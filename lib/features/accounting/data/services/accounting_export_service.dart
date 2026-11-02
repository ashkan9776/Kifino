import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/minimal_xlsx_writer.dart';
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
