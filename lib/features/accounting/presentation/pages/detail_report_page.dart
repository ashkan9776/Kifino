import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../domain/entities/accounting_audit_entity.dart';
import '../../domain/repositories/accounting_repository.dart';

/// Selection payload passed through the router `extra` when the report is
/// opened pre-filled from the detail-ledgers page.
class DetailReportSelection {
  final String ledgerId;
  final String valueId;

  const DetailReportSelection({required this.ledgerId, required this.valueId});
}

/// تفصیلی شناور report: turnover of every approved document tagged with the
/// chosen detail value, with running balance and totals.
class DetailReportPage extends StatefulWidget {
  final DetailReportSelection? initialSelection;

  const DetailReportPage({super.key, this.initialSelection});

  @override
  State<DetailReportPage> createState() => _DetailReportPageState();
}

class _DetailReportPageState extends State<DetailReportPage> {
  List<DetailLedgerWithValues> _ledgers = [];
  bool _loadingLedgers = true;
  String? _selectedLedgerId;
  String? _selectedValueId;
  DateTime? _startDate;
  DateTime? _endDate;

  DetailReport? _report;
  bool _loadingReport = false;
  String? _reportError;

  @override
  void initState() {
    super.initState();
    _loadLedgers();
  }

  Future<void> _loadLedgers() async {
    setState(() => _loadingLedgers = true);
    try {
      final ledgers = await getIt<AccountingRepository>().getDetailLedgers();
      if (!mounted) return;
      setState(() {
        _ledgers = ledgers;
        _loadingLedgers = false;
        final selection = widget.initialSelection;
        if (_selectedLedgerId == null && selection != null) {
          _selectedLedgerId = selection.ledgerId;
          _selectedValueId = selection.valueId;
        }
        // Dropped selection guard: ledger/value may have been deleted.
        if (_selectedLedgerId != null &&
            !_ledgers.any((l) => l.ledger.id == _selectedLedgerId)) {
          _selectedLedgerId = null;
          _selectedValueId = null;
        }
        if (_selectedLedgerId != null && _selectedValueId != null) {
          final values = _valuesOf(_selectedLedgerId!) ?? const <DetailValueEntity>[];
          if (!values.any((v) => v.id == _selectedValueId)) {
            _selectedValueId = null;
          }
        }
      });
      if (_selectedLedgerId != null && _selectedValueId != null) {
        await _runReport();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingLedgers = false;
        _reportError = _message(e);
      });
    }
  }

  List<DetailValueEntity>? _valuesOf(String ledgerId) {
    for (final l in _ledgers) {
      if (l.ledger.id == ledgerId) return l.values;
    }
    return null;
  }

  Future<void> _runReport() async {
    final ledgerId = _selectedLedgerId;
    final valueId = _selectedValueId;
    if (ledgerId == null || valueId == null) return;
    setState(() {
      _loadingReport = true;
      _reportError = null;
    });
    try {
      final report = await getIt<AccountingRepository>().getDetailReport(
            ledgerId: ledgerId,
            valueId: valueId,
            startDate: _startDate,
            endDate: _endDate,
          );
      if (!mounted) return;
      setState(() {
        _report = report;
        _loadingReport = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reportError = _message(e);
        _loadingReport = false;
      });
    }
  }

  Future<void> _pickDateRange() async {
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
    }
  }

  static String _message(Object e) =>
      e.toString().replaceFirst(RegExp(r'^(Bad state|StateError):\s*'), '');

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('گزارش تفصیلی شناور'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildControls(colors),
          const Divider(height: 1),
          Expanded(child: _buildResults(colors)),
        ],
      ),
    );
  }

  Widget _buildControls(KifinoColorsExtension colors) {
    final selectedLedger =
        _ledgers.where((l) => l.ledger.id == _selectedLedgerId).firstOrNull;
    final values = selectedLedger?.values ?? const <DetailValueEntity>[];
    final canRun = _selectedLedgerId != null &&
        _selectedValueId != null &&
        !_loadingReport;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: _loadingLedgers
          ? const Column(
              children: [
                AppSkeleton(height: 48),
                SizedBox(height: 10),
                AppSkeleton(height: 48),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedLedgerId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'تفصیلی شناور *',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _ledgers
                      .map((l) => DropdownMenuItem(
                            value: l.ledger.id,
                            child: Text(l.ledger.title, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (id) {
                    setState(() {
                      _selectedLedgerId = id;
                      _selectedValueId = null;
                      _report = null;
                    });
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: ValueKey('detail-value-$_selectedLedgerId'),
                  initialValue: _selectedValueId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'مقدار تفصیلی *',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  items: values
                      .map((v) => DropdownMenuItem(
                            value: v.id,
                            child: Text(v.title, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: _selectedLedgerId == null
                      ? null
                      : (id) {
                          setState(() {
                            _selectedValueId = id;
                            _report = null;
                          });
                        },
                ),
                const SizedBox(height: 10),
                _buildDateRangeField(colors),
                const SizedBox(height: 12),
                AppButton(
                  label: 'نمایش گزارش',
                  icon: const Icon(Icons.assessment_outlined, size: 18),
                  onPressed: canRun ? _runReport : null,
                  isLoading: _loadingReport,
                ),
              ],
            ),
          ),
      );
  }

  Widget _buildDateRangeField(KifinoColorsExtension colors) {
    final hasRange = _startDate != null && _endDate != null;
    return InkWell(
      onTap: _pickDateRange,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: colors.surfaceBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.date_range, size: 18, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasRange
                    ? '${JalaliDate.fromDateTime(_startDate!).format()} — ${JalaliDate.fromDateTime(_endDate!).format()}'
                    : 'بازه تاریخ (اختیاری)',
                style: AppTypography.bodySmall.copyWith(
                  color: hasRange ? colors.textPrimary : colors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasRange)
              GestureDetector(
                onTap: () => setState(() {
                  _startDate = null;
                  _endDate = null;
                }),
                child: Icon(Icons.close, size: 16, color: colors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(KifinoColorsExtension colors) {
    if (_loadingReport) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(
          6,
          (index) => const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: AppSkeleton(height: 84),
          ),
        ),
      );
    }

    if (_reportError != null) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: 'خطا در دریافت گزارش',
        description: _reportError!,
        actionLabel: 'تلاش مجدد',
        onAction: _runReport,
      );
    }

    final report = _report;
    if (report == null) {
      return AppEmptyState(
        icon: Icons.assessment_outlined,
        title: 'گزارشی نمایش داده نشده است',
        description: 'تفصیلی شناور و مقدار آن را انتخاب کرده و روی «نمایش گزارش» بزنید.',
      );
    }

    if (report.rows.isEmpty) {
      return AppEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'گردشی برای این مقدار ثبت نشده است',
        description:
            'هیچ سند تأییدشده‌ای با این برچسب تفصیلی در بازه انتخابی یافت نشد.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: report.rows.length + 1,
      itemBuilder: (context, index) {
        if (index == report.rows.length) {
          return _TotalsCard(report: report, colors: colors);
        }
        return _ReportRowCard(row: report.rows[index], colors: colors);
      },
    );
  }
}

class _ReportRowCard extends StatelessWidget {
  final DetailReportRow row;
  final KifinoColorsExtension colors;

  const _ReportRowCard({required this.row, required this.colors});

  String _balanceText() {
    if (row.runningBalanceMinorUnits == 0) return TextNormalizer.auto('0');
    return Money.fromMinor(row.runningBalanceMinorUnits.abs()).formatted;
  }

  String _balanceSide() {
    final net = row.runningBalanceMinorUnits;
    if (net == 0) return '';
    return net > 0 ? 'بد' : 'بس';
  }

  @override
  Widget build(BuildContext context) {
    final jalali = JalaliDate.fromDateTime(row.date);
    final hasDebit = row.debitMinorUnits > 0;
    final hasCredit = row.creditMinorUnits > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'سند #${TextNormalizer.auto(row.documentNumber.toString())}',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${TextNormalizer.auto(jalali.day.toString())} ${jalali.monthName} ${TextNormalizer.auto(jalali.year.toString())}',
                    style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(row.documentTitle, style: AppTypography.titleSmall),
            Text(
              row.subjectName + (row.description.isNotEmpty ? ' • ${row.description}' : ''),
              style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _AmountCell(
                    label: 'بدهکار',
                    amount: hasDebit ? Money.fromMinor(row.debitMinorUnits).formatted : '-',
                    color: hasDebit ? colors.expense : colors.textTertiary,
                  ),
                ),
                Expanded(
                  child: _AmountCell(
                    label: 'بستانکار',
                    amount: hasCredit ? Money.fromMinor(row.creditMinorUnits).formatted : '-',
                    color: hasCredit ? colors.income : colors.textTertiary,
                  ),
                ),
                Expanded(
                  child: _AmountCell(
                    label: 'مانده (${_balanceSide()})',
                    amount: _balanceText(),
                    color: row.runningBalanceMinorUnits >= 0 ? colors.expense : colors.income,
                    bold: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountCell extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;
  final bool bold;

  const _AmountCell({
    required this.label,
    required this.amount,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelSmall.copyWith(color: colors.textSecondary)),
        const SizedBox(height: 2),
        Text(
          amount,
          style: AppTypography.bodyMedium.copyWith(
            color: color,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final DetailReport report;
  final KifinoColorsExtension colors;

  const _TotalsCard({required this.report, required this.colors});

  @override
  Widget build(BuildContext context) {
    final net = report.netMinorUnits;
    final netColor = net == 0
        ? colors.textSecondary
        : (net > 0 ? colors.expense : colors.income);
    final netSide = net == 0 ? '' : (net > 0 ? 'بدهکار' : 'بستانکار');

    return AppCard(
      padding: const EdgeInsets.all(14),
      borderColor: colors.primary.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('جمع کل گزارش', style: AppTypography.titleSmall),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('جمع بدهکار', style: AppTypography.bodySmall),
                    Text(
                      Money.fromMinor(report.totalDebitMinorUnits).formatted,
                      style: AppTypography.titleSmall.copyWith(color: colors.expense),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('جمع بستانکار', style: AppTypography.bodySmall),
                    Text(
                      Money.fromMinor(report.totalCreditMinorUnits).formatted,
                      style: AppTypography.titleSmall.copyWith(color: colors.income),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('مانده خالص $netSide', style: AppTypography.bodyMedium),
              Text(
                Money.fromMinor(net.abs()).formatted,
                style: AppTypography.moneyTile.copyWith(color: netColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
