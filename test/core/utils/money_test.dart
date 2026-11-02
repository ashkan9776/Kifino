import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/errors/exceptions.dart';
import 'package:kifino/core/utils/money.dart';

void main() {
  group('Money Value Object Tests', () {
    test(
      'Correctly calculates major and minor units for decimal currencies',
      () {
        final usd = Money.fromMajor(125.75, Currency.usd);
        expect(usd.minorUnits, equals(12575));
        expect(usd.toMajor(), equals(125.75));
        expect(usd.format(), equals(r'$125.75'));
      },
    );

    test('Correctly calculates major and minor units for zero-decimal currencies (Toman/Rial)', () {
      final toman = Money.fromMinor(450000, Currency.toman);
      expect(toman.minorUnits, equals(450000));
      expect(toman.toMajor(), equals(450000.0));
      expect(toman.format(includeSymbol: true), equals('450,000 تومان'));
    });

    test('Supports arithmetic operations with same currency', () {
      final m1 = Money.fromMinor(100000, Currency.toman);
      final m2 = Money.fromMinor(50000, Currency.toman);

      expect(m1 + m2, equals(Money.fromMinor(150000, Currency.toman)));
      expect(m1 - m2, equals(Money.fromMinor(50000, Currency.toman)));
      expect(m2 * 3, equals(Money.fromMinor(150000, Currency.toman)));
      expect(-m2, equals(Money.fromMinor(-50000, Currency.toman)));
    });

    test('Throws CurrencyMismatchException on cross-currency math', () {
      final usd = Money.fromMinor(1000, Currency.usd);
      final eur = Money.fromMinor(1000, Currency.eur);

      expect(() => usd + eur, throwsA(isA<CurrencyMismatchException>()));
      expect(() => usd - eur, throwsA(isA<CurrencyMismatchException>()));
    });

    test('Supports comparisons', () {
      final a = Money.fromMinor(100, Currency.usd);
      final b = Money.fromMinor(200, Currency.usd);

      expect(a < b, isTrue);
      expect(a <= b, isTrue);
      expect(b > a, isTrue);
      expect(b >= a, isTrue);
    });

    test('Converts between Toman and Rial', () {
      final toman = Money.fromMinor(50000, Currency.toman);
      final rial = toman.toTomanOrRial();
      expect(rial.currency, equals(Currency.irr));
      expect(rial.minorUnits, equals(500000));

      final backToToman = rial.toTomanOrRial();
      expect(backToToman.currency, equals(Currency.toman));
      expect(backToToman.minorUnits, equals(500000 ~/ 10));
    });
  });
}
