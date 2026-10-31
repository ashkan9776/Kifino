import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/services/backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final _passwordController = TextEditingController();
  final _restorePathController = TextEditingController();
  final _restorePasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isExportingCsv = false;
  String? _lastBackupPath;

  Future<void> _exportCsv() async {
    setState(() => _isExportingCsv = true);
    try {
      final result = await sl<BackupService>().exportTransactionsCsv();
      if (!mounted) return;
      result.fold(
        onSuccess: (path) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فایل اکسل (CSV) ساخته شد:\n$path'),
              duration: const Duration(seconds: 5),
            ),
          );
        },
        onFailure: (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _isExportingCsv = false);
    }
  }

  void _showCreateBackupDialog() {
    _passwordController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('پشتیبان‌گیری رمزنگاری‌شده (AES-256)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'یک رمز عبور برای محافظت از اطلاعات مالی خود وارد کنید. برای بازیابی به این رمز نیاز خواهید داشت:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'رمز عبور پشتیبان',
                prefixIcon: Icon(Icons.key_rounded),
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
            onPressed: () async {
              if (_passwordController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              setState(() => _isLoading = true);

              final backupService = sl<BackupService>();
              final result = await backupService.createEncryptedBackup(
                password: _passwordController.text.trim(),
              );

              setState(() => _isLoading = false);

              result.fold(
                onSuccess: (filePath) {
                  setState(() => _lastBackupPath = filePath);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('فایل پشتیبان با موفقیت در مسیر ذخیره شد:\n$filePath'),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                },
                onFailure: (err) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطا: ${err.message}')),
                  );
                },
              );
            },
            child: const Text('ایجاد پشتیبان'),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog() {
    _restorePathController.text = _lastBackupPath ?? '';
    _restorePasswordController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بازیابی اطلاعات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _restorePathController,
              decoration: const InputDecoration(
                labelText: 'مسیر فایل پشتیبان (.kfn)',
                prefixIcon: Icon(Icons.file_present_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _restorePasswordController,
              obscureText: true,
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
          ElevatedButton(
            onPressed: () async {
              if (_restorePathController.text.trim().isEmpty ||
                  _restorePasswordController.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(ctx);
              setState(() => _isLoading = true);

              final backupService = sl<BackupService>();
              final result = await backupService.restoreEncryptedBackup(
                filePath: _restorePathController.text.trim(),
                password: _restorePasswordController.text.trim(),
              );

              setState(() => _isLoading = false);

              result.fold(
                onSuccess: (metadata) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'اطلاعات با موفقیت بازیابی شد!\nتراکنش‌ها: ${metadata.entityCounts["transactions"] ?? 0} | حساب‌ها: ${metadata.entityCounts["accounts"] ?? 0}',
                      ),
                    ),
                  );
                },
                onFailure: (err) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطای بازیابی: ${err.message}')),
                  );
                },
              );
            },
            child: const Text('بازیابی'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _restorePathController.dispose();
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
      appBar: AppBar(
        title: const Text('پشتیبان‌گیری و بازیابی'),
      ),
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
                        child: const Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'پشتیبان‌گیری کامل از اطلاعات',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'رمزنگاری‌شده با استاندارد نظامی AES-256',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'از تمامی حساب‌ها، تراکنش‌ها، چک‌ها، اقساط، فاکتورها و مخاطبان یک فایل رمزگذاری‌شده تهیه می‌شود.',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: _isLoading ? 'در حال تهیه پشتیبان...' : 'ایجاد فایل پشتیبان جدید',
                    icon: const Icon(Icons.download_rounded, size: 20),
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
                          color: AppColors.accentIndigo.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.table_view_rounded, color: AppColors.accentIndigo, size: 28),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'خروجی اکسل (CSV)',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'تمام تراکنش‌ها با تاریخ شمسی، قابل بازکردن در Excel',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: _isExportingCsv ? 'در حال ساخت فایل...' : 'ساخت فایل اکسل تراکنش‌ها',
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
                        child: const Icon(Icons.settings_backup_restore_rounded, color: AppColors.income, size: 28),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'بازیابی از فایل پشتیبان',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'بازگردانی کامل اطلاعات از فایل .kfn',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'اطلاعات موجود درون فایل پشتیبان همراه با اعتبارسنجی چک‌سام بدون دستکاری وارد دیتابیس می‌شوند.',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'انتخاب و بازیابی فایل',
                    variant: AppButtonVariant.outline,
                    icon: const Icon(Icons.upload_file_rounded, size: 20),
                    onPressed: _isLoading ? null : _showRestoreDialog,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          if (_lastBackupPath != null)
            AppCard(
              backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('آخرین فایل ایجادشده:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    SelectableText(
                      _lastBackupPath!,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
        ),
      ),
    );
  }
}
