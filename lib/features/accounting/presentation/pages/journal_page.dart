import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../data/services/accounting_export_service.dart';
import '../../domain/entities/accounting_document_entity.dart';
import '../../domain/repositories/accounting_repository.dart';
import '../services/accounting_export_actions.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage>
    with AccountingExportActions {
  List<AccountingDocumentEntity> _documents = [];
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadJournal();
  }

  Future<void> _loadJournal() async {
    setState(() => _isLoading = true);
    final repo = getIt<AccountingRepository>();
    final docs = await repo.getDocuments(
      startDate: _startDate,
      endDate: _endDate,
    );
    // Sort chronological (oldest to newest) for journal
    setState(() {
      _documents = docs.reversed.toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;

    int grandTotalDebit = 0;
    int grandTotalCredit = 0;

    for (final doc in _documents) {
      grandTotalDebit += doc.totalDebit.minorUnits;
      grandTotalCredit += doc.totalCredit.minorUnits;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('دفتر روزنامه رسمی'),
        centerTitle: true,
        actions: [
          buildExportAction(
            () => getIt<AccountingExportService>().exportJournal(
              startDate: _startDate,
              endDate: _endDate,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _pickDateRange(context),
            tooltip: 'فیلتر تاریخ',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadJournal,
            tooltip: 'تازه‌سازی',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book, size: 56, color: colors.textSecondary),
                      const SizedBox(height: 12),
                      Text('تراکنشی در دفتر روزنامه ثبت نشده است', style: AppTypography.titleMedium),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Journal List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _documents.length,
                        itemBuilder: (context, index) {
                          final doc = _documents[index];
                          return _buildJournalDocumentBlock(doc, colors);
                        },
                      ),
                    ),

                    // Grand Total Footer
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        border: Border(
                          top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            offset: const Offset(0, -2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('جمع کل دفتر روزنامه:',
                                style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                Text('بدهکار: ', style: AppTypography.bodySmall),
                                AppMoneyText(
                                  money: Money.fromMinor(grandTotalDebit),
                                  style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 16),
                                Text('بستانکار: ', style: AppTypography.bodySmall),
                                AppMoneyText(
                                  money: Money.fromMinor(grandTotalCredit),
                                  style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildJournalDocumentBlock(AccountingDocumentEntity doc, KifinoColorsExtension colors) {
    final jalali = JalaliDate.fromDateTime(doc.date);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Document Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('سند #${TextNormalizer.toPersianDigits(doc.number.toString())}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 8),
                    Text('• ${doc.title}',
                        style: TextStyle(fontSize: 12, color: colors.textPrimary),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
                Text(
                  '${TextNormalizer.toPersianDigits(jalali.day.toString())} ${jalali.monthName} ${TextNormalizer.toPersianDigits(jalali.year.toString())}',
                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                ),
              ],
            ),
          ),

          // Transactions Table Rows
          Padding(
            padding: const EdgeInsets.all(8),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2), // ردیف و کد
                1: FlexColumnWidth(3.0), // شرح
                2: FlexColumnWidth(1.8), // بدهکار
                3: FlexColumnWidth(1.8), // بستانکار
              },
              children: [
                const TableRow(
                  children: [
                    Text('کد حساب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    Text('شرح آرتیکل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    Text('بدهکار',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.red),
                        textAlign: TextAlign.end),
                    Text('بستانکار',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green),
                        textAlign: TextAlign.end),
                  ],
                ),
                const TableRow(children: [
                  Divider(height: 8),
                  Divider(height: 8),
                  Divider(height: 8),
                  Divider(height: 8),
                ]),
                ...doc.transactions.map((tx) {
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          tx.subject?.formattedCode ?? '',
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          tx.subject != null ? '${tx.subject!.name} (${tx.description})' : tx.description,
                          style: const TextStyle(fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          tx.debit.minorUnits > 0 ? tx.debit.formatted : '-',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.end,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          tx.credit.minorUnits > 0 ? tx.credit.formatted : '-',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadJournal();
    }
  }
}
