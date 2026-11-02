import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../cubit/security_cubit.dart';
import '../cubit/security_state.dart';

class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  final _pinController = TextEditingController();

  void _showSetPinDialog() {
    _pinController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تنظیم رمز عبور ۴ رقمی'),
        content: TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 4,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'رمز ۴ رقمی را وارد کنید',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_pinController.text.length == 4) {
                context.read<SecurityCubit>().savePin(_pinController.text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('رمز عبور با موفقیت فعال شد.')),
                );
              }
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
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
          appBar: AppBar(title: const Text('امنیت و قفل برنامه')),
          body: BlocBuilder<SecurityCubit, SecurityState>(
            builder: (context, state) {
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  // 1. PIN Lock Section
                  AppCard(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('قفل با رمز عبور (PIN)'),
                          subtitle: Text(
                            state.isPinSet
                                ? 'رمز عبور فعال است و هنگام ورود پرسیده می‌شود'
                                : 'رمز عبور تعیین نشده است',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkSubtext
                                  : AppColors.lightSubtext,
                              fontSize: 12,
                            ),
                          ),
                          value: state.isPinSet,
                          onChanged: (enabled) {
                            if (enabled) {
                              _showSetPinDialog();
                            } else {
                              context.read<SecurityCubit>().removePin();
                            }
                          },
                        ),
                        if (state.isPinSet) ...[
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.password_rounded),
                            title: const Text('تغییر رمز عبور'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: _showSetPinDialog,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // 2. Biometrics Section
                  AppCard(
                    child: SwitchListTile(
                      secondary: const Icon(Icons.fingerprint_rounded),
                      title: const Text('ورود با بیومتریک (اثر انگشت / چهره)'),
                      subtitle: Text(
                        state.canBiometric
                            ? 'احراز هویت سریع با سنسور دستگاه'
                            : 'سنسور بیومتریک در این دستگاه پشتیبانی نمی‌شود',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkSubtext
                              : AppColors.lightSubtext,
                          fontSize: 12,
                        ),
                      ),
                      value: state.isBiometricEnabled,
                      onChanged: (state.canBiometric && state.isPinSet)
                          ? (val) {
                              context.read<SecurityCubit>().toggleBiometrics(
                                val,
                              );
                            }
                          : null,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // 3. Security Status & Encryption
                  AppCard(
                    backgroundColor: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.lightSurfaceVariant,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.verified_user_outlined,
                                color: AppColors.income,
                                size: 24,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'امنیت سطح سازمانی (Enterprise)',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '• رمزنگاری کلیدها با Android Keystore / iOS Keychain\n'
                            '• هش نمک‌دار SHA-256 برای پین‌کد\n'
                            '• جداسازی پایگاه‌داده محلی با پایگاه‌داده SQLite امن\n'
                            '• هیچ داده‌ای بدون اجازه شما به خارج دستگاه ارسال نمی‌شود.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isDark
                                      ? AppColors.darkSubtext
                                      : AppColors.lightSubtext,
                                  height: 1.6,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  if (state.isPinSet)
                    AppButton(
                      label: 'قفل کردن فوری برنامه',
                      variant: AppButtonVariant.outline,
                      icon: const Icon(Icons.lock_outline_rounded, size: 20),
                      onPressed: () {
                        context.read<SecurityCubit>().lockApp();
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
