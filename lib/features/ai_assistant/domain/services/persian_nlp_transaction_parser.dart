import '../../../../core/utils/money.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../entities/parsed_transaction_draft.dart';

/// Which currency the user actually spoke, detected from keywords.
enum _SpokenCurrency { toman, rial, usd, eur }

/// Persian natural-language transaction parser.
///
/// IMPORTANT — currency policy: spoken amounts are normalized to
/// [targetCurrency] (the user's base currency) so the ledger never mixes
/// Toman and Rial rows. "۴۵ هزار تومن" and "۴۵۰,۰۰۰ ریال" both produce the
/// SAME Money when the target is Toman. Foreign currencies (USD/EUR) are kept
/// as spoken — no exchange rates are invented.
class PersianNlpTransactionParser {
  static ParsedTransactionDraft? parse(
    String rawInput, {
    Currency targetCurrency = Currency.toman,
  }) {
    final cleanInput = TextNormalizer.normalizePersian(rawInput).trim();
    if (cleanInput.isEmpty) return null;

    final normalizedDigits = TextNormalizer.toLatinDigits(cleanInput);

    // 1. Detect which currency the user spoke (default: colloquial Toman).
    final lower = normalizedDigits.toLowerCase();
    _SpokenCurrency spoken = _SpokenCurrency.toman;
    if (lower.contains('تومان') || lower.contains('تومن') || lower.contains('toman')) {
      spoken = _SpokenCurrency.toman;
    } else if (lower.contains('ریال') || lower.contains('rial') || lower.contains('irr')) {
      spoken = _SpokenCurrency.rial;
    } else if (lower.contains('دلار') || lower.contains('usd') || lower.contains(r'$')) {
      spoken = _SpokenCurrency.usd;
    } else if (lower.contains('یورو') || lower.contains('eur') || lower.contains('€')) {
      spoken = _SpokenCurrency.eur;
    }

    // 2. Extract numbers & magnitude multipliers. Commas are stripped first
    // so "۳,۵۰۰,۰۰۰" parses as one number instead of "۳,۵۰۰".
    final digitsOnlyText = normalizedDigits.replaceAll(',', '');
    final numberRegex = RegExp(r'(\d+(?:\.\d+)?)');
    final match = numberRegex.firstMatch(digitsOnlyText);
    if (match == null) return null;

    final numberStr = match.group(1)!;
    double baseNumber = double.tryParse(numberStr) ?? 0.0;
    if (baseNumber <= 0) return null;

    double multiplier = 1.0;
    if (lower.contains('میلیون') || lower.contains('ملیون') || lower.contains('million')) {
      multiplier = 1000000.0;
    } else if (lower.contains('هزار') || lower.contains('هزارتومن') || lower.contains('thousand')) {
      multiplier = 1000.0;
    } else if (spoken == _SpokenCurrency.toman &&
        baseNumber <= 500 &&
        !lower.contains('تومان')) {
      // Colloquial shortcut: "۳۵۰ تومن" (spelled without ا) almost always
      // means 350,000 Tomans. An explicitly written "تومان" is a literal
      // amount, and spoken ریال/foreign amounts are never inflated.
      multiplier = 1000.0;
    }

    final finalAmount = baseNumber * multiplier;

    // 3. Build the Money in the SPOKEN currency first.
    final Currency spokenCurrency = switch (spoken) {
      _SpokenCurrency.toman => Currency.toman,
      _SpokenCurrency.rial => Currency.irr,
      _SpokenCurrency.usd => Currency.usd,
      _SpokenCurrency.eur => Currency.eur,
    };
    final int spokenMinor = switch (spokenCurrency.decimals) {
      0 => finalAmount.round(),
      _ => (finalAmount * 100).round(),
    };
    final spokenMoney = Money.fromMinor(spokenMinor, spokenCurrency);

    // 4. Normalize Iranian currencies to the target so the ledger stays in
    // ONE unit. Foreign currencies pass through untouched.
    final bool spokenIsIranian =
        spokenCurrency == Currency.toman || spokenCurrency == Currency.irr;
    final bool targetIsIranian =
        targetCurrency == Currency.toman || targetCurrency == Currency.irr;

    final Money money;
    if (spokenIsIranian && targetIsIranian) {
      money = spokenCurrency == targetCurrency
          ? spokenMoney
          : spokenMoney.toTomanOrRial();
    } else {
      money = spokenMoney;
    }

    // 5. Detect transaction type.
    TransactionType type = TransactionType.expense;
    const incomeKeywords = [
      'حقوق', 'واریز', 'درآمد', 'درامد', 'پاداش', 'سود', 'فروش',
      'طلب', 'بستانکار', 'salary', 'income', 'deposit', 'earned', 'bonus',
    ];
    const transferKeywords = [
      'انتقال', 'کارت به کارت', 'کارت‌به‌کارت', 'جابجایی', 'واریز به حساب', 'transfer',
    ];

    // "فروشگاه" (shop) must not read as "فروش" (a sale → income).
    final incomeHit = incomeKeywords.any((k) =>
        lower.contains(k) && !(k == 'فروش' && lower.contains('فروشگاه')));
    if (incomeHit) {
      type = TransactionType.income;
    } else if (transferKeywords.any((k) => lower.contains(k))) {
      type = TransactionType.transfer;
    }

    // 6. Auto-detect category.
    String? category;
    if (lower.contains('غذا') ||
        lower.contains('رستوران') ||
        lower.contains('کافه') ||
        lower.contains('ناهار') ||
        lower.contains('شام') ||
        lower.contains('صبحانه') ||
        lower.contains('سوپرمارکت') ||
        lower.contains('میوه') ||
        lower.contains('نان') ||
        lower.contains('خوراکی') ||
        lower.contains('grocery') ||
        lower.contains('food') ||
        lower.contains('restaurant')) {
      category = 'خوراک و غذا';
    } else if (lower.contains('اسنپ') ||
        lower.contains('تپسی') ||
        lower.contains('تاکسی') ||
        lower.contains('بنزین') ||
        lower.contains('مترو') ||
        lower.contains('اتوبوس') ||
        lower.contains('تعمیرگاه') ||
        lower.contains('روغن') ||
        lower.contains('snapp') ||
        lower.contains('taxi') ||
        lower.contains('fuel')) {
      category = 'حمل و نقل';
    } else if (lower.contains('اجاره') ||
        lower.contains('قبض') ||
        lower.contains('برق') ||
        lower.contains('آب') ||
        lower.contains('گاز') ||
        lower.contains('اینترنت') ||
        lower.contains('شارژ ساختمان') ||
        lower.contains('rent') ||
        lower.contains('bill')) {
      category = 'قبوض و خانه';
    } else if (lower.contains('دارو') ||
        lower.contains('دکتر') ||
        lower.contains('پزشک') ||
        lower.contains('ویزیت') ||
        lower.contains('بیمارستان') ||
        lower.contains('دندانپزشکی') ||
        lower.contains('pharmacy') ||
        lower.contains('doctor')) {
      category = 'سلامت و درمان';
    } else if (type == TransactionType.income) {
      category = 'حقوق و درآمد';
    } else {
      category = 'سایر هزینه‌ها';
    }

    // 7. Clean description (strip currency & magnitude words and any number).
    String description = cleanInput;
    final wordsToRemove = [
      'تومان', 'تومن', 'ریال', 'میلیون', 'ملیون', 'هزار',
      'دلار', 'یورو', 'usd', 'eur', 'toman', 'rial',
    ];
    for (final w in wordsToRemove) {
      description = description.replaceAll(w, '');
    }
    // Remove the number token itself (Persian/Latin digits, any separators).
    description = description.replaceAll(
      RegExp(r'[\d۰-۹]+(?:[.,،][\d۰-۹]+)*'),
      '',
    );
    description = description.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (description.isEmpty) {
      description = category;
    }

    return ParsedTransactionDraft(
      originalText: cleanInput,
      description: description,
      amount: money,
      type: type,
      suggestedCategory: category,
      date: DateTime.now(),
      confidence: 0.95,
    );
  }
}
