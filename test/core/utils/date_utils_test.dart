import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/utils/date_utils.dart';

void main() {
  group('JalaliDate Tests', () {
    test('Converts known Gregorian dates to Jalali correctly', () {
      // 2026-03-21 is around 1405-01-01
      final gDate = DateTime(2024, 3, 20); // 1403-01-01
      final jDate = JalaliDate.fromDateTime(gDate);

      expect(jDate.year, equals(1403));
      expect(jDate.month, equals(1));
      expect(jDate.day, equals(1));
    });

    test('Converts back from Jalali to Gregorian accurately', () {
      const jDate = JalaliDate(1403, 7, 1);
      final gDate = jDate.toDateTime();
      final roundTrip = JalaliDate.fromDateTime(gDate);

      expect(roundTrip.year, equals(jDate.year));
      expect(roundTrip.month, equals(jDate.month));
      expect(roundTrip.day, equals(jDate.day));
    });

    test('Formats full date in Persian', () {
      const jDate = JalaliDate(1403, 1, 15);
      final formatted = jDate.formatFull(usePersianDigits: false);
      expect(formatted, equals('15 فروردین 1403'));
    });
  });
}
