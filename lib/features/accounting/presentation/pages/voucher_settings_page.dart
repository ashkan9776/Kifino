import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../accounting/domain/entities/accounting_subject_entity.dart';
import '../../../accounting/domain/repositories/accounting_repository.dart';
import '../../../accounting/domain/services/voucher_settings_service.dart';
import '../../../../core/di/injection.dart';

/// Configurable counterpart accounts for automatic vouchers (Phase 2):
/// each voucher line maps to a chart-of-accounts code the user can change.
class VoucherSettingsPage extends StatefulWidget {
  const VoucherSettingsPage({super.key});

  @override
  State<VoucherSettingsPage> createState() => _VoucherSettingsPageState();
}

class _VoucherSettingsPageState extends State<VoucherSettingsPage> {
  List<AccountingSubjectEntity>? _subjects;
  late VoucherAccountSettings _settings;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _settings = sl<VoucherSettingsService>().load();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final result = await sl<AccountingRepository>().getAllSubjects();
    if (!mounted) return;
    setState(() {
      // Only kol/moein accounts can back a voucher line.
      _subjects = result
          .where((s) =>
              s.level == AccountingSubjectLevel.kol ||
              s.level == AccountingSubjectLevel.moein)
          .toList();
    });
  }

  Future<void> _save() async {
    await sl<VoucherSettingsService>().save(_settings);
    if (!mounted) return;
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  Future<void> _pickSubject(String currentCode, ValueChanged<String> onPicked) async {
    final subjects = _subjects;
    if (subjects == null) return;
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => AppBottomSheet(
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.7,
            child: Column(
              children: [
                AppSheetHeader(title: l10n.isPersian ? 'انتخاب حساب' : 'Select account'),
                Expanded(
                  child: ListView(
                    children: [
                      for (final subject in subjects)
                        ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppSpacing.borderRadiusMd,
                          ),
                          title: Text('${subject.formattedCode} — ${subject.name}'),
                          trailing: subject.code == currentCode
                              ? const Icon(Icons.check_circle_rounded,
                                  color: AppColors.income)
                              : null,
                          onTap: () {
                            onPicked(subject.code);
                            Navigator.pop(sheetContext);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isPersian = l10n.isPersian;

    final rows = <(String, String)>[
      (isPersian ? 'فروش' : 'Sales', _settings.salesCode),
      (isPersian ? 'حساب‌های دریافتنی' : 'Accounts receivable', _settings.receivableCode),
      (isPersian ? 'مالیات فروش' : 'Output VAT', _settings.vatOutputCode),
      (isPersian ? 'تخفیف فروش' : 'Sales discount', _settings.discountSalesCode),
      (isPersian ? 'موجودی کالا' : 'Inventory', _settings.inventoryCode),
      (isPersian ? 'خرید' : 'Purchases', _settings.purchaseCode),
      (isPersian ? 'بستانکاران' : 'Accounts payable', _settings.payableCode),
      (isPersian ? 'مالیات خرید' : 'Input VAT', _settings.vatInputCode),
      (isPersian ? 'تخفیف خرید' : 'Purchase discount', _settings.purchaseDiscountCode),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(isPersian ? 'حساب‌های سند خودکار' : 'Auto-voucher accounts')),
      body: _subjects == null
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: AppSkeleton(height: 300),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    isPersian
                        ? 'با ثبت هر فاکتور، یک سند حسابداری خودکار ساخته می‌شود. حساب‌های طرف مقابل هر سطر را اینجا تنظیم کن.'
                        : 'Every invoice creates an automatic voucher. Configure the counterpart account for each line here.',
                    style: AppTypography.bodyMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, indent: AppSpacing.xl, color: Theme.of(context).dividerColor),
                        ListTile(
                          title: Text(rows[i].$1, style: AppTypography.bodyLarge),
                          subtitle: Text(rows[i].$2, style: AppTypography.labelMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                          )),
                          trailing: const Icon(Icons.chevron_left_rounded, size: 20),
                          onTap: () => _pickSubject(rows[i].$2, (code) {
                            setState(() {
                              _settings = _settings.copyWith(
                                salesCode: i == 0 ? code : null,
                                receivableCode: i == 1 ? code : null,
                                vatOutputCode: i == 2 ? code : null,
                                discountSalesCode: i == 3 ? code : null,
                                inventoryCode: i == 4 ? code : null,
                                purchaseCode: i == 5 ? code : null,
                                payableCode: i == 6 ? code : null,
                                vatInputCode: i == 7 ? code : null,
                                purchaseDiscountCode: i == 8 ? code : null,
                              );
                            });
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: _saved
                      ? (isPersian ? 'ذخیره شد ✓' : 'Saved ✓')
                      : (isPersian ? 'ذخیره تنظیمات' : 'Save settings'),
                  onPressed: _save,
                ),
              ],
            ),
    );
  }
}
