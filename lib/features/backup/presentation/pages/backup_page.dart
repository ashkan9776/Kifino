import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';

import 'dart:convert';

import '../../../../core/di/injection.dart';
import '../../../../core/services/file_transfer.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_kit.dart';
import '../../../../core/widgets/export_sheet.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../domain/services/backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final _passwordController = TextEditingController();
  final _restorePasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isExportingCsv = false;
  bool _isRepairing = false;

  void _toast(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _exportCsv() async {
    setState(() => _isExportingCsv = true);
    try {
      final result = await sl<BackupService>().buildTransactionsCsv();
      if (!mounted) return;
      // The file is ready; the button shouldn't spin while the user picks
      // where it goes.
      setState(() => _isExportingCsv = false);
      await result.fold(
        onSuccess: (file) => showExportSheet(
          context,
          file: file,
          title: 'فایل اکسل تراکنش‌ها آماده است',
        ),
        onFailure: (failure) async => _toast(failure.message),
      );
    } finally {
      if (mounted) setState(() => _isExportingCsv = false);
    }
  }

  /// Rebuilds every account balance from its opening balance plus all
  /// active transactions — fixes drift left by older app versions.
  Future<void> _repairBalances() async {
    setState(() => _isRepairing = true);
    try {
      final result = await sl<TransactionRepository>().recomputeBalances();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isSuccess
                ? 'مانده همه حساب‌ها از روی تراکنش‌ها بازسازی شد.'
                : result.failureOrNull!.message,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isRepairing = false);
    }
  }

  void _showCreateBackupDialog() {
    _passwordController.clear();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final password = _passwordController.text;
          final strength = BackupService.evaluatePasswordStrength(password);
          final isValid = password.length >= 8;

          final (strengthLabel, strengthColor) = switch (strength) {
            4 => ('بسیار قوی', AppColors.income),
            3 => ('خوب', AppColors.income),
            2 => ('متوسط', AppColors.warning),
            1 => ('ضعیف', AppColors.danger),
            _ => ('بسیار ضعیف (حداقل ۸ کاراکتر)', AppColors.lightTextTertiary),
          };

          return AlertDialog(
            title: const Text('رمز فایل پشتیبان'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'یک رمز عبور با حداقل ۸ کاراکتر برای محافظت از اطلاعات مالی خود وارد کنید:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    labelText: 'رمز عبور پشتیبان',
                    prefixIcon: const Icon(Icons.key_rounded),
                    errorText: password.isNotEmpty && !isValid
                        ? 'رمز عبور باید حداقل ۸ کاراکتر باشد'
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Text(
                      'قدرت رمز: ',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      strengthLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: strengthColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: password.isEmpty ? 0 : (strength.clamp(1, 4) / 4),
                    backgroundColor: AppColors.lightTextTertiary.withValues(
                      alpha: 0.2,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('انصراف'),
              ),
              ElevatedButton(
                onPressed: isValid
                    ? () async {
                        final pwd = _passwordController.text.trim();
                        Navigator.pop(ctx);
                        setState(() => _isLoading = true);

                        final result = await sl<BackupService>()
                            .buildEncryptedBackup(password: pwd);

                        if (!mounted) return;
                        setState(() => _isLoading = false);

                        await result.fold(
                          // The dialog (and its `context`) is gone by now;
                          // the sheet belongs to the page.
                          onSuccess: (file) => showExportSheet(
                            this.context,
                            file: file,
                            title: 'فایل پشتیبان آماده است',
                            note:
                                'فایل را جایی نگه دارید که با حذف برنامه پاک '
                                'نشود (مثلاً پوشه Download، کارت حافظه یا '
                                'پیام‌های ذخیره‌شده تلگرام). بدون رمز عبور، '
                                'بازیابی ممکن نیست.',
                          ),
                          onFailure: (err) async =>
                              _toast('خطا: ${err.message}'),
                        );
                      }
                    : null,
                child: const Text('ایجاد پشتیبان'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Restore: the system file picker first (Downloads, SD card, Drive…),
  /// then the password — with a clear warning that it replaces everything.
  Future<void> _pickAndRestore() async {
    final PickedFile? picked;
    try {
      picked = await sl<FileTransfer>().pick();
    } catch (e) {
      _toast('باز کردن فایل انجام نشد: $e');
      return;
    }
    if (picked == null || !mounted) return;

    final String content;
    try {
      content = utf8.decode(picked.bytes);
    } on FormatException {
      _toast('این فایل، پشتیبان کیفینو نیست.');
      return;
    }

    _restorePasswordController.clear();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بازیابی اطلاعات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppListGroup(
              children: [
                AppListRow(
                  icon: Icons.insert_drive_file_outlined,
                  title: picked!.name,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppNotice(
              icon: Icons.warning_amber_rounded,
              color: AppColors.danger,
              message:
                  'همه اطلاعات فعلی این دفتر حذف و با محتوای این فایل '
                  'جایگزین می‌شود.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _restorePasswordController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'رمز عبور پشتیبان',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              final pwd = _restorePasswordController.text.trim();
              if (pwd.isNotEmpty) Navigator.pop(ctx, pwd);
            },
            child: const Text('جایگزینی و بازیابی'),
          ),
        ],
      ),
    );
    if (password == null || !mounted) return;

    setState(() => _isLoading = true);
    final result = await sl<BackupService>().restoreEncryptedBackupContent(
      content: content,
      password: password,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    result.fold(
      onSuccess: (metadata) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              metadata.isLegacyFormat
                  ? 'اطلاعات با موفقیت بازیابی شد!\nتوجه: این پشتیبان با ساختار قدیمی بازیابی شد. برای امنیت بیشتر، پیشنهاد می‌شود یک پشتیبان جدید (AES-GCM) ایجاد کنید.'
                  : 'اطلاعات با موفقیت بازیابی شد!\nتراکنش‌ها: ${metadata.entityCounts["transactions"] ?? 0} | حساب‌ها: ${metadata.entityCounts["accounts"] ?? 0}',
            ),
            duration: const Duration(seconds: 5),
            backgroundColor: metadata.isLegacyFormat
                ? AppColors.debtOrangeLight
                : null,
          ),
        );
      },
      onFailure: (err) => _toast('خطای بازیابی: ${err.message}'),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _restorePasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Scaffold(
          appBar: AppBar(title: const Text('پشتیبان‌گیری و بازیابی')),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // 1. Export Card
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.cloud_upload_outlined,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'پشتیبان‌گیری کامل از اطلاعات',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'رمزنگاری‌شده با استاندارد نظامی AES-256',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkSubtext
                                        : AppColors.lightSubtext,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'از تمامی حساب‌ها، تراکنش‌ها، چک‌ها، اقساط، فاکتورها و مخاطبان یک فایل رمزگذاری‌شده تهیه می‌شود. بعد انتخاب می‌کنید کجا ذخیره شود یا برای چه کسی ارسال شود.',
                        style: TextStyle(fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: _isLoading
                            ? 'در حال تهیه پشتیبان...'
                            : 'تهیه فایل پشتیبان',
                        icon: const Icon(Icons.lock_outline_rounded, size: 20),
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _showCreateBackupDialog,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // 1.5 Excel (CSV) Export Card
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.accentIndigo.withValues(
                                alpha: 0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.table_view_rounded,
                              color: AppColors.accentIndigo,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'خروجی اکسل (CSV)',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'تمام تراکنش‌ها با تاریخ شمسی، قابل بازکردن در Excel',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkSubtext
                                        : AppColors.lightSubtext,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: _isExportingCsv
                            ? 'در حال ساخت فایل...'
                            : 'ساخت فایل اکسل تراکنش‌ها',
                        variant: AppButtonVariant.outline,
                        icon: const Icon(Icons.ios_share_rounded, size: 20),
                        isLoading: _isExportingCsv,
                        onPressed: _isExportingCsv ? null : _exportCsv,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // 2. Restore Card
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.income.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.settings_backup_restore_rounded,
                              color: AppColors.income,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'بازیابی از فایل پشتیبان',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'بازگردانی کامل اطلاعات از فایل .kfn',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkSubtext
                                        : AppColors.lightSubtext,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'فایل .kfn را از پوشه Download، کارت حافظه، Google Drive یا هر جای دیگری انتخاب کنید. اطلاعات فعلی با محتوای فایل جایگزین می‌شود.',
                        style: TextStyle(fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'انتخاب فایل پشتیبان',
                        variant: AppButtonVariant.outline,
                        icon: const Icon(Icons.upload_file_rounded, size: 20),
                        onPressed: _isLoading ? null : _pickAndRestore,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // 3. Integrity tools
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'بازسازی مانده حساب‌ها',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'اگر مانده یک حساب با تراکنش‌هایش نمی‌خواند، مانده همه حساب‌ها از موجودی اولیه و تراکنش‌های ثبت‌شده دوباره محاسبه می‌شود.',
                        style: TextStyle(fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'بازسازی مانده‌ها',
                        variant: AppButtonVariant.outline,
                        icon: const Icon(Icons.build_circle_outlined, size: 20),
                        isLoading: _isRepairing,
                        onPressed: _isRepairing ? null : _repairBalances,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
