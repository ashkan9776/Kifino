import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/minimal_xlsx_writer.dart';
import '../../domain/entities/accounting_document_entity.dart';
import '../../domain/entities/accounting_subject_entity.dart';
import '../../domain/repositories/accounting_repository.dart';

/// Real XLSX exports (Phase 4) for the accounting reports. Data is fetched on
/// the main isolate, byte building runs in a background isolate via compute,
/// files land in the documents/exports directory.
class AccountingExportService {
  final AccountingRepository _repository;

  const AccountingExportService(this._repository);

  Future<String> exportJournal({DateTime? startDate, DateTime? endDate}) async {
    final docs = await _repository.getDocuments(
      startDate: startDate,
      endDate: endDate,
    );
    final rows = <List<Object>>[
      [
        'شماره سند',
        'تاریخ',
        'عنوان سند',
        'کد حساب',
        'نام حساب',
        'شرح',
        'بدهکار',
        'بستانکار',
      ],
    ];
    for (final doc in docs) {
      for (final tx in doc.transactions) {
        final subject = await _repository.getSubjectById(tx.subjectId);
        rows.add([
          doc.number,
          AppDateFormatter.formatShort(doc.date, locale: 'fa'),
          doc.title,
          subject?.code ?? '',
          subject?.name ?? '',
          tx.description,
          tx.debit.minorUnits,
          tx.credit.minorUnits,
        ]);
      }
    }
    return _save('journal', [XlsxSheetData('دفتر روزنامه', rows)]);
  }

