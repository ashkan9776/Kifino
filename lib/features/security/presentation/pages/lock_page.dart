import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../cubit/security_cubit.dart';
import '../cubit/security_state.dart';

class LockPage extends StatefulWidget {
  const LockPage({super.key});

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  String _enteredPin = '';
  static const int _pinLength = 4;

  void _onDigitPressed(String digit) {
    if (_enteredPin.length < _pinLength) {
      setState(() {
        _enteredPin += digit;
      });

      if (_enteredPin.length == _pinLength) {
        _verifyPin();
      }
    }
  }

  void _onDeletePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  Future<void> _verifyPin() async {
    final cubit = context.read<SecurityCubit>();
    final success = await cubit.verifyPin(_enteredPin);
    if (!success) {
      setState(() {
        _enteredPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<SecurityCubit, SecurityState>(
      builder: (context, state) {
        return ColoredBox(
          color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          child: SafeArea(
            top: false,
            child: Scaffold(
              backgroundColor: isDark
                  ? AppColors.darkBackground
                  : AppColors.lightBackground,
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: Column(
                    children: [
                      const Spacer(),

                      // 1. App Icon / Shield Branding
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.primary,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'کیفینو قفل است',
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'برای ورود، رمز ۴ رقمی خود را وارد نمایید',
                        style: AppTypography.bodyMedium.copyWith(
                          color: isDark
                              ? AppColors.darkSubtext
                              : AppColors.lightSubtext,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // 2. PIN Dot Indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pinLength, (index) {
                          final isFilled = index < _enteredPin.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            width: isFilled ? 18 : 14,
                            height: isFilled ? 18 : 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isFilled
                                  ? AppColors.primary
                                  : (isDark
                                        ? AppColors.darkSurfaceVariant
                                        : AppColors.lightBorder),
                              border: isFilled
                                  ? null
                                  : Border.all(
                                      color: isDark
                                          ? AppColors.darkBorder
                                          : AppColors.lightBorder,
                                      width: 2,
                                    ),
                            ),
                          );
                        }),
                      ),

                      // Error Text if any
                      SizedBox(
                        height: 36,
                        child: Center(
                          child: state.errorMessage != null
                              ? Text(
                                  state.errorMessage!,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.expense,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),

                      const Spacer(),

                      // 3. Numeric Keypad
                      _buildKeypad(context, state, isDark),

                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKeypad(BuildContext context, SecurityState state, bool isDark) {
    return Column(
      children: [
        _buildKeyRow(['1', '2', '3'], isDark),
        const SizedBox(height: AppSpacing.md),
        _buildKeyRow(['4', '5', '6'], isDark),
        const SizedBox(height: AppSpacing.md),
        _buildKeyRow(['7', '8', '9'], isDark),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Biometric button (if available and enabled)
            if (state.canBiometric && state.isBiometricEnabled)
              _buildSpecialKey(
                icon: Icons.fingerprint_rounded,
                onTap: () =>
                    context.read<SecurityCubit>().authenticateBiometric(),
                isDark: isDark,
              )
            else
              const SizedBox(width: 72, height: 72),

            _buildDigitKey('0', isDark),

            _buildSpecialKey(
              icon: Icons.backspace_outlined,
              onTap: _onDeletePressed,
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeyRow(List<String> digits, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildDigitKey(d, isDark)).toList(),
    );
  }

  Widget _buildDigitKey(String digit, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onDigitPressed(digit),
        borderRadius: BorderRadius.circular(36),
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Text(
            // Persian digits on the pad while the app is in Persian; the
            // value appended to the PIN stays Latin so hashing matches.
            TextNormalizer.auto(digit),
            style: AppTypography.displayMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(36),
        child: SizedBox(
          width: 72,
          height: 72,
          child: Icon(
            icon,
            size: 28,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
      ),
    );
  }
}
