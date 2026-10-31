import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../data/services/accounting_export_service.dart';
import '../../domain/entities/accounting_subject_entity.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../domain/repositories/accounting_repository.dart';
import '../services/accounting_export_actions.dart';

class LedgerPage extends StatefulWidget {
  final String? initialSubjectId;
  const LedgerPage({super.key, this.initialSubjectId});

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> with AccountingExportActions {
  List<AccountingSubjectEntity> _subjects = [];
  AccountingSubjectEntity? _selectedSubject;
  LedgerReport? _report;
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final repo = getIt<AccountingRepository>();
    final allSubs = await repo.getAllSubjects();
    setState(() {
      _subjects = allSubs;
      if (allSubs.isNotEmpty) {
        _selectedSubject = widget.initialSubjectId != null
            ? allSubs.firstWhere(
                (s) => s.id == widget.initialSubjectId,
                orElse: () => allSubs.first,
              )
            : allSubs.first;
      }
    });

    if (_selectedSubject != null) {
      await _loadLedger();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLedger() async {
    if (_selectedSubject == null) return;
    setState(() => _isLoading = true);
    final repo = getIt<AccountingRepository>();
    final report = await repo.getLedgerReport(
      subjectId: _selectedSubject!.id,
      startDate: _startDate,
      endDate: _endDate,
    );
    setState(() {
      _report = report;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('دفتر کل و دفتر معین'),
        centerTitle: true,
        actions: [
          buildExportAction(() async {
            final subject = _selectedSubject;
            if (subject == null) {
              throw StateError('ابتدا سرفصل حساب را انتخاب کنید');
            }
            return getIt<AccountingExportService>().exportLedger(
              subjectId: subject.id,
              startDate: _startDate,
              endDate: _endDate,
            );
          }),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _pickDateRange(context),
            tooltip: 'فیلتر بازه زمانی',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLedger,
            tooltip: 'تازه‌سازی',
          ),
        ],
      ),
      body: Column(
        children: [
          // Account Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: InkWell(
              onTap: () => _pickSubjectDialog(context),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_tree_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedSubject != null
                            ? _selectedSubject!.formattedName
                            : 'انتخاب سرفصل حساب...',
                        style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ),

          // Summary Card (Opening, Turnover, Closing with Diagnosis)
          if (_report != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('مانده اول دوره', style: AppTypography.bodySmall),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              AppMoneyText(
                                money: _report!.openingBalance,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${_report!.openingSide})',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(width: 1, height: 30, color: Colors.grey.withValues(alpha: 0.3)),
                      Column(
                        children: [
                          Text('گردش بدهکار', style: AppTypography.bodySmall),
                          const SizedBox(height: 4),
                          AppMoneyText(
                            money: _report!.sumDebit,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 30, color: Colors.grey.withValues(alpha: 0.3)),
                      Column(
                        children: [
                          Text('گردش بستانکار', style: AppTypography.bodySmall),
                          const SizedBox(height: 4),
                          AppMoneyText(
                            money: _report!.sumCredit,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 30, color: Colors.grey.withValues(alpha: 0.3)),
                      Column(
                        children: [
                          Text('مانده نهایی', style: AppTypography.bodySmall),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              AppMoneyText(
                                money: _report!.closingBalance,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${_report!.closingSide})',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _report!.closingSide == 'بد'
                                      ? Colors.red
                                      : _report!.closingSide == 'بس'
                                          ? Colors.green
                                          : colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),

          // Ledger Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _report == null || _report!.entries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chrome_reader_mode, size: 50, color: colors.textSecondary),
                            const SizedBox(height: 10),
                            Text('گردشی برای این سرفصل ثبت نشده است', style: AppTypography.bodyMedium),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _report!.entries.length,
                        itemBuilder: (context, index) {
                          final entry = _report!.entries[index];
                          return _buildLedgerRowCard(entry, colors);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerRowCard(LedgerEntry entry, KifinoColorsExtension colors) {
    final jalali = JalaliDate.fromDateTime(entry.date);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ردیف ${TextNormalizer.toPersianDigits(entry.rowIndex.toString())} • سند #${TextNormalizer.toPersianDigits(entry.documentNumber.toString())}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${TextNormalizer.toPersianDigits(jalali.day.toString())} ${jalali.monthName} ${TextNormalizer.toPersianDigits(jalali.year.toString())}',
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                entry.description,
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (entry.debit.minorUnits > 0) ...[
                        const Text('بدهکار: ', style: TextStyle(fontSize: 11, color: Colors.red)),
                        AppMoneyText(
                          money: entry.debit,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ],
                      if (entry.credit.minorUnits > 0) ...[
                        const Text('بستانکار: ', style: TextStyle(fontSize: 11, color: Colors.green)),
                        AppMoneyText(
                          money: entry.credit,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      Text('مانده: ', style: AppTypography.bodySmall),
                      AppMoneyText(
                        money: entry.runningBalance,
                        style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: entry.balanceSide == 'بد'
                              ? Colors.red.withValues(alpha: 0.1)
                              : entry.balanceSide == 'بس'
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          entry.balanceSide,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: entry.balanceSide == 'بد'
                                ? Colors.red
                                : entry.balanceSide == 'بس'
                                    ? Colors.green
                                    : colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickSubjectDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final filtered = _subjects.where((s) {
              final q = query.trim().toLowerCase();
              return q.isEmpty || s.name.toLowerCase().contains(q) || s.code.contains(q);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (_, scrollCtrl) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('انتخاب سرفصل حسابداری', style: AppTypography.titleMedium),
                      const SizedBox(height: 10),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'جستجوی سرفصل (نام یا کد)...',
                          prefixIcon: const Icon(Icons.search),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (val) {
                          setModalState(() => query = val);
                        },
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollCtrl,
                          itemCount: filtered.length,
                          itemBuilder: (c, i) {
                            final sub = filtered[i];
                            return ListTile(
                              dense: true,
                              title: Text(sub.formattedName,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('${sub.level.titleFa} • ${sub.type.titleFa}'),
                              onTap: () {
                                setState(() => _selectedSubject = sub);
                                Navigator.pop(ctx);
                                _loadLedger();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
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
      _loadLedger();
    }
  }
}
