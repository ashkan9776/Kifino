import '../../../../core/constants/app_currency.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../entities/parsed_transaction_draft.dart';

/// Which currency the user actually spoke, detected from keywords.
enum _SpokenCurrency { toman, rial, usd, eur }

class _AmountPhrase {
  final double value;
  final bool hasScaleWord;
  final int startToken;
  final int endToken; // inclusive

  const _AmountPhrase({
    required this.value,
    required this.hasScaleWord,
    required this.startToken,
    required this.endToken,
  });
}

/// Persian natural-language transaction parser.
///
/// Supports compound Persian numerals (digits and Persian number words like
/// "یک میلیون و دویست هزار" or "۲ و نیم میلیون"), relative dates
/// (دیروز/پریروز), token-boundary keyword matching (preventing false positives
/// such as نان/آناناس, سود/سودابه, آب/کباب, ریال/سریال), and automatic
/// Iranian currency normalization to [targetCurrency].
class PersianNlpTransactionParser {
  static const Map<String, double> _wordNumbers = {
    'یک': 1,
    'یه': 1,
    'دو': 2,
    'سه': 3,
    'چهار': 4,
    'پنج': 5,
    'شش': 6,
    'شیش': 6,
    'هفت': 7,
    'هشت': 8,
    'نه': 9,
    'ده': 10,
    'یازده': 11,
    'دوازده': 12,
    'سیزده': 13,
    'چهارده': 14,
    'پانزده': 15,
    'پونزده': 15,
    'شانزده': 16,
    'شونزده': 16,
    'هفده': 17,
    'هجده': 18,
    'نوزده': 19,
    'بیست': 20,
    'سی': 30,
    'چهل': 40,
    'پنجاه': 50,
    'شصت': 60,
    'هفتاد': 70,
    'هشتاد': 80,
    'نود': 90,
    'صد': 100,
    'یکصد': 100,
    'دویست': 200,
    'سیصد': 300,
    'چهارصد': 400,
    'پانصد': 500,
    'پونصد': 500,
    'ششصد': 600,
    'هفتصد': 700,
    'هشتصد': 800,
    'نهصد': 900,
  };

  static const Map<String, double> _scales = {
    'هزار': 1000.0,
    'thousand': 1000.0,
    'میلیون': 1000000.0,
    'ملیون': 1000000.0,
    'million': 1000000.0,
    'میلیارد': 1000000000.0,
    'billion': 1000000000.0,
  };

  static const Set<String> _currencyTokens = {
    'تومان',
    'تومن',
    'ریال',
    'دلار',
    'یورو',
    'usd',
    'eur',
    'irr',
    'toman',
    'rial',
  };

  static const String _leftBound =
      r'(?:^|(?<=[\s.,،؛:!?()\[\]{}"\x27«»\-/+\u200c]))';
  static const String _rightBound =
      r'(?=$|[\s.,،؛:!?()\[\]{}"\x27«»\-/+\u200c])';

  static bool _hasWord(String text, String word) {
    final escaped = RegExp.escape(word);
    return RegExp('$_leftBound$escaped$_rightBound').hasMatch(text);
  }

