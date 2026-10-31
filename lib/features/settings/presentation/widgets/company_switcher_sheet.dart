import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/company_controller.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/database/company_registry.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_skeleton.dart';

/// Quick company switcher (Phase 5): lists registered companies (دفتر),
/// switches the active one, creates new ones and deletes inactive ones.
/// Switching disposes the company-scoped singletons and rebuilds the whole
/// widget tree under the new company key.
Future<void> showCompanySwitcherSheet(BuildContext context) async {
  final controller = sl<CompanyController>();
  if (!controller.initialized) {
    await controller.initialize();
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => const _CompanySwitcherSheet(),
  );
}

class _CompanySwitcherSheet extends StatefulWidget {
  const _CompanySwitcherSheet();

  @override
  State<_CompanySwitcherSheet> createState() => _CompanySwitcherSheetState();
}

class _CompanySwitcherSheetState extends State<_CompanySwitcherSheet> {
  late Future<List<CompanyInfo>> _companiesFuture;
  bool _switching = false;
  bool _creating = false;
  final TextEditingController _newNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _companiesFuture = sl<CompanyController>().companies();
  }

  Future<void> _switch(String id, String name) async {
    // Capture everything before the async gap: the whole widget tree is
    // rebuilt during the switch, so `context` cannot be used after it.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _switching = true);
    try {
      await sl<CompanyController>().switchTo(id);
      // Pop both the sheet and the MorePage — the whole tree rebuilds under
      // the new company key.
      if (navigator.canPop()) navigator.pop();
      if (navigator.canPop()) navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('به «$name» تغییر شرکت داده شد.')),
      );
    } catch (e) {
      if (mounted) setState(() => _switching = false);
      messenger.showSnackBar(
        SnackBar(content: Text('تغییر شرکت انجام نشد. دوباره تلاش کنید.')),
      );
    }
  }

  Future<void> _createCompany() async {
    final name = _newNameController.text.trim();
    if (name.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _creating = true);
    try {
      await sl<CompanyController>().createCompany(name);
      _newNameController.clear();
      if (mounted) setState(() => _creating = false);
      _reload();
      messenger.showSnackBar(
        SnackBar(content: Text('«$name» ساخته شد و فعال است.')),
      );
    } catch (e) {
      if (mounted) setState(() => _creating = false);
      messenger.showSnackBar(
        SnackBar(content: Text('ساخت شرکت انجام نشد. دوباره تلاش کنید.')),
      );
    }
  }

  Future<void> _deleteCompany(CompanyInfo company) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف شرکت؟'),
        content: Text(
          'تمام داده‌های «${company.name}» (حساب‌ها، تراکنش‌ها، اسناد حسابداری و …) برای همیشه حذف می‌شوند. این عمل قابل بازگشت نیست.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف کامل'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await sl<CompanyController>().deleteCompany(company.id);
      _reload();
    }
  }

  @override
  void dispose() {
    _newNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSheetHeader(title: 'شرکت‌ها و دفاتر'),
              Text(
                'هر شرکت یک دفتر حسابداری مستقل با دیتابیس جداگانه دارد. تغییر شرکت، کل اپ را با داده‌های همان شرکت بازسازی می‌کند.',
                style: AppTypography.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              FutureBuilder<List<CompanyInfo>>(
                future: _companiesFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: AppSkeleton(height: 100),
                    );
                  }
                  final activeId = sl<CompanyController>().activeCompanyId;
                  return Column(
                    children: [
                      for (final company in snapshot.data!)
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: AppSpacing.borderRadiusMd,
                          ),
                          title: Text(company.name, style: AppTypography.bodyLarge),
                          leading: Icon(
                            company.id == activeId
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            color: company.id == activeId
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                          trailing: company.id != CompanyRegistry.defaultCompanyId
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                  tooltip: 'حذف شرکت',
                                  onPressed: _switching
                                      ? null
                                      : () => _deleteCompany(company),
                                )
                              : null,
                          onTap: (_switching || company.id == activeId)
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  _switch(company.id, company.name);
                                },
                        ),
                    ],
                  );
                },
              ),

              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newNameController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _creating ? null : _createCompany(),
                      decoration: const InputDecoration(
                        labelText: 'نام شرکت یا دفتر جدید',
                        prefixIcon: Icon(Icons.business_center_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _creating
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton.filled(
                          onPressed: _createCompany,
                          icon: const Icon(Icons.add_rounded),
                          tooltip: 'افزودن شرکت',
                        ),
                ],
              ),
              if (_switching) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'در حال بازسازی داده‌ها…',
                      style: AppTypography.labelMedium,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
