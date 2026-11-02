import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../accounting/domain/entities/accounting_audit_entity.dart';
import '../../../accounting/domain/repositories/accounting_repository.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../domain/entities/check_entity.dart';

/// Status history of one check, fed live by the accounting audit trail
/// (entityType 'check'). Every status change writes a before/after entry in
/// the repository, so a mis-tap and its correction are both visible here.
/// Each row expands to show the raw before/after JSON snapshot.
class CheckStatusHistorySheet extends StatefulWidget {
  final CheckEntity check;

  const CheckStatusHistorySheet({super.key, required this.check});

  /// Convenience opener.
  static Future<void> show(BuildContext context, CheckEntity check) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CheckStatusHistorySheet(check: check),
    );
  }

  @override
  State<CheckStatusHistorySheet> createState() =>
      _CheckStatusHistorySheetState();
}

class _CheckStatusHistorySheetState extends State<CheckStatusHistorySheet> {
  late final Stream<List<AccountingAuditLogEntity>> _logs;

  @override
  void initState() {
    super.initState();
    // Resolve once: Drift .watch() streams must not be re-created per rebuild.
    _logs = sl<AccountingRepository>().watchEntityAuditLogs(
      entityType: 'check',
      entityId: widget.check.id,
    );
  }

  String _prettyJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '—';
    try {
      final decoded = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final isFa = l10n.isPersian;
    final check = widget.check;

    return AppBottomSheet(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSheetHeader(
              title: isFa ? 'تاریخچه وضعیت چک' : 'Check Status History',
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${isFa ? 'چک' : 'Check'} ${TextNormalizer.auto(check.checkNumber)} — ${check.partyName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: StreamBuilder<List<AccountingAuditLogEntity>>(
                stream: _logs,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xl,
                      ),
                      child: Text(
                        '${isFa ? 'خطا' : 'Error'}: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppSkeleton(
                          height: 56,
                          borderRadius: AppSpacing.borderRadiusSm,
                        ),
                        SizedBox(height: AppSpacing.xs),
                        AppSkeleton(
                          height: 56,
                          borderRadius: AppSpacing.borderRadiusSm,
                        ),
                        SizedBox(height: AppSpacing.xs),
                        AppSkeleton(
                          height: 56,
                          borderRadius: AppSpacing.borderRadiusSm,
                        ),
                      ],
                    );
                  }

                  final logs = snapshot.data!;
                  if (logs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xl,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 40,
                            color: isDark
                                ? AppColors.darkSubtext
                                : AppColors.lightSubtext,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            isFa
                                ? 'هنوز تغییری در وضعیت این چک ثبت نشده است'
                                : 'No status changes recorded yet',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? AppColors.darkSubtext
                                  : AppColors.lightSubtext,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: logs.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) => _HistoryRow(
                      log: logs[index],
                      prettyBefore: _prettyJson(logs[index].beforeJson),
                      prettyAfter: _prettyJson(logs[index].afterJson),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatefulWidget {
  final AccountingAuditLogEntity log;
  final String prettyBefore;
  final String prettyAfter;

  const _HistoryRow({
    required this.log,
    required this.prettyBefore,
    required this.prettyAfter,
  });

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _expanded = false;

  (IconData, Color, String) _actionStyle(bool isFa, bool isDark) {
    return switch (widget.log.action) {
      AuditLogAction.create => (
        Icons.add_circle_outline_rounded,
        AppColors.income,
        isFa ? 'ثبت چک' : 'Created',
      ),
      AuditLogAction.update => (
        Icons.published_with_changes_rounded,
        isDark ? AppColors.primaryBlueDark : AppColors.primaryBlueLight,
        isFa ? 'تغییر وضعیت' : 'Status changed',
      ),
      AuditLogAction.approve => (
        Icons.verified_outlined,
        AppColors.income,
        isFa ? 'تایید' : 'Approved',
      ),
      AuditLogAction.delete => (
        Icons.delete_outline_rounded,
        AppColors.danger,
        isFa ? 'حذف' : 'Deleted',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final isFa = l10n.isPersian;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    final (icon, color, fallbackTitle) = _actionStyle(isFa, isDark);
    final title =
        (widget.log.description != null && widget.log.description!.isNotEmpty)
        ? widget.log.description!
        : fallbackTitle;
    final when =
        '${AppDateFormatter.format(widget.log.performedAt, locale: l10n.localeName)} · ${AppDateFormatter.formatTime(widget.log.performedAt, locale: l10n.localeName)}';

    return InkWell(
      borderRadius: AppSpacing.borderRadiusSm,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color:
              (isDark ? AppColors.darkSurface : AppColors.lightSurfaceVariant)
                  .withValues(alpha: 0.55),
          borderRadius: AppSpacing.borderRadiusSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        TextNormalizer.auto(when),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: subtext,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: subtext,
                  ),
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: AppSpacing.sm),
              _jsonBlock(
                isFa ? 'قبل' : 'Before',
                widget.prettyBefore,
                theme,
                isDark,
              ),
              const SizedBox(height: AppSpacing.xs),
              _jsonBlock(
                isFa ? 'بعد' : 'After',
                widget.prettyAfter,
                theme,
                isDark,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _jsonBlock(String label, String pretty, ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.darkSurface : AppColors.lightSurface)
                .withValues(alpha: 0.8),
            borderRadius: AppSpacing.borderRadiusXs,
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              pretty,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
