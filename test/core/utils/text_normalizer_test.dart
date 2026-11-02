import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/utils/persian_input.dart';
import 'package:kifino/core/utils/text_normalizer.dart';

void main() {
  group('TextNormalizer Tests', () {
    test('Normalizes Arabic Yeh and Kaf to Persian', () {
      const raw = 'كتاب يزد'; // Arabic kaf and yeh
      final normalized = TextNormalizer.normalizeForSearch(raw);
      expect(normalized, equals('کتاب یزد'));
    });

    test('Converts Persian and Arabic digits to Latin digits', () {
      expect(TextNormalizer.toLatinDigits('۱۲۳۴۵۶۷۸۹۰'), equals('1234567890'));
      expect(TextNormalizer.toLatinDigits('١٢٣٤٥٦٧٨٩٠'), equals('1234567890'));
    });

    test('Converts Latin digits to Persian digits', () {
      expect(TextNormalizer.toPersianDigits('12345'), equals('۱۲۳۴۵'));
    });

    test('Parses formatted money strings with Persian digits and commas', () {
      expect(TextNormalizer.parseMoneyInput('۳۵۰,۰۰۰'), equals(350000));
      expect(TextNormalizer.parseMoneyInput('1,250,000'), equals(1250000));
      expect(TextNormalizer.parseMoneyInput('-45,000'), equals(-45000));
    });

    test(
      'formatNumberWithSeparators formats correctly with Persian digits',
      () {
        expect(formatNumberWithSeparators(10000000), equals('۱۰,۰۰۰,۰۰۰'));
        expect(formatNumberWithSeparators('2500'), equals('۲,۵۰۰'));
        expect(formatNumberWithSeparators(50), equals('۵۰'));
        expect(formatNumberWithSeparators(''), equals(''));
      },
    );

    test(
      'PersianThousandsSeparatorTextInputFormatter formats input dynamically',
      () {
        const formatter = PersianThousandsSeparatorTextInputFormatter(
          enabled: true,
          usePersianDigits: true,
        );
        const oldValue = TextEditingValue.empty;
        const newValue = TextEditingValue(
          text: '10000000',
          selection: TextSelection.collapsed(offset: 8),
        );
        final formatted = formatter.formatEditUpdate(oldValue, newValue);
        expect(formatted.text, equals('۱۰,۰۰۰,۰۰۰'));
        expect(formatted.selection.baseOffset, equals(10));
      },
    );
  });
}
