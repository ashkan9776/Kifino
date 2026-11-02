import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// One worksheet: a name (≤31 chars, sanitized) and rows of cells.
/// Cell values are either String (inline text) or num (numeric).
class XlsxSheetData {
  final String name;
  final List<List<Object>> rows;

  const XlsxSheetData(this.name, this.rows);
}

/// Minimal, dependency-free XLSX (OOXML) writer.
///
/// Produces a spec-valid workbook (inline-string cells, RTL sheet views,
/// minimal styles) that opens correctly in Excel, LibreOffice and Google
/// Sheets. Zip building uses the `archive` package which is already part of
/// the Flutter toolchain — no new pub dependency required.
abstract final class MinimalXlsxWriter {
  static const String _contentTypesTemplate =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '{SHEETS}'
      '</Types>';

  static const String _rels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';

  static const String _styles =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>'
      '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>'
      '<borders count="1"><border/></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>'
      '</styleSheet>';

  static Uint8List encode({required List<XlsxSheetData> sheets}) {
    assert(sheets.isNotEmpty, 'workbook needs at least one sheet');
    final contentTypesSheets = StringBuffer();
    final workbookSheets = StringBuffer();
    final workbookRels = StringBuffer();
    final worksheetFiles = <ArchiveFile>[];

    for (var i = 0; i < sheets.length; i++) {
      final n = i + 1;
      final safeName = sheets[i].name
          .replaceAll(RegExp(r'[\\/*?:\[\]]'), '')
          .substring(0, sheets[i].name.length.clamp(0, 31));
      contentTypesSheets.write(
        '<Override PartName="/xl/worksheets/sheet$n.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
      );
      workbookSheets.write(
        '<sheet name="${_escape(safeName)}" sheetId="$n" r:id="rId$n"/>',
      );
      workbookRels.write(
        '<Relationship Id="rId$n" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$n.xml"/>',
      );
      worksheetFiles.add(
        ArchiveFile.bytes(
          'xl/worksheets/sheet$n.xml',
          utf8.encode(_sheetXml(sheets[i].rows)),
        ),
      );
    }

    final archive = Archive()
      ..addFile(
        ArchiveFile.bytes(
          '[Content_Types].xml',
          utf8.encode(
            _contentTypesTemplate.replaceFirst(
              '{SHEETS}',
              contentTypesSheets.toString(),
            ),
          ),
        ),
      )
      ..addFile(ArchiveFile.bytes('_rels/.rels', utf8.encode(_rels)))
      ..addFile(
        ArchiveFile.bytes(
          'xl/workbook.xml',
          utf8.encode(
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
            '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
            '<sheets>${workbookSheets.toString()}</sheets></workbook>',
          ),
        ),
      )
      ..addFile(
        ArchiveFile.bytes(
          'xl/_rels/workbook.xml.rels',
          utf8.encode(
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '${workbookRels.toString()}'
            '<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
            '</Relationships>',
          ),
        ),
      )
      ..addFile(ArchiveFile.bytes('xl/styles.xml', utf8.encode(_styles)));
    for (final f in worksheetFiles) {
      archive.addFile(f);
    }

    final bytes = ZipEncoder().encode(archive);
    return Uint8List.fromList(bytes);
  }

  static String _sheetXml(List<List<Object>> rows) {
    final sb = StringBuffer();
    sb.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    sb.write(
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    );
    sb.write(
      '<sheetViews><sheetView rightToLeft="1" workbookViewId="0"/></sheetViews>',
    );
    sb.write('<sheetData>');
    for (var r = 0; r < rows.length; r++) {
      sb.write('<row r="${r + 1}">');
      final cells = rows[r];
      for (var c = 0; c < cells.length; c++) {
        final ref = '${_columnLetter(c)}${r + 1}';
        final value = cells[c];
        if (value is num) {
          sb.write('<c r="$ref"><v>$value</v></c>');
        } else if (value.toString().isNotEmpty) {
          sb.write(
            '<c r="$ref" t="inlineStr"><is><t>${_escape(value.toString())}</t></is></c>',
          );
        }
      }
      sb.write('</row>');
    }
    sb.write('</sheetData></worksheet>');
    return sb.toString();
  }

  static String _columnLetter(int index) {
    var i = index;
    final sb = StringBuffer();
    while (i >= 0) {
      sb.write(String.fromCharCode(65 + (i % 26)));
      i = (i ~/ 26) - 1;
    }
    return sb.toString().split('').reversed.join();
  }

  static String _escape(String raw) => raw
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
