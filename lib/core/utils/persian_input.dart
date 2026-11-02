import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'text_normalizer.dart';

/// True when the ambient locale is Persian — drives Persian-digit rendering
/// for every numeric input in the app.
bool isFaLocale(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'fa';

/// Digits-only formatter that ALSO renders as Persian digits (۰-۹) while the
/// ambient locale is Persian. It is self-sufficient: it rejects every
/// non-digit character itself, so it must NOT be paired with
/// [FilteringTextInputFormatter.digitsOnly] — that one runs afterwards and
/// strips the Persian digits right back out, making the field un-typable.
/// Parsing stays Latin-safe via [TextNormalizer.toLatinDigits].
class PersianDigitsTextInputFormatter extends TextInputFormatter {
  final bool enabled;

  const PersianDigitsTextInputFormatter({this.enabled = true});

  static final RegExp _allowedDigits = RegExp(r'[0-9۰-۹٠-٩]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    if (raw.isEmpty) return newValue;

    // 1. Keep digits from any script, drop everything else.
    final buffer = StringBuffer();
    for (final rune in raw.runes) {
      final ch = String.fromCharCode(rune);
      if (_allowedDigits.hasMatch(ch)) buffer.write(ch);
    }
    var filtered = buffer.toString();

    // 2. Render as Persian digits when the app language is Persian.
    if (enabled) {
      filtered = TextNormalizer.toPersianDigits(filtered);
    }

    if (filtered == raw) {
      return TextEditingValue(
        text: filtered,
        selection: newValue.selection,
        composing: TextRange.empty,
      );
    }

    // Digit-for-digit mapping keeps offsets aligned; clamp for safety.
    final clamped = newValue.selection.copyWith(
      baseOffset: newValue.selection.baseOffset.clamp(0, filtered.length),
      extentOffset: newValue.selection.extentOffset.clamp(0, filtered.length),
    );
    return TextEditingValue(
      text: filtered,
      selection: clamped,
      composing: TextRange.empty,
    );
  }
}

/// Formatter that inserts thousands separators (commas) and renders
/// digits in Persian (or Latin when disabled/English).
class PersianThousandsSeparatorTextInputFormatter extends TextInputFormatter {
  final bool enabled;
  final bool usePersianDigits;

  const PersianThousandsSeparatorTextInputFormatter({
    this.enabled = true,
    this.usePersianDigits = true,
  });

  static final RegExp _digitRegex = RegExp(r'[0-9۰-۹٠-٩]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!enabled) return newValue;
    if (newValue.text.isEmpty) return newValue;

    // 1. Calculate how many raw digits appeared before the cursor in newValue
    int digitsBeforeCursor = 0;
    final cursorOffset = newValue.selection.baseOffset.clamp(
      0,
      newValue.text.length,
    );
    for (int i = 0; i < cursorOffset; i++) {
      if (_digitRegex.hasMatch(newValue.text[i])) {
        digitsBeforeCursor++;
      }
    }

    // 2. Extract only digits, converted to Latin for standardized formatting
    final buffer = StringBuffer();
    for (final rune in newValue.text.runes) {
      final ch = String.fromCharCode(rune);
      if (_digitRegex.hasMatch(ch)) {
        buffer.write(ch);
      }
    }
    final rawDigits = TextNormalizer.toLatinDigits(buffer.toString());
    if (rawDigits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
        composing: TextRange.empty,
      );
    }

    // 3. Format with thousands separator ','
    final formattedBuffer = StringBuffer();
    final len = rawDigits.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        formattedBuffer.write(',');
      }
      formattedBuffer.write(rawDigits[i]);
    }
    var formattedText = formattedBuffer.toString();

    // 4. Convert digits to Persian if enabled
    if (usePersianDigits) {
      formattedText = TextNormalizer.toPersianDigits(formattedText);
    }

    // 5. Compute new cursor position matching digitsBeforeCursor
    int newCursorOffset = 0;
    int digitCount = 0;
    for (int i = 0; i < formattedText.length; i++) {
      if (_digitRegex.hasMatch(formattedText[i])) {
        digitCount++;
      }
      if (digitCount == digitsBeforeCursor) {
        newCursorOffset = i + 1;
        break;
      }
    }
    if (digitsBeforeCursor == 0) {
      newCursorOffset = 0;
    } else if (digitCount < digitsBeforeCursor) {
      newCursorOffset = formattedText.length;
    }

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: newCursorOffset),
      composing: TextRange.empty,
    );
  }
}

/// Normalizes any user-typed numeric string (Persian/Arabic/Latin digits,
/// separators) down to plain Latin digits for parsing. Decimal points are
/// dropped — use for integer-only values like money minor units.
String normalizeNumericInput(String input) =>
    TextNormalizer.toLatinDigits(input).replaceAll(RegExp(r'[^0-9]'), '');

/// Same as [normalizeNumericInput] but preserves the decimal point (both
/// Latin '.' and Persian '٫') — use for quantities like ۱.۵ گرم.
String normalizeDecimalInput(String input) =>
    TextNormalizer.toLatinDigits(input)
        .replaceAll('٫', '.')
        .replaceAll(RegExp(r'[^0-9.]'), '');

/// Formats an integer or numeric string with thousands separators (e.g. 1000000 -> "۱,۰۰۰,۰۰۰").
String formatNumberWithSeparators(dynamic value, {bool toPersian = true}) {
  if (value == null) return '';
  final raw = TextNormalizer.toLatinDigits(value.toString())
      .replaceAll(RegExp(r'[^0-9]'), '');
  if (raw.isEmpty) return '';
  final buffer = StringBuffer();
  final len = raw.length;
  for (int i = 0; i < len; i++) {
    if (i > 0 && (len - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(raw[i]);
  }
  final formatted = buffer.toString();
  return toPersian ? TextNormalizer.toPersianDigits(formatted) : formatted;
}
