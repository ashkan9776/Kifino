import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../domain/entities/aging_report_entity.dart';
import '../../domain/repositories/business_repository.dart';

/// گزارش سنی مطالبات/بدهی‌ها — open invoices bucketed by days past due,
/// per contact. Receivables by default; payables via the toggle.
class AgingReportPage extends StatefulWidget {
  const AgingReportPage({super.key});

  @override
  State<AgingReportPage> createState() => _AgingReportPageState();
}

class _AgingReportPageState extends State<AgingReportPage> {
  bool _receivables = true;
  bool _loading = true;
  List<ContactAgingEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result =
        await sl<BusinessRepository>().getAgingReport(receivables: _receivables);
    if (!mounted) return;
    setState(() {
      _entries = result.dataOrNull ?? const [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Scaffold(
      appBar: AppBar(
        title: const Text('گزارش سنی مطالبات'),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('مطالبات')),
                  ButtonSegment(value: false, label: Text('بدهی‌ها')),
                ],
                selected: {_receivables},
                onSelectionChanged: (val) {
                  setState(() => _receivables = val.first);
                  _load();
                },
                showSelectedIcon: false,
              ),
            ),
            if (_loading)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    AppSkeleton(
                      height: 90,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppSkeleton(
                      height: 220,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ],
                ),
              )
            else if (_entries.isEmpty)
              Expanded(
                child: AppEmptyState(
                  icon: Icons.hourglass_empty_rounded,
                  title: _receivables ? 'مطالبی در جریان نیست' : 'بدهی در جریان نیست',
                  description: 'همه فاکتورهای این دسته تسویه شده‌اند.',
                ),
              )
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  children: [
                    _BucketHeader(receivables: _receivables, subtext: subtext),
                    const SizedBox(height: AppSpacing.sm),
                    for (final entry in _entries) ...[
                      _AgingCard(entry: entry),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: null,
    );
  }
}

class _BucketHeader extends StatelessWidget {
  final bool receivables;
  final Color subtext;

  const _BucketHeader({required this.receivables, required this.subtext});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget bucket(String label) => Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: subtext,
            fontWeight: FontWeight.bold,
          ),
        );
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            receivables ? 'مشتری' : 'تأمین‌کننده',
            style: theme.textTheme.labelSmall?.copyWith(
              color: subtext,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              bucket('جاری'),
              bucket('۱-۳۰'),
              bucket('۳۱-۶۰'),
              bucket('۶۱-۹۰'),
              bucket('+۹۰'),
            ],
          ),
        ),
      ],
    );
  }
}

class _AgingCard extends StatelessWidget {
  final ContactAgingEntry entry;

  const _AgingCard({required this.entry});

  ({String label, int minor, Color color}) _bucket(
    String label,
    int minor,
    Color color,
  ) =>
      (label: label, minor: minor, color: color);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    final buckets = [
      _bucket('جاری', entry.currentMinor, AppColors.income),
      _bucket('۱-۳۰', entry.days1To30Minor, AppColors.warning),
      _bucket('۳۱-۶۰', entry.days31To60Minor, Colors.orange),
      _bucket('۶۱-۹۰', entry.days61To90Minor, Colors.deepOrange),
      _bucket('+۹۰', entry.days90PlusMinor, AppColors.expense),
    ];

    return AppCard(
      onTap: entry.totalMinor > 0
          ? () => context.push('/business', extra: entry.contactId)
          : null,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  entry.contactName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${TextNormalizer.auto(Money.fromMinor(entry.totalMinor).format())} تومان',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (final b in buckets) ...[
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: b.minor > 0
                          ? b.color.withValues(alpha: 0.12)
                          : (isDark
                                ? AppColors.darkSurface
                                : AppColors.lightSurfaceVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          b.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: b.minor > 0 ? b.color : subtext,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          b.minor > 0
                              ? TextNormalizer.auto(
                                  Money.fromMinor(b.minor).formatCompact(),
                                )
                              : '—',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: b.minor > 0 ? b.color : subtext,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
