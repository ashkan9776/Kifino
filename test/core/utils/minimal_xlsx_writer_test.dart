import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/utils/minimal_xlsx_writer.dart';

void main() {
  group('MinimalXlsxWriter', () {
    test('produces a valid xlsx zip with workbook and worksheet parts', () {
      final bytes = MinimalXlsxWriter.encode(sheets: [
        const XlsxSheetData('تراز آزمایشی', [
          ['کد', 'حساب', 'بدهکار', 'بستانکار'],
          ['010', 'بانک‌ها', 100000, 0],
          ['060', 'فروش', 0, 100000],
        ]),
        const XlsxSheetData('روزنامه', [
          ['شرح', 'مبلغ'],
          ['خرید نرم‌افزار', 2500000],
        ]),
      ]);

      // It must be a real zip (PK header).
      expect(bytes.take(2).toList(), equals([0x50, 0x4B]));

      // Decode and verify the required OOXML parts exist with our content.
      final archive = ZipDecoder().decodeBytes(bytes);
      final names = archive.files.map((f) => f.name).toSet();
      expect(names, containsAll([
        '[Content_Types].xml',
        '_rels/.rels',
        'xl/workbook.xml',
        'xl/worksheets/sheet1.xml',
        'xl/worksheets/sheet2.xml',
      ]));

      final sheet1 = utf8.decode(
        archive.files
            .firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml')
            .content,
      );
      expect(sheet1, contains('بانک‌ها'));
      expect(sheet1, contains('<v>100000</v>'));
      // RTL sheet view present
      expect(sheet1, contains('rightToLeft="1"'));

      final workbook = utf8.decode(
        archive.files
            .firstWhere((f) => f.name == 'xl/workbook.xml')
            .content,
      );
      expect(workbook, contains('تراز آزمایشی'));
      expect(workbook, contains('روزنامه'));
    });

    test('writes files that Excel can open — spot-check content types', () async {
      final bytes = MinimalXlsxWriter.encode(sheets: [
        const XlsxSheetData('Sheet1', [
          ['a', 1],
        ]),
      ]);
      final tmp = File(
        '${Directory.systemTemp.path}/kifino_test_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      );
      await tmp.writeAsBytes(bytes, flush: true);
      expect(await tmp.exists(), isTrue);
      expect(await tmp.length(), greaterThan(200));
      await tmp.delete();
    });
  });
}