  Future<String> exportLedger({
    required String subjectId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final report = await _repository.getLedgerReport(
      subjectId: subjectId,
      startDate: startDate,
      endDate: endDate,
    );
    final rows = <List<Object>>[
      ['تاریخ', 'شماره سند', 'شرح', 'بدهکار', 'بستانکار', 'مانده'],
      [
        'افتتاحیه',
        '',
        'مانده اول دوره',
        report.openingSide == 'بد' ? report.openingBalance.minorUnits : 0,
        report.openingSide == 'بس' ? report.openingBalance.minorUnits : 0,
        report.openingBalance.minorUnits,
      ],
    ];
    for (final entry in report.entries) {
      rows.add([
        AppDateFormatter.formatShort(entry.date, locale: 'fa'),
        entry.documentNumber,
        entry.description,
        entry.debit.minorUnits,
        entry.credit.minorUnits,
        entry.runningBalance.minorUnits,
      ]);
    }
    final closing = report.closingBalance;
    rows.add([
      '',
      '',
      'مانده پایان دوره',
      closing.minorUnits >= 0 ? closing.minorUnits : 0,
      closing.minorUnits < 0 ? -closing.minorUnits : 0,
      closing.minorUnits,
    ]);
    return _save('ledger', [
      XlsxSheetData('دفتر کل ${report.subject.name}', rows),
    ]);
  }

  Future<String> exportTrialBalance({
    AccountingSubjectLevel level = AccountingSubjectLevel.kol,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final report = await _repository.getTrialBalanceReport(
      level: level,
      startDate: startDate,
      endDate: endDate,
    );
    final rows = <List<Object>>[
      [
        'کد',
        'حساب',
        'بد opens',
        'بس opens',
        'گردش بد',
        'گردش بس',
        'مانده بد',
        'مانده بس',
      ],
    ];
    for (final e in report.entries) {
      rows.add([
        e.subject.code,
        e.subject.name,
        e.openingDebit.minorUnits,
        e.openingCredit.minorUnits,
        e.periodDebit.minorUnits,
        e.periodCredit.minorUnits,
        e.endingDebit.minorUnits,
        e.endingCredit.minorUnits,
      ]);
    }
    // Totals row must balance.
    int tOpenD = 0, tOpenC = 0, tPD = 0, tPC = 0, tED = 0, tEC = 0;
    for (final e in report.entries) {
      tOpenD += e.openingDebit.minorUnits;
      tOpenC += e.openingCredit.minorUnits;
      tPD += e.periodDebit.minorUnits;
      tPC += e.periodCredit.minorUnits;
      tED += e.endingDebit.minorUnits;
      tEC += e.endingCredit.minorUnits;
    }
    rows.add(['', 'جمع', tOpenD, tOpenC, tPD, tPC, tED, tEC]);
    return _save('trial-balance', [XlsxSheetData('تراز آزمایشی', rows)]);
  }

  Future<String> exportBalanceSheet({required DateTime asOfDate}) async {
    final report = await _repository.getBalanceSheetReport(asOfDate: asOfDate);
    final rows = <List<Object>>[
      ['گروه', 'حساب', 'مانده'],
    ];
    void addGroup(String title, List items) {
      for (final item in items) {
        rows.add([title, item.title, item.amount.minorUnits]);
      }
    }

    addGroup('دارایی جاری', report.currentAssets);
    addGroup('دارایی غیرجاری', report.nonCurrentAssets);
    addGroup('بدهی جاری', report.currentLiabilities);
    addGroup('بدهی غیرجاری', report.nonCurrentLiabilities);
    addGroup('حقوق صاحبان سهام', report.equityItems);
    rows.add(['', 'سود (زیان) دوره', report.netIncomeForPeriod.minorUnits]);
    return _save('balance-sheet', [XlsxSheetData('ترازنامه', rows)]);
  }

  Future<String> exportIncomeStatement({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final report = await _repository.getIncomeStatementReport(
      startDate: startDate,
      endDate: endDate,
    );
    final rows = <List<Object>>[
      ['گروه', 'حساب', 'مبلغ'],
    ];
    for (final item in report.revenues) {
      rows.add(['درآمد', item.title, item.amount.minorUnits]);
    }
    for (final item in report.salesDiscountsReturns) {
      rows.add(['تخفیف و برگشت فروش', item.title, -item.amount.minorUnits]);
    }
    for (final item in report.cogsItems) {
      rows.add(['بهای تمام‌شده', item.title, item.amount.minorUnits]);
    }
    for (final item in report.operatingExpenses) {
      rows.add(['هزینه عملیاتی', item.title, item.amount.minorUnits]);
    }
    for (final item in report.otherIncomes) {
      rows.add(['سایر درآمدها', item.title, item.amount.minorUnits]);
    }
    for (final item in report.otherExpenses) {
      rows.add(['سایر هزینه‌ها', item.title, item.amount.minorUnits]);
    }
    rows.add(['', 'سود (زیان) خالص', report.netProfit.minorUnits]);
    return _save('income-statement', [XlsxSheetData('صورت سود و زیان', rows)]);
  }


  /// ─── دفاتر قانونی (فرمت سازمان امور مالیاتی) ───
  ///
  /// The tax org's electronic-books format requires, per transaction line:
  /// ledger (kol) code+name, sub-ledger (moein) code+name, detail (تفصیلی)
  /// code+name, debit/credit, document date/number/description. Exported as
  /// XLSX ready for the دفاتر الکترونیکی portal upload.

  /// Latest FINAL document date ≤ [fiscalYearId]'s end → the «شمول» date
  /// for the legal journal. Kifino documents carry a single date, so both
  /// شمول and موضوع columns share it.
  Future<String> exportLegalJournal({String? fiscalYearId}) async {
    final docs = (await _repository.getDocuments(fiscalYearId: fiscalYearId))
        .where((d) =>
            d.status == DocumentStatus.approved ||
            d.status == DocumentStatus.posted)
        .toList();
    final subjects = await _repository.getAllSubjects();
    String codeOf(String id) =>
        subjects.where((s) => s.id == id).firstOrNull?.code ?? '';
    String nameOf(String id) =>
        subjects.where((s) => s.id == id).firstOrNull?.name ?? '';

    final rows = <List<Object>>[
      [
        'ردیف',
        'تاریخ شمول',
        'تاریخ موضوع',
        'شماره سند',
        'شرح سند',
        'کد کل',
        'عنوان کل',
        'کد معین',
        'عنوان معین',
        'کد تفصیلی',
        'شرح تفصیلی',
        'بدهکار',
        'بستانکار',
        'شرح آرتیکل',
      ],
    ];
    var rowIndex = 1;
    for (final doc in docs.reversed) {
      for (final tx in doc.transactions) {
        final kolCode = codeOf(tx.subjectId);
        // Kol = 3-digit prefix; moein = 6-digit — derive the kol name by
        // prefix match when the posting is at moein level.
        String kolName = '';
        if (kolCode.length >= 3) {
          final matches = subjects.where(
            (s) => s.code == kolCode.substring(0, 3) && s.level == AccountingSubjectLevel.kol,
          );
          kolName = matches.isEmpty ? '' : matches.first.name;
        }
        rows.add([
          rowIndex++,
          AppDateFormatter.formatShort(doc.date, locale: 'fa'),
          AppDateFormatter.formatShort(doc.date, locale: 'fa'),
          doc.number,
          doc.title,
          kolCode.length > 3 ? kolCode.substring(0, 3) : kolCode,
          kolName,
          kolCode.length > 3 ? kolCode : '',
          kolCode.length > 3 ? nameOf(tx.subjectId) : '',
          tx.detailSubjectId ?? '',
          tx.detailSubjectName ?? '',
          tx.debit.minorUnits,
          tx.credit.minorUnits,
          tx.description,
        ]);
      }
    }
    return _save('legal-journal', [
      XlsxSheetData('دفتر روزنامه قانونی', rows),
    ]);
  }

  /// Legal GENERAL LEDGER: one row per moein account — kol/moein codes and
  /// names, period turns, and closing debit/credit balances.
  Future<String> exportLegalLedger({String? fiscalYearId}) async {
    final report = await _repository.getTrialBalanceReport(
      level: AccountingSubjectLevel.moein,
      fiscalYearId: fiscalYearId,
    );
    final rows = <List<Object>>[
      [
        'کد کل',
        'عنوان کل',
        'کد معین',
        'عنوان معین',
        'گردش بدهکار',
        'گردش بستانکار',
        'مانده بدهکار',
        'مانده بستانکار',
      ],
    ];
    for (final e in report.entries) {
      final code = e.subject.code;
      final kolCode = code.length > 3 ? code.substring(0, 3) : code;
      String kolName = '';
      if (code.length > 3) {
        final matches = (await _repository.getAllSubjects()).where(
          (s) => s.code == kolCode && s.level == AccountingSubjectLevel.kol,
        );
        kolName = matches.isEmpty ? '' : matches.first.name;
      }
      final net = e.netMinorUnits; // + debit / − credit
      rows.add([
        kolCode,
        kolName,
        code,
        e.subject.name,
        e.periodDebit.minorUnits,
        e.periodCredit.minorUnits,
        net > 0 ? net : 0,
        net < 0 ? -net : 0,
      ]);
    }
    return _save('legal-ledger', [XlsxSheetData('دفتر کل قانونی', rows)]);
  }

  Future<String> _save(String baseName, List<XlsxSheetData> sheets) async {
    final bytes = await compute(_encodeIsolate, sheets);
    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory(p.join(dir.path, 'exports'));
    if (!await exportDir.exists()) await exportDir.create(recursive: true);

    final stamp = AppDateFormatter.formatShort(
      DateTime.now(),
      locale: 'fa',
    ).replaceAll(RegExp(r'[^\u0600-\u06FF\w]'), '-');
    final filePath = p.join(exportDir.path, 'kifino-$baseName-$stamp.xlsx');
    await File(filePath).writeAsBytes(bytes, flush: true);
    return filePath;
  }
}

/// Top-level isolate entry — plain sendable payload only.
Uint8List _encodeIsolate(List<XlsxSheetData> sheets) =>
    MinimalXlsxWriter.encode(sheets: sheets);