  static String _preprocessForTokenizing(String normalizedLatin) {
    var text = normalizedLatin
        .replaceAll('\u200c', ' ')
        .replaceAll('٫', '.')
        .replaceAll(RegExp(r'(?<=\d)[,،](?=\d)'), '')
        .replaceAll('هزارتومان', 'هزار تومان')
        .replaceAll('هزارتومن', 'هزار تومن')
        .replaceAll('میلیونتومان', 'میلیون تومان')
        .replaceAll('میلیونتومن', 'میلیون تومن')
        .replaceAll(',', ' ');
    // Separate numbers glued to words (e.g. "450هزار" -> "450 هزار").
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)(?=[^\d\s.,،])'),
      (m) => '${m.group(1)} ',
    );
    text = text.replaceAllMapped(
      RegExp(r'([^\d\s.,،])(?=\d)'),
      (m) => '${m.group(1)} ',
    );
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _stripPunct(String token) =>
      token.replaceAll(RegExp(r'^[.,،؛:!?()\[\]{}"\x27«»\-/+]+|[.,،؛:!?()\[\]{}"\x27«»\-/+]+$'), '');

  static bool _isAmountToken(String tok) {
    if (tok.isEmpty) return false;
    if (double.tryParse(tok) != null) return true;
    if (_wordNumbers.containsKey(tok)) return true;
    if (_scales.containsKey(tok)) return true;
    if (tok == 'نیم' || tok == 'نصف') return true;
    return false;
  }

  static _AmountPhrase? _parseAmount(List<String> tokens) {
    final clean = tokens.map((t) => _stripPunct(t).toLowerCase()).toList();
    final phrases = <_AmountPhrase>[];

    int i = 0;
    while (i < clean.length) {
      if (!_isAmountToken(clean[i])) {
        i++;
        continue;
      }

      // Collect contiguous compound phrase: number/scale tokens optionally
      // joined by 'و' when 'و' is followed by another number/scale token.
      final start = i;
      int end = i;
      int scan = i + 1;
      while (scan < clean.length) {
        final cur = clean[scan];
        if (_isAmountToken(cur)) {
          end = scan;
          scan++;
        } else if (cur == 'و' &&
            scan + 1 < clean.length &&
            _isAmountToken(clean[scan + 1])) {
          scan++;
        } else {
          break;
        }
      }

      // Evaluate tokens[start..end].
      double total = 0.0;
      double current = 0.0;
      double lastScale = 0.0;
      bool hasScale = false;
      bool hasNumber = false;

      for (int k = start; k <= end; k++) {
        final tok = clean[k];
        if (tok == 'و') continue;

        final literal = double.tryParse(tok);
        if (literal != null) {
          current += literal;
          hasNumber = true;
          continue;
        }

        final wordVal = _wordNumbers[tok];
        if (wordVal != null) {
          current += wordVal;
          hasNumber = true;
          continue;
        }

        if (tok == 'نیم' || tok == 'نصف') {
          // Check whether a scale word follows before the next non-fraction term.
          bool scaleFollows = false;
          for (int look = k + 1; look <= end; look++) {
            final nextTok = clean[look];
            if (nextTok == 'و') continue;
            if (_scales.containsKey(nextTok)) scaleFollows = true;
            break;
          }
          if (!scaleFollows && current == 0 && lastScale > 0) {
            total += lastScale * 0.5;
          } else {
            current += 0.5;
          }
          hasNumber = true;
          continue;
        }

        final scale = _scales[tok];
        if (scale != null) {
          final coeff = current == 0 ? 1.0 : current;
          total += coeff * scale;
          current = 0.0;
          lastScale = scale;
          hasScale = true;
          hasNumber = true;
        }
      }

      total += current;
      if (hasNumber && total > 0) {
        phrases.add(
          _AmountPhrase(
            value: total,
            hasScaleWord: hasScale,
            startToken: start,
            endToken: end,
          ),
        );
      }
      i = end + 1;
    }

    if (phrases.isEmpty) return null;

    // Prefer a phrase explicitly carrying a magnitude scale (e.g. میلیون/هزار)
    // or directly adjacent to a currency keyword, else first valid phrase.
    for (final p in phrases) {
      if (p.hasScaleWord) return p;
    }
    for (final p in phrases) {
      if (p.endToken + 1 < clean.length &&
          _currencyTokens.contains(clean[p.endToken + 1])) {
        return p;
      }
    }
    return phrases.first;
  }

  static ParsedTransactionDraft? parse(
    String rawInput, {
    Currency? targetCurrency,
  }) {
    final resolvedTarget = targetCurrency ?? AppCurrency.base;
    final cleanInput = TextNormalizer.normalizePersian(rawInput).trim();
    if (cleanInput.isEmpty) return null;

    final normalizedDigits = TextNormalizer.toLatinDigits(cleanInput);
    final lower = normalizedDigits.toLowerCase();

    // 1. Detect spoken currency cleanly via word/symbol matching.
    _SpokenCurrency spoken = _SpokenCurrency.toman;
    if (_hasWord(lower, 'تومان') ||
        _hasWord(lower, 'تومن') ||
        _hasWord(lower, 'toman') ||
        lower.contains('هزارتومان') ||
        lower.contains('هزارتومن')) {
      spoken = _SpokenCurrency.toman;
    } else if (_hasWord(lower, 'ریال') ||
        _hasWord(lower, 'rial') ||
        _hasWord(lower, 'irr')) {
      spoken = _SpokenCurrency.rial;
    } else if (_hasWord(lower, 'دلار') ||
        _hasWord(lower, 'usd') ||
        lower.contains(r'$')) {
      spoken = _SpokenCurrency.usd;
    } else if (_hasWord(lower, 'یورو') ||
        _hasWord(lower, 'eur') ||
        lower.contains('€')) {
      spoken = _SpokenCurrency.eur;
    }

    // 2. Parse compound Persian amounts.
    final tokenizedText = _preprocessForTokenizing(normalizedDigits);
    final tokens = tokenizedText.isEmpty
        ? <String>[]
        : tokenizedText.split(RegExp(r'\s+'));
    final amountPhrase = _parseAmount(tokens);
    if (amountPhrase == null || amountPhrase.value <= 0) return null;

    double finalAmount = amountPhrase.value;
    if (!amountPhrase.hasScaleWord &&
        spoken == _SpokenCurrency.toman &&
        finalAmount <= 500 &&
        !_hasWord(lower, 'تومان') &&
        !lower.contains('هزارتومان')) {
      // Colloquial shortcut: "۶۵ تومن" means 65,000 Tomans, whereas explicit
      // "۲۵۰ تومان" or "۲ و نیم میلیون" is kept at face value.
      finalAmount *= 1000.0;
    }

    // 3. Build Money in SPOKEN currency first.
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

    // 4. Normalize compatible Iranian currencies into target unit.
    final Money money =
        spokenMoney.isCompatibleWith(resolvedTarget) &&
            spokenCurrency != resolvedTarget
        ? spokenMoney.normalizeTo(resolvedTarget)
        : spokenMoney;

    // 5. Detect transaction type. Check transfer BEFORE income so "واریز به حساب"
    // is never swallowed by "واریز".
    TransactionType type = TransactionType.expense;
    final normLowerForKeywords = lower.replaceAll('\u200c', ' ');
    const transferPhrases = [
      'واریز به حساب',
      'کارت به کارت',
      'کارت‌به‌کارت',
      'انتقال',
      'جابجایی',
      'transfer',
    ];
    final isTransfer = transferPhrases.any(
      (k) => k == 'انتقال' || k == 'جابجایی' || k == 'transfer'
          ? _hasWord(normLowerForKeywords, k)
          : normLowerForKeywords.contains(k),
    );

    if (isTransfer) {
      type = TransactionType.transfer;
    } else {
      final incomeExactWords = [
        'حقوق',
        'واریز',
        'درآمد',
        'درامد',
        'پاداش',
        'سود',
        'فروش',
        'طلب',
        'بستانکار',
        'salary',
        'income',
        'deposit',
        'earned',
        'bonus',
      ];
      final incomeHit = incomeExactWords.any((k) => _hasWord(lower, k));
      if (incomeHit) {
        type = TransactionType.income;
      }
    }

    // 6. Auto-detect category with context-first and word-boundary matching.
    String category;
    final isFoodOil =
        lower.contains('روغن مایع') ||
        lower.contains('روغن زیتون') ||
        lower.contains('روغن نباتی') ||
        lower.contains('روغن سرخ') ||
        lower.contains('روغن حیوانی') ||
        lower.contains('روغن خوراکی') ||
        lower.contains('روغن آفتابگردان') ||
        lower.contains('روغن کنجد');

    if (isFoodOil ||
        _hasWord(lower, 'نان') ||
        lower.contains('غذا') ||
        lower.contains('رستوران') ||
        lower.contains('کافه') ||
        lower.contains('ناهار') ||
        lower.contains('شام') ||
        lower.contains('صبحانه') ||
        lower.contains('سوپرمارکت') ||
        lower.contains('میوه') ||
        lower.contains('خوراکی') ||
        lower.contains('کباب') ||
        _hasWord(lower, 'grocery') ||
        _hasWord(lower, 'food') ||
        _hasWord(lower, 'restaurant')) {
      category = 'خوراک و غذا';
    } else if (lower.contains('اسنپ') ||
        lower.contains('تپسی') ||
        lower.contains('تاکسی') ||
        lower.contains('بنزین') ||
        lower.contains('مترو') ||
        lower.contains('اتوبوس') ||
        lower.contains('تعمیرگاه') ||
        lower.contains('روغن موتور') ||
        lower.contains('تعویض روغن') ||
        (!isFoodOil && _hasWord(lower, 'روغن')) ||
        _hasWord(lower, 'snapp') ||
        _hasWord(lower, 'taxi') ||
        _hasWord(lower, 'fuel')) {
      category = 'حمل و نقل';
    } else if (lower.contains('اجاره') ||
        lower.contains('قبض') ||
        lower.contains('برق') ||
        _hasWord(lower, 'آب') ||
        _hasWord(lower, 'گاز') ||
        lower.contains('اینترنت') ||
        lower.contains('شارژ ساختمان') ||
        _hasWord(lower, 'rent') ||
        _hasWord(lower, 'bill')) {
      category = 'قبوض و خانه';
    } else if (lower.contains('دارو') ||
        lower.contains('دکتر') ||
        lower.contains('پزشک') ||
        lower.contains('ویزیت') ||
        lower.contains('بیمارستان') ||
        lower.contains('دندانپزشکی') ||
        _hasWord(lower, 'pharmacy') ||
        _hasWord(lower, 'doctor')) {
      category = 'سلامت و درمان';
    } else if (type == TransactionType.income) {
      category = 'حقوق و درآمد';
    } else {
      category = 'سایر هزینه‌ها';
    }

    // 7. Relative date detection.
    final now = DateTime.now();
    DateTime txDate = now;
    if (_hasWord(lower, 'پریروز')) {
      txDate = now.subtract(const Duration(days: 2));
    } else if (_hasWord(lower, 'دیروز')) {
      txDate = now.subtract(const Duration(days: 1));
    }

    // 8. Build clean description by omitting ONLY the parsed amount phrase
    // tokens, standalone currency tokens, and relative date adverbs.
    // Words like "سریال" remain completely intact!
    final keptTokens = <String>[];
    for (int t = 0; t < tokens.length; t++) {
      if (t >= amountPhrase.startToken && t <= amountPhrase.endToken) {
        continue;
      }
      final tok = _stripPunct(tokens[t]).toLowerCase();
      if (_currencyTokens.contains(tok) ||
          tok == 'دیروز' ||
          tok == 'پریروز' ||
          tok == 'امروز' ||
          tok == r'$' ||
          tok == '€') {
        continue;
      }
      keptTokens.add(tokens[t]);
    }
    var description = keptTokens.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (description.isEmpty) {
      description = category;
    } else {
      // Restore Persian numerals inside surviving words if any numbers remain.
      description = TextNormalizer.normalizePersian(description);
    }

    return ParsedTransactionDraft(
      originalText: cleanInput,
      description: description,
      amount: money,
      type: type,
      suggestedCategory: category,
      date: txDate,
      confidence: 0.95,
    );
  }
}
