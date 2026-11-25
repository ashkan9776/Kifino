import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/design_system/tokens/colors.dart';
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
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Repaint the countdown every second while a lockout is running.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final until = context.read<SecurityCubit>().state.lockedUntil;
      if (until == null) return;
      if (DateTime.now().isAfter(until)) {
        context.read<SecurityCubit>().refreshLockout();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Live countdown while PIN entry is blocked, else null.
  String? _lockoutText(SecurityState state) {
    final until = state.lockedUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    if (left.isNegative) return null;
    final total = left.inSeconds + 1;
    final mm = (total ~/ 60).toString().padLeft(2, '0');
    final ss = (total % 60).toString().padLeft(2, '0');
    return TextNormalizer.auto(
      'تلاش‌های نادرست زیاد بود. $mm:$ss دیگر دوباره امتحان کنید.',
    );
  }

  bool get _isLockedOut {
    final until = context.read<SecurityCubit>().state.lockedUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void _onDigitPressed(String digit) {
    if (_isLockedOut) return;
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
    if (!mounted) return;
    if (!success) {
      HapticFeedback.heavyImpact();
      setState(() {
        _enteredPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SecurityCubit, SecurityState>(
      builder: (context, state) {
        final lockout = _lockoutText(state);
        final message = lockout ?? state.errorMessage;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Material(
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: KifinoPalette.heroDark),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlueDark.withValues(
                            alpha: 0.16,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AppColors.primaryBlueDark.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.primaryBlueDark,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'کیفینو',
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.onInk,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        TextNormalizer.auto(
                          'رمز $_pinLength رقمی را وارد کنید',
                        ),
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.onInkSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pinLength, (index) {
                          final filled = index < _enteredPin.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled
                                  ? AppColors.primaryBlueDark
                                  : Colors.transparent,
                              border: Border.all(
                                color: filled
                                    ? AppColors.primaryBlueDark
                                    : AppColors.onInkSecondary,
                                width: 1.5,
                              ),
                            ),
                          );
                        }),
                      ),
                      SizedBox(
                        height: 56,
                        child: Center(
                          child: message == null
                              ? null
                              : Text(
                                  message,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.expenseDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const Spacer(flex: 3),
                      _buildKeypad(context, state),
                      const SizedBox(height: AppSpacing.lg),
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

  Widget _buildKeypad(BuildContext context, SecurityState state) {
    final locked = _isLockedOut;
    Widget row(List<String> digits) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [for (final d in digits) _digitKey(d, locked)],
    );
    return Column(
      children: [
        row(['1', '2', '3']),
        const SizedBox(height: AppSpacing.md),
        row(['4', '5', '6']),
        const SizedBox(height: AppSpacing.md),
        row(['7', '8', '9']),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (state.canBiometric && state.isBiometricEnabled)
              _iconKey(
                icon: Icons.fingerprint_rounded,
                label: 'ورود با اثر انگشت',
                onTap: () =>
                    context.read<SecurityCubit>().authenticateBiometric(),
              )
            else
              const SizedBox(width: 72, height: 72),
            _digitKey('0', locked),
            _iconKey(
              icon: Icons.backspace_outlined,
              label: 'پاک کردن',
              onTap: _onDeletePressed,
            ),
          ],
        ),
      ],
    );
  }

  Widget _digitKey(String digit, bool locked) {
    return Semantics(
      button: true,
      label: digit,
      excludeSemantics: true,
      child: Material(
        color: Colors.white.withValues(alpha: locked ? 0.03 : 0.08),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: locked
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  _onDigitPressed(digit);
                },
          child: SizedBox(
            width: 72,
            height: 72,
            child: Center(
              // Persian glyphs on the pad; the appended value stays Latin
              // so the hash matches.
              child: Text(
                TextNormalizer.auto(digit),
                style: AppTypography.displayMedium.copyWith(
                  color: AppColors.onInk.withValues(alpha: locked ? 0.35 : 1),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconKey({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 72,
            height: 72,
            child: Icon(icon, size: 28, color: AppColors.onInk),
          ),
        ),
      ),
    );
  }
}
