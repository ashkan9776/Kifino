import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../utils/money.dart';

enum MoneyDisplaySign { none, positiveNegative, negativeOnly }

/// Sets the style [AppMoneyText] uses when it is given none — so a hero can
/// say "amounts here are headline-sized" without every call site repeating
/// the style.
class MoneyTextStyle extends InheritedWidget {
  final TextStyle style;

  const MoneyTextStyle({super.key, required this.style, required super.child});

  static TextStyle? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MoneyTextStyle>()?.style;

  @override
  bool updateShouldNotify(MoneyTextStyle old) => old.style != style;
}

class AppMoneyText extends StatelessWidget {
  final Money money;
  final TextStyle? style;
  final MoneyDisplaySign sign;
  final bool? colorCode; // if true, green for + and red for -
  final bool? usePersianDigits; // null → follow app locale (fa → Persian)
  final bool includeSymbol;

  /// Counts up/down to the value instead of snapping — premium touch for the
  /// hero figures on the dashboard.
  final bool animated;

  const AppMoneyText({
    super.key,
    required this.money,
    this.style,
    this.sign = MoneyDisplaySign.none,
    this.colorCode,
    this.usePersianDigits,
    this.includeSymbol = true,
    this.animated = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;
    final defaultStyle =
        style ?? MoneyTextStyle.maybeOf(context) ?? AppTypography.moneyTile;

    Color? textColor = defaultStyle.color;
    String prefix = '';

    if (sign == MoneyDisplaySign.positiveNegative) {
      if (money.isPositive) {
        prefix = '+';
        if (colorCode ?? true) textColor = colors.income;
      } else if (money.isNegative) {
        prefix = '-';
        if (colorCode ?? true) textColor = colors.expense;
      }
    } else if (sign == MoneyDisplaySign.negativeOnly) {
      // Expenses are stored as positive amounts — this sign means "this row
      // is a minus". A zero has no sign ("۰ تومان", never "۰ تومان -").
      if (!money.isZero) {
        prefix = '-';
        if (colorCode ?? true) textColor = colors.expense;
      }
    } else if (colorCode == true) {
      if (money.isPositive) {
        textColor = colors.income;
      } else if (money.isNegative) {
        textColor = colors.expense;
      }
    }

    final isRtl = Directionality.of(context) == TextDirection.rtl;

    String formatMinor(int minor) {
      final m = Money.fromMinor(minor, money.currency);
      final formatted = m.abs().format(
        includeSymbol: includeSymbol,
        usePersianDigits: usePersianDigits,
      );
      if (prefix.isEmpty) return formatted;
      if (!isRtl) return '$prefix$formatted';
      // RTL: keep the sign glued to the digits inside a left-to-right
      // isolate ("‎-۴۵۰,۰۰۰ تومان"), instead of drifting to the far end of
      // the line as a lone "-" the eye reads as a dash.
      final number = m.abs().format(
        includeSymbol: false,
        usePersianDigits: usePersianDigits,
      );
      final symbol = formatted.substring(number.length);
      if (formatted.startsWith(number)) {
        return '\u2066$prefix$number\u2069$symbol';
      }
      return '\u2066$prefix$formatted\u2069';
    }

    final textStyle = defaultStyle.copyWith(
      color: textColor,
      fontFeatures: AppTypography.tabularFigures,
    );

    final Widget text;
    if (animated) {
      text = TweenAnimationBuilder<int>(
        tween: IntTween(end: money.minorUnits),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Text(
          formatMinor(value),
          style: textStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    } else {
      text = Text(
        formatMinor(money.minorUnits),
        style: textStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return text;
  }
}
