import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../domain/entities/accounting_audit_entity.dart';
import '../bloc/audit_log_cubit.dart';

/// Live audit trail of accounting documents (Phase 1): what changed, when,
/// with pretty-printed before/after JSON snapshots per entry.
class AuditLogPage extends StatelessWidget {
  const AuditLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuditLogCubit>(
      create: (_) => sl<AuditLogCubit>()..watch(),
      child: const _AuditLogView(),
    );
  }
}

class _AuditLogView extends StatelessWidget {
  const _AuditLogView();

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('لاگ حسابرسی'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تازه‌سازی',
            onPressed: () => context.read<AuditLogCubit>().watch(),
          ),
        ],
      ),
      body: BlocBuilder<AuditLogCubit, AuditLogState>(
        builder: (context, state) {
          if (state is AuditLogLoading) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: List.generate(
                8,
                (index) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: AppSkeleton(height: 72),
                ),
              ),
            );
          }

          if (state is AuditLogError) {
            return AppEmptyState(
              icon: Icons.error_outline,
              title: 'خطا در دریافت لاگ حسابرسی',
              description: state.message,
              actionLabel: 'تلاش مجدد',
              onAction: () => context.read<AuditLogCubit>().watch(),
            );
          }

          if (state is AuditLogLoaded) {
            if (state.logs.isEmpty) {
              return const AppEmptyState(
                icon: Icons.history_toggle_off,
                title: 'رخدادی ثبت نشده است',
                description:
                    'هر ایجاد، تأیید، ویرایش یا حذف سند حسابداری به‌صورت خودکار در همین صفحه ثبت می‌شود.',
              );
            }
            return RefreshIndicator(
              onRefresh: () async => context.read<AuditLogCubit>().watch(),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: state.logs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return _AuditTile(
                    log: state.logs[index],
                    colors: colors,
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  final AccountingAuditLogEntity log;
  final KifinoColorsExtension colors;

  const _AuditTile({required this.log, required this.colors});

  (IconData, Color, String) get _actionStyle {
    switch (log.action) {
      case AuditLogAction.create:
        return (Icons.add_circle, Colors.blue, 'ایجاد سند');
      case AuditLogAction.approve:
        return (Icons.check_circle, Colors.green, 'تأیید سند');
      case AuditLogAction.update:
        return (Icons.edit, Colors.orange, 'ویرایش سند');
      case AuditLogAction.delete:
        return (Icons.delete, Colors.red, 'حذف سند');
    }
  }

  String get _subtitle {
    final jDate = JalaliDate.fromDateTime(log.performedAt);
    final time = AppDateFormatter.formatTime(log.performedAt, locale: 'fa');
    return '${jDate.formatFull()} • $time';
  }

  void _showJsonDialog(BuildContext context) {
    final shortId =
        log.entityId.length > 8 ? log.entityId.substring(0, 8) : log.entityId;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(_actionStyle.$1, size: 20, color: _actionStyle.$2),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_actionStyle.$3} #${TextNormalizer.auto(shortId)}',
                  style: AppTypography.titleMedium,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (log.description != null && log.description!.isNotEmpty) ...[
                    Text(log.description!, style: AppTypography.bodyMedium),
                    const SizedBox(height: 12),
                  ],
                  if (log.beforeJson != null) _jsonSection('وضعیت قبل', log.beforeJson!),
                  if (log.afterJson != null) _jsonSection('وضعیت بعد', log.afterJson!),
                  if (log.beforeJson == null && log.afterJson == null)
                    Text(
                      'تصویری از وضعیت قبل/بعد برای این رخداد ذخیره نشده است.',
                      style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
                    ),
                  const SizedBox(height: 12),
                  Text(_subtitle, style: AppTypography.bodySmall.copyWith(color: colors.textSecondary)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('بستن'),
            ),
          ],
        );
      },
    );
  }

  Widget _jsonSection(String label, String rawJson) {
    String pretty = rawJson;
    try {
      pretty = const JsonEncoder.withIndent('  ').convert(jsonDecode(rawJson));
    } catch (_) {
      // Not valid JSON — show the raw payload untouched.
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.titleSmall),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.textSecondary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              pretty,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color, fallbackTitle) = _actionStyle;
    final title =
        (log.description != null && log.description!.isNotEmpty) ? log.description! : fallbackTitle;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.surfaceBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: AppTypography.titleSmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_subtitle, style: AppTypography.bodySmall.copyWith(color: colors.textSecondary)),
        ),
        trailing: Icon(Icons.chevron_left, size: 20, color: colors.textSecondary),
        onTap: () => _showJsonDialog(context),
      ),
    );
  }
}
