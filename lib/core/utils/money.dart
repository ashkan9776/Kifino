import 'dart:math' as math;
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import '../errors/exceptions.dart';
import 'text_normalizer.dart';

enum Currency {
  irr('IRR', 'ریال', 0, 'Iranian Rial'),
  toman('TOMAN', 'تومان', 0, 'Iranian Toman'),
  usd('USD', r'$', 2, 'US Dollar'),
  eur('EUR', '€', 2, 'Euro'),
  aed('AED', 'د.إ', 2, 'UAE Dirham'),
  tryCurrency('TRY', '₺', 2, 'Turkish Lira'),
  gbp('GBP', '£', 2, 'British Pound');

  final String code;
  final String symbol;
  final int decimals;
  final String displayName;

  const Currency(this.code, this.symbol, this.decimals, this.displayName);

  static Currency fromCode(String code) {
    final upper = code.toUpperCase().trim();
    for (final c in values) {
      if (c.code == upper) return c;
    }
    return Currency.usd; // Default fallback
  }
}

class Money extends Equatable implements Comparable<Money> {
  final int minorUnits;
  final Currency currency;

  const Money({
    required this.minorUnits,
    this.currency = Currency.toman,
  });

  const Money.zero([this.currency = Currency.toman]) : minorUnits = 0;

  const Money.fromMinor(this.minorUnits, [this.currency = Currency.toman]);

  factory Money.fromMajor(num majorUnits, Currency currency) {
    final factor = math.pow(10, currency.decimals).toInt();
    final minor = (majorUnits * factor).round();
    return Money(minorUnits: minor, currency: currency);
  }

  double toMajor() {
    if (currency.decimals == 0) return minorUnits.toDouble();
    final factor = math.pow(10, currency.decimals).toDouble();
    return minorUnits / factor;
  }

  bool get isZero => minorUnits == 0;
  bool get isPositive => minorUnits > 0;
  bool get isNegative => minorUnits < 0;

  Money abs() => Money(minorUnits: minorUnits.abs(), currency: currency);
  Money operator -() => Money(minorUnits: -minorUnits, currency: currency);

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(minorUnits: minorUnits + other.minorUnits, currency: currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(minorUnits: minorUnits - other.minorUnits, currency: currency);
  }

  Money operator *(num multiplier) {
    return Money(
      minorUnits: (minorUnits * multiplier).round(),
      currency: currency,
    );
  }

  bool operator <(Money other) {
    _assertSameCurrency(other);
    return minorUnits < other.minorUnits;
  }

  bool operator <=(Money other) {
    _assertSameCurrency(other);
    return minorUnits <= other.minorUnits;
  }

  bool operator >(Money other) {
    _assertSameCurrency(other);
    return minorUnits > other.minorUnits;
  }

  bool operator >=(Money other) {
    _assertSameCurrency(other);
    return minorUnits >= other.minorUnits;
  }

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  void _assertSameCurrency(Money other) {
    if (currency != other.currency) {
      throw CurrencyMismatchException(currency.code, other.currency.code);
    }
  }

  /// Convert between Toman and Rial directly without rate:
  Money toTomanOrRial() {
    if (currency == Currency.irr) {
      return Money(minorUnits: (minorUnits / 10).round(), currency: Currency.toman);
    } else if (currency == Currency.toman) {
      return Money(minorUnits: minorUnits * 10, currency: Currency.irr);
    }
    return this;
  }

  /// Normalizes this amount into [target] when both currencies are Iranian
  /// (Toman↔Rial is an exact ×10 conversion). Foreign currencies pass through
  /// unchanged — no exchange rates are ever invented. Use this everywhere
  /// sums are computed so the ledger never mixes units.
  Money normalizeTo(Currency target) {
    if (currency == target) return this;
    final bool thisIranian = currency == Currency.irr || currency == Currency.toman;
    final bool targetIranian = target == Currency.irr || target == Currency.toman;
    if (thisIranian && targetIranian) return toTomanOrRial();
    return this;
  }

  /// True when this amount can be safely summed with [target] currency
  /// (same currency, or convertible Iranian pair).
  bool isCompatibleWith(Currency target) {
    if (currency == target) return true;
    final bool thisIranian = currency == Currency.irr || currency == Currency.toman;
    final bool targetIranian = target == Currency.irr || target == Currency.toman;
    return thisIranian && targetIranian;
  }

  String format({
    bool includeSymbol = true,
    bool? usePersianDigits,
    bool compact = false,
  }) {
    final major = toMajor();
    String formattedNumber;

    if (currency.decimals == 0) {
      final formatter = NumberFormat('#,##0', 'en_US');
      formattedNumber = formatter.format(major);
    } else {
      final formatter = NumberFormat('#,##0.00', 'en_US');
      formattedNumber = formatter.format(major);
    }

    if (usePersianDigits ?? TextNormalizer.persianDigitsEnabled) {
      formattedNumber = TextNormalizer.toPersianDigits(formattedNumber);
    }

    if (!includeSymbol) {
      return formattedNumber;
    }

    // RTL currencies usually place symbol after or before depending on locale
    if (currency == Currency.toman || currency == Currency.irr || currency == Currency.aed) {
      return '$formattedNumber ${currency.symbol}';
    } else {
      return '${currency.symbol}$formattedNumber';
    }
  }

  /// Compact notation for dense surfaces: «۲۴۸.۵ میلیون» / «2.4M».
  /// Exact amounts remain available via [format] — use compact only where
  /// space is tight and the precise value is one tap away.
  String formatCompact({bool? isPersianLocale}) {
    final persian = isPersianLocale ?? TextNormalizer.persianDigitsEnabled;
    final value = toMajor().abs();
    String text;

    String num(double n) =>
        n >= 100 ? n.round().toString() : n.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');

    if (currency.decimals == 0) {
      if (value >= 1000000000) {
        text = persian ? '${num(value / 1000000000)} میلیارد' : '${num(value / 1000000000)}B';
      } else if (value >= 1000000) {
        text = persian ? '${num(value / 1000000)} میلیون' : '${num(value / 1000000)}M';
      } else if (value >= 10000) {
        text = persian ? '${num(value / 1000)} هزار' : '${num(value / 1000)}K';
      } else {
        text = value.round().toString();
      }
    } else {
      if (value >= 1000000) {
        text = persian ? '${num(value / 1000000)} میلیون' : '${num(value / 1000000)}M';
      } else if (value >= 1000) {
        text = persian ? '${num(value / 1000)} هزار' : '${num(value / 1000)}K';
      } else {
        text = value.toStringAsFixed(currency.decimals);
      }
    }

    if (persian) text = TextNormalizer.toPersianDigits(text);
    return text;
  }

  @override
  List<Object?> get props => [minorUnits, currency];

  String get formatted => format();

  @override
  String toString() => format();
}

/// Currency-level compatibility helpers (mirrors [Money.isCompatibleWith]).
extension CurrencyCompatibility on Currency {
  /// True when amounts in [other] can be summed with this currency without
  /// invented exchange rates (same currency, or the Iranian Toman↔Rial pair).
  bool isCompatibleWith(Currency other) {
    if (this == other) return true;
    final bool thisIranian = this == Currency.irr || this == Currency.toman;
    final bool otherIranian = other == Currency.irr || other == Currency.toman;
    return thisIranian && otherIranian;
  }
}
