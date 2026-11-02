import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../utils/money.dart';
import '../utils/persian_input.dart';
import '../utils/text_normalizer.dart';

/// Large numeric money input used across the app.
///
/// - Shows Persian digits (with thousands separators) whenever the ambient
///   locale is Persian, regardless of what the hardware keyboard types.
/// - Reports raw minor units through [onAmountMinorChanged]; parsing is
///   always Persian/Arabic-digit safe.
/// - Pass [amountNotifier] to change the amount from OUTSIDE the field
///   (e.g. quick-amount chips): the field re-forms and displays the new
///   value, and user typing pushes back into the same notifier. Both stay
///   in sync without fighting (external updates are suppressed while the
///   user is typing).
class AppAmountField extends StatefulWidget {
  final Currency currency;
  final ValueChanged<int> onAmountMinorChanged;
  final int initialAmountMinor;
  final bool autoFocus;
  final Color? signColor;
  final String? prefixSign;
  final bool? usePersianDigits;

  /// Optional external source of truth for the amount (minor units).
  /// Chip-style quick amounts set `notifier.value += …` and the field
  /// updates instantly.
  final ValueNotifier<int>? amountNotifier;

  const AppAmountField({
    super.key,
    required this.currency,
    required this.onAmountMinorChanged,
    this.initialAmountMinor = 0,
    this.autoFocus = true,
    this.signColor,
    this.prefixSign,
    this.usePersianDigits,
    this.amountNotifier,
  });

  @override
  State<AppAmountField> createState() => _AppAmountFieldState();
}

class _AppAmountFieldState extends State<AppAmountField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _focused = false;

  /// Guards against feedback loops while THIS state is pushing a programmatic
  /// change into the notifier.
  bool _internalUpdate = false;

  bool get _persianDigits => widget.usePersianDigits ?? isFaLocale(context);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (mounted && _focused != _focusNode.hasFocus) {
        setState(() => _focused = _focusNode.hasFocus);
      }
    });

    final initial = widget.amountNotifier?.value ?? widget.initialAmountMinor;
    if (initial > 0) {
      _controller.text = _display(initial);
    }

    _controller.addListener(_handleTextChanged);
    widget.amountNotifier?.addListener(_onExternalAmountChanged);
  }

  @override
  void didUpdateWidget(covariant AppAmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldNotifier = oldWidget.amountNotifier;
    final newNotifier = widget.amountNotifier;
    if (!identical(oldNotifier, newNotifier)) {
      oldNotifier?.removeListener(_onExternalAmountChanged);
      newNotifier?.addListener(_onExternalAmountChanged);
      if (newNotifier != null) {
        _syncTextFromNotifier(newNotifier.value);
      }
    }
  }

  @override
  void dispose() {
    widget.amountNotifier?.removeListener(_onExternalAmountChanged);
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _display(int minorUnits) {
    final money = Money.fromMinor(minorUnits, widget.currency);
    var formatted = money.format(includeSymbol: false);
    if (_persianDigits) {
      formatted = TextNormalizer.toPersianDigits(formatted);
    }
    return formatted;
  }

  void _handleTextChanged() {
    final parsedMinor = TextNormalizer.parseMoneyInput(_controller.text) ?? 0;

    // Push into the notifier without re-triggering our own listener (the
    // text is already what the user typed).
    _internalUpdate = true;
    widget.amountNotifier?.value = parsedMinor;
    _internalUpdate = false;

    widget.onAmountMinorChanged(parsedMinor);
  }

  void _onExternalAmountChanged() {
    if (_internalUpdate || !mounted) return;
    final value = widget.amountNotifier!.value;
    final formatted = _display(value);
    if (_controller.text == formatted) return;
    _controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    widget.onAmountMinorChanged(value);
  }

  /// Convenience for external code that wants to SET the amount (quick
  /// chips): replaces instead of accumulating.
  void setAmount(int minorUnits) {
    widget.amountNotifier?.value = minorUnits;
  }

  void _syncTextFromNotifier(int minorUnits) {
    final formatted = _display(minorUnits);
    if (_controller.text != formatted) {
      _controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor =
        widget.signColor ?? Theme.of(context).colorScheme.primary;

    final signWidget = widget.prefixSign == null
        ? null
        : Text(
            widget.prefixSign!,
            style: AppTypography.displayLarge.copyWith(color: accentColor),
          );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceVariant
            : AppColors.lightSurfaceVariant,
        borderRadius: AppSpacing.borderRadiusLg,
        border: Border.all(
          color: _focused
              ? accentColor.withValues(alpha: 0.7)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: _focused ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (signWidget != null && !isRtl) ...[
            signWidget,
            const SizedBox(width: AppSpacing.xs),
          ],
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: widget.autoFocus,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: false,
                signed: false,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩,]')),
              ],
              onChanged: _formatInput,
              style: AppTypography.displayLarge.copyWith(
                color:
                    widget.signColor ?? Theme.of(context).colorScheme.onSurface,
                fontFeatures: AppTypography.tabularFigures,
              ),
              decoration: InputDecoration(
                hintText: _persianDigits ? '۰' : '0',
                hintStyle: AppTypography.displayLarge.copyWith(
                  color:
                      (isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary)
                          .withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                filled: false,
              ),
            ),
          ),
          if (signWidget != null && isRtl) ...[
            signWidget,
            const SizedBox(width: AppSpacing.xs),
          ],
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: AppSpacing.borderRadiusSm,
            ),
            child: Text(
              widget.currency.symbol.isNotEmpty
                  ? widget.currency.symbol
                  : widget.currency.code,
              style: AppTypography.labelLarge.copyWith(color: accentColor),
            ),
          ),
        ],
      ),
    );
  }

  void _formatInput(String value) {
    final parsedMinor = TextNormalizer.parseMoneyInput(value) ?? 0;
    final formatted = _display(parsedMinor);

    if (_controller.text != formatted) {
      _controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }
}
