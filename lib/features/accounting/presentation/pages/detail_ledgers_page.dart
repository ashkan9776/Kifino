import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../domain/entities/accounting_audit_entity.dart';
import '../bloc/detail_ledger_cubit.dart';
import 'detail_report_page.dart';

/// تفصیلی شناور — manage floating analysis dimensions (ledgers) and their
/// values. Documents tag one value per ledger; reports slice by value.
class DetailLedgersPage extends StatelessWidget {
  const DetailLedgersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DetailLedgerCubit>(
      create: (_) => sl<DetailLedgerCubit>()..load(),
      child: const _DetailLedgersView(),
    );
  }
}

class _DetailLedgersView extends StatefulWidget {
  const _DetailLedgersView();

  @override
  State<_DetailLedgersView> createState() => _DetailLedgersViewState();
}

class _DetailLedgersViewState extends State<_DetailLedgersView> {
  final Set<String> _expandedLedgerIds = {};

  void _toggleExpanded(String ledgerId) {
    setState(() {
      if (!_expandedLedgerIds.add(ledgerId)) {
        _expandedLedgerIds.remove(ledgerId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;

    return Scaffold(
      appBar: AppBar(title: const Text('تفصیلی شناور'), centerTitle: true),
      body: BlocConsumer<DetailLedgerCubit, DetailLedgerState>(
        listener: (context, state) {
          if (state is DetailLedgerLoaded && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: colors.expense,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is DetailLedgerLoading) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: List.generate(
                4,
                (index) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: AppSkeleton(height: 88),
                ),
              ),
            );
          }

          if (state is DetailLedgerError) {
            return AppEmptyState(
              icon: Icons.error_outline,
              title: 'خطا در دریافت تفصیلی‌ها',
              description: state.message,
              actionLabel: 'تلاش مجدد',
              onAction: () => context.read<DetailLedgerCubit>().load(),
            );
          }

          if (state is DetailLedgerLoaded) {
            if (state.ledgers.isEmpty) {
              return const AppEmptyState(
                icon: Icons.category_outlined,
                title: 'هنوز تفصیلی شناوری تعریف نشده است',
                description: 'تفصیلی شناور بُعد تحلیلی اسناد است (مانند مشتریان، پروژه‌ها یا مراکز هزینه) بدون ایجاد سرفصل موازی.',
              );
            }
            return RefreshIndicator(
              onRefresh: () async => context.read<DetailLedgerCubit>().load(),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: state.ledgers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _LedgerCard(
                    item: state.ledgers[index],
                    expanded: _expandedLedgerIds.contains(
                      state.ledgers[index].ledger.id,
                    ),
                    onToggle: () =>
                        _toggleExpanded(state.ledgers[index].ledger.id),
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLedgerSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('تفصیلی جدید'),
      ),
    );
  }

  Future<void> _showLedgerSheet(
    BuildContext context, {
    String? ledgerId,
    String? initialTitle,
  }) {
    return _showFormSheet(
      context,
      title: ledgerId == null
          ? 'تعریف تفصیلی شناور جدید'
          : 'ویرایش عنوان تفصیلی',
      fields: [
        _SheetField(
          label: 'عنوان تفصیلی',
          hint: 'مثال: مشتریان، پروژه‌ها، مراکز هزینه',
          initial: initialTitle ?? '',
          isRequired: true,
        ),
        if (ledgerId == null)
          const _SheetField(
            label: 'پیشوند کد',
            hint: 'مثال: 90',
            isRequired: true,
          ),
      ],
      onSubmit: (values) async {
        final cubit = context.read<DetailLedgerCubit>();
        final ok = ledgerId == null
            ? await cubit.createLedger(title: values[0], code: values[1])
            : await cubit.renameLedger(id: ledgerId, title: values[0]);
        return ok ? null : _lastError(cubit);
      },
    );
  }

  Future<void> _showValueSheet(BuildContext context, String ledgerId) {
    return _showFormSheet(
      context,
      title: 'افزودن مقدار به تفصیلی',
      fields: [
        const _SheetField(
          label: 'عنوان مقدار',
          hint: 'مثال: شرکت الف',
          isRequired: true,
        ),
        const _SheetField(
          label: 'کد (اختیاری)',
          hint: 'مثال: 01',
          isRequired: false,
        ),
      ],
      onSubmit: (values) async {
        final cubit = context.read<DetailLedgerCubit>();
        final ok = await cubit.createValue(
          ledgerId: ledgerId,
          title: values[0],
          code: values[1].isEmpty ? null : values[1],
        );
        return ok ? null : _lastError(cubit);
      },
    );
  }

  String _lastError(DetailLedgerCubit cubit) {
    final state = cubit.state;
    if (state is DetailLedgerLoaded && state.errorMessage != null) {
      return state.errorMessage!;
    }
    return 'خطا در ذخیره‌سازی';
  }

  Future<void> _showFormSheet(
    BuildContext context, {
    required String title,
    required List<_SheetField> fields,
    required Future<String?> Function(List<String> values) onSubmit,
  }) {
    final controllers = fields
        .map((f) => TextEditingController(text: f.initial))
        .toList();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        String? submitError;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return AppBottomSheet(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSheetHeader(title: title),
                    const SizedBox(height: 8),
                    for (var i = 0; i < fields.length; i++) ...[
                      TextField(
                        controller: controllers[i],
                        decoration: InputDecoration(
                          labelText:
                              fields[i].label +
                              (fields[i].isRequired ? ' *' : ''),
                          hintText: fields[i].hint,
                        ),
                        textInputAction: i == fields.length - 1
                            ? TextInputAction.done
                            : TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (submitError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          submitError!,
                          style: AppTypography.bodySmall.copyWith(
                            color: Colors.red,
                          ),
                        ),
                      ),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final values = controllers
                              .map((c) => c.text.trim())
                              .toList();
                          final missing = <String>[];
                          for (var i = 0; i < fields.length; i++) {
                            if (fields[i].isRequired && values[i].isEmpty) {
                              missing.add(fields[i].label);
                            }
                          }
                          if (missing.isNotEmpty) {
                            setSheetState(
                              () => submitError =
                                  'پر کردن ${missing.join(' و ')} الزامی است',
                            );
                            return;
                          }
                          final failure = await onSubmit(values);
                          if (!sheetContext.mounted) return;
                          if (failure == null) {
                            Navigator.of(sheetContext).pop();
                          } else {
                            setSheetState(() => submitError = failure);
                          }
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('ذخیره'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      for (final c in controllers) {
        c.dispose();
      }
    });
  }
}

class _SheetField {
  final String label;
  final String hint;
  final String initial;
  final bool isRequired;

  const _SheetField({
    required this.label,
    required this.hint,
    this.initial = '',
    required this.isRequired,
  });
}

class _LedgerCard extends StatelessWidget {
  final DetailLedgerWithValues item;
  final bool expanded;
  final VoidCallback onToggle;

  const _LedgerCard({
    required this.item,
    required this.expanded,
    required this.onToggle,
  });

  /// Shared delete confirmation — soft-delete keeps past report history.
  void _confirmDelete(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    final colors = context.customColors;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message, style: AppTypography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.expense),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onConfirm();
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteLedger(BuildContext context) {
    final cubit = context.read<DetailLedgerCubit>();
    _confirmDelete(
      context,
      title: 'حذف تفصیلی شناور',
      message:
          '«${item.ledger.title}» و همه مقادیر آن حذف می‌شوند. برچسب‌های اسناد قبلی باقی می‌مانند و گزارش‌های گذشته سابقه خود را حفظ می‌کنند، اما امکان برچسب‌گذاری سند جدید با این تفصیلی وجود نخواهد داشت.',
      onConfirm: () => cubit.deleteLedger(item.ledger.id),
    );
  }

  void _confirmDeleteValue(BuildContext context, DetailValueEntity value) {
    final cubit = context.read<DetailLedgerCubit>();
    _confirmDelete(
      context,
      title: 'حذف مقدار تفصیلی',
      message:
          '«${value.title}» حذف می‌شود. برچسب اسناد قبلی حفظ می‌شود و گزارش‌های گذشته به‌کار خود ادامه می‌دهند.',
      onConfirm: () => cubit.deleteValue(value.id),
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    Color? color,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.surfaceBorder),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.receivable.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.category_outlined,
                      color: colors.receivable,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.ledger.title,
                          style: AppTypography.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'کد ${TextNormalizer.auto(item.ledger.code)} • '
                          '${TextNormalizer.auto(item.values.length.toString())} مقدار',
                          style: AppTypography.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!item.ledger.isActive)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 4),
                      child: Icon(
                        Icons.visibility_off,
                        size: 16,
                        color: colors.textTertiary,
                      ),
                    ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: colors.textSecondary,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'عملیات تفصیلی',
                    icon: Icon(Icons.more_vert, color: colors.textSecondary),
                    onSelected: (action) {
                      final view = context
                          .findAncestorStateOfType<_DetailLedgersViewState>();
                      switch (action) {
                        case 'add_value':
                          view?._showValueSheet(context, item.ledger.id);
                        case 'rename':
                          view?._showLedgerSheet(
                            context,
                            ledgerId: item.ledger.id,
                            initialTitle: item.ledger.title,
                          );
                        case 'delete':
                          _confirmDeleteLedger(context);
                      }
                    },
                    itemBuilder: (menuContext) => [
                      _menuItem(
                        'add_value',
                        Icons.add_circle_outline,
                        'افزودن مقدار',
                      ),
                      _menuItem('rename', Icons.edit_outlined, 'ویرایش عنوان'),
                      _menuItem(
                        'delete',
                        Icons.delete_outline,
                        'حذف تفصیلی',
                        color: colors.expense,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: colors.surfaceBorder),
            if (item.values.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'هنوز مقداری برای این تفصیلی ثبت نشده است',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              )
            else
              ...item.values.map(
                (value) => _ValueTile(
                  value: value,
                  colors: colors,
                  onDelete: () => _confirmDeleteValue(context, value),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ValueTile extends StatelessWidget {
  final DetailValueEntity value;
  final KifinoColorsExtension colors;
  final VoidCallback onDelete;

  const _ValueTile({
    required this.value,
    required this.colors,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: Icon(
        value.isActive ? Icons.label_outline : Icons.label_off_outlined,
        size: 18,
        color: value.isActive ? colors.primary : colors.textTertiary,
      ),
      title: Text(
        value.title,
        style: AppTypography.bodyMedium.copyWith(
          fontWeight: FontWeight.w600,
          color: value.isActive ? null : colors.textSecondary,
        ),
      ),
      subtitle: value.code != null && value.code!.isNotEmpty
          ? Text(
              'کد ${TextNormalizer.auto(value.code!)}',
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'گزارش تفصیلی',
            icon: const Icon(Icons.assessment_outlined, size: 20),
            onPressed: () => context.push(
              '/accounting/detail-ledgers/report',
              extra: DetailReportSelection(
                ledgerId: value.ledgerId,
                valueId: value.id,
              ),
            ),
          ),
          IconButton(
            tooltip: 'حذف مقدار',
            icon: Icon(Icons.close, size: 18, color: colors.expense),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
