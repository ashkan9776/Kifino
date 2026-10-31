class TextNormalizer {
  /// Global switch driving default Persian-digit rendering for every number
  /// the app displays. Set once from [Locale] at startup (fa → true) and kept
  /// in sync by SettingsCubit — widgets and value objects (e.g. [Money.format])
  /// read it so the whole app follows the selected language.
  static bool _persianDigitsEnabled = false;
  static bool get persianDigitsEnabled => _persianDigitsEnabled;
  static void setPersianDigitsEnabled({required bool enabled}) =>
      _persianDigitsEnabled = enabled;

  /// Converts digits to Persian when the global Persian-locale switch is on;
  /// pass-through otherwise. Use for every displayed number that has no
  /// explicit usePersianDigits parameter.
  static String auto(String input) =>
      _persianDigitsEnabled ? toPersianDigits(input) : input;

  static const Map<String, String> _persianToArabicDigits = {
    '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
    '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
    '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
    '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
  };

  static const Map<String, String> _latinToPersianDigits = {
    '0': '۰', '1': '۱', '2': '۲', '3': '۳', '4': '۴',
    '5': '۵', '6': '۶', '7': '۷', '8': '۸', '9': '۹',
  };

  /// Normalizes Persian text characters (Yeh and Kaf variants).
  static String normalizePersian(String input) {
    if (input.isEmpty) return '';
    String text = input;
    text = text.replaceAll('\u0643', '\u06a9'); // ك -> ک
    text = text.replaceAll('\u064a', '\u06cc'); // ي -> ی
    text = text.replaceAll('\u0649', '\u06cc'); // ى -> ی
    text = text.replaceAll('\u06c0', '\u0647\u0654');
    return text;
  }

  /// Normalizes Persian and Arabic text for reliable search:
  /// - Converts Arabic 'ي' to Persian 'ی'
  /// - Converts Arabic 'ك' to Persian 'ک'
  /// - Normalizes or removes ZWNJ (Zero-Width Non-Joiner '\u200C')
  /// - Converts Arabic/Persian digits to standard Latin digits
  /// - Trims and squashes multiple spaces
  static String normalizeForSearch(String input) {
    if (input.isEmpty) return '';

    String text = input;

    // Convert Arabic Kaf to Persian Keh
    text = text.replaceAll('\u0643', '\u06a9'); // ك -> ک

    // Convert Arabic Yeh to Persian Yeh
    text = text.replaceAll('\u064a', '\u06cc'); // ي -> ی
    text = text.replaceAll('\u0649', '\u06cc'); // ى -> ی

    // Normalize Persian Heh with Hamza above
    text = text.replaceAll('\u06c0', '\u0647\u0654');

    // Remove or normalize ZWNJ for loose search matching
    text = text.replaceAll('\u200c', ' ');

    // Normalize digits to Latin for uniform search
    text = toLatinDigits(text);

    // Normalize whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text.toLowerCase();
  }

  /// Converts any Persian or Arabic digits to standard Latin digits (0-9).
  static String toLatinDigits(String input) {
    if (input.isEmpty) return input;
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      buffer.write(_persianToArabicDigits[char] ?? char);
    }
    return buffer.toString();
  }

  /// Converts Latin digits to Persian digits (۰-۹).
  static String toPersianDigits(String input) {
    if (input.isEmpty) return input;
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      buffer.write(_latinToPersianDigits[char] ?? char);
    }
    return buffer.toString();
  }

  /// Cleans and parses a monetary input string (which might contain Persian digits, commas, or spaces)
  /// into an integer minor unit.
  static int? parseMoneyInput(String input) {
    if (input.isEmpty) return null;
    final latin = toLatinDigits(input);
    final cleaned = latin.replaceAll(RegExp(r'[^0-9\-]'), '');
    return int.tryParse(cleaned);
  }
}
