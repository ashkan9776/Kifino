import '../../../../core/constants/app_currency.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../accounts/domain/entities/account_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../entities/parsed_transaction_draft.dart';

class _BankDef {
  final List<String> aliases;
  final String displayName;
  final String matchKeyword;

  const _BankDef(this.aliases, this.displayName, this.matchKeyword);
}

class _BalanceMatch {
  final Money money;
  final int start;
  final int end;

  const _BalanceMatch({
    required this.money,
    required this.start,
    required this.end,
  });
}

/// Parser for Iranian banking transaction SMS messages (پیامک تراکنش بانکی).
///
/// Supports traditional Rial-denominated bank SMS (Mellat, Melli, Saderat,
/// Saman, Pasargad, Keshavarzi, Tejarat, Resalat, Sepah, Ayandeh, etc.) as
/// well as Toman-denominated neobanks (BluBank, Wepod), normalizes amounts
/// into [targetCurrency] (defaulting to [AppCurrency.base]), converts Jalali
/// timestamps to [DateTime], extracts remaining balances, and optionally
/// matches card digits or bank names against [AccountEntity] records.
class IranianBankSmsParser {
  static const List<_BankDef> _banks = [
    _BankDef(['بلوبانک', 'بلو بانک', 'بلو'], 'بلوبانک', 'بلو'),
    _BankDef(['ویپاد'], 'ویپاد', 'ویپاد'),
    _BankDef(['به‌پرداخت ملت', 'به پرداخت ملت', 'بانک ملت'], 'بانک ملت', 'ملت'),
    _BankDef(['بانک ملی ایران', 'بانک ملی'], 'بانک ملی', 'ملی'),
    _BankDef(['بانک صادرات ایران', 'بانک صادرات'], 'بانک صادرات', 'صادرات'),
    _BankDef(['بانک سامان'], 'بانک سامان', 'سامان'),
    _BankDef(['بانک پاسارگاد'], 'بانک پاسارگاد', 'پاسارگاد'),
    _BankDef(['بانک کشاورزی'], 'بانک کشاورزی', 'کشاورزی'),
    _BankDef(['بانک تجارت'], 'بانک تجارت', 'تجارت'),
    _BankDef(
      ['بانک قرض الحسنه رسالت', 'بانک قرض‌الحسنه رسالت', 'بانک رسالت'],
      'بانک رسالت',
      'رسالت',
    ),
    _BankDef(
      ['بانک قرض الحسنه مهر', 'بانک مهر ایران'],
      'بانک مهر ایران',
      'مهر',
    ),
    _BankDef(['بانک سپه'], 'بانک سپه', 'سپه'),
    _BankDef(['بانک آینده'], 'بانک آینده', 'آینده'),
    _BankDef(['بانک مسکن'], 'بانک مسکن', 'مسکن'),
    _BankDef(['بانک رفاه'], 'بانک رفاه', 'رفاه'),
    _BankDef(['بانک شهر'], 'بانک شهر', 'شهر'),
    _BankDef(['بانک دی'], 'بانک دی', 'دی'),
    _BankDef(['بانک سینا'], 'بانک سینا', 'سینا'),
    _BankDef(['بانک پارسیان'], 'بانک پارسیان', 'پارسیان'),
    _BankDef(
      ['بانک اقتصاد نوین', 'اقتصاد نوین'],
      'بانک اقتصاد نوین',
      'اقتصاد نوین',
    ),
    _BankDef(['بانک کارآفرین'], 'بانک کارآفرین', 'کارآفرین'),
    _BankDef(['بانک سرمایه'], 'بانک سرمایه', 'سرمایه'),
    _BankDef(['بانک گردشگری'], 'بانک گردشگری', 'گردشگری'),
    _BankDef(['پست بانک'], 'پست بانک', 'پست'),
  ];

  static const String _leftBound =
      r'(?:^|(?<=[\s.,،؛:!?()\[\]{}"\x27«»\-/+\u200c]))';
  static const String _rightBound =
      r'(?=$|[\s.,،؛:!?()\[\]{}"\x27«»\-/+\u200c])';

  static bool _hasWord(String text, String word) {
    final escaped = RegExp.escape(word);
    return RegExp('$_leftBound$escaped$_rightBound').hasMatch(text);
  }

  /// Heuristic detector that distinguishes structured Iranian bank SMS alerts
  /// from casual Persian chat phrases (like "واریز به حساب ۵۰۰ هزار تومان").
  static bool looksLikeBankSms(String rawInput) {
    final normalized = _normalizeInput(rawInput);
    if (normalized.isEmpty) return false;

    int signals = 0;

    if (_detectBank(normalized) != null ||
        RegExp(r'(?:^|\n)\s*بانک\s+[^\n]+').hasMatch(normalized)) {
      signals++;
    }

    if (_findBalanceMatch(normalized, _inferDefaultCurrency(normalized)) !=
        null) {
      signals++;
    }

    if (RegExp(
      r'(?:\*{2,}\d{4}|\*\d{4}|\.{2,}\d{4}|(?:شماره\s*)?(?:کارت|حساب|سپرده)\s*[:：\-]?\s*[*\d.\-]{4,})',
    ).hasMatch(normalized)) {
      signals++;
    }

    if (RegExp(r'مبلغ\s*[:：\-]?\s*[0-9,،]+').hasMatch(normalized) ||
        RegExp(
          r'(?:برداشت|واریز|خرید|انتقال|افزایش\s+موجودی|کاهش\s+موجودی)\s*[:：\-]\s*[0-9,،]+',
        ).hasMatch(normalized) ||
        normalized.contains('از حسابت برداشت شد') ||
        normalized.contains('به حسابت واریز شد')) {
      signals++;
    }

    final hasMultilineAndAmount =
        normalized.contains('\n') &&
        RegExp(r'[0-9,،]+\s*(?:ریال|تومان|تومن)').hasMatch(normalized);
    final hasJalaliTimestamp = RegExp(r'\b1[34]\d{2}[/-]\d{1,2}[/-]\d{1,2}\b')
        .hasMatch(normalized);
    if (hasMultilineAndAmount || hasJalaliTimestamp) {
      signals++;
    }

    return signals >= 2;
  }

  /// Parses an Iranian bank SMS into a [ParsedTransactionDraft]. Returns `null`
  /// when the input is not a recognized bank SMS or lacks a valid transaction
  /// amount (e.g. a message containing only `مانده`).
  static ParsedTransactionDraft? parse(
    String rawInput, {
    Currency? targetCurrency,
    List<AccountEntity>? accounts,
    DateTime? referenceDate,
  }) {
    final cleanOriginal = TextNormalizer.normalizePersian(rawInput).trim();
    if (cleanOriginal.isEmpty) return null;

    final normalized = _normalizeInput(rawInput);
    if (!looksLikeBankSms(rawInput)) return null;

    final resolvedTarget = targetCurrency ?? AppCurrency.base;
    final defaultSmsCurrency = _inferDefaultCurrency(normalized);

    // 1. Detect bank metadata and strip PSP phrasing like "به‌پرداخت" from
    // keyword analysis text so it never false-triggers "پرداخت".
    final bankDef = _detectBank(normalized);
    var workText = normalized;

    // 2. Extract and mask remaining balance (مانده / موجودی) first, while
    // guarding against "افزایش موجودی" and "کاهش موجودی".
    final balanceMatch = _findBalanceMatch(workText, defaultSmsCurrency);
    Money? remainingBalance;
    if (balanceMatch != null) {
      remainingBalance = _normalizeMoney(balanceMatch.money, resolvedTarget);
      workText = _maskSpan(workText, balanceMatch.start, balanceMatch.end);
    }

    // 3. Extract card / account hint digits and mask card/account identifiers
    // plus tracking codes so their numbers are never read as amounts.
    final accountHintDigits = _extractAccountDigits(workText);
    workText = _maskSensitiveIdentifiers(workText);

    // 4. Extract Jalali / Gregorian date-time (and mask it).
    final dateResult = _extractAndMaskDateTime(
      workText,
      referenceDate: referenceDate,
    );
    final txDate = dateResult.$1;
    workText = dateResult.$2;

    // 5. Extract transaction amount cleanly (distinct from balance & cards).
    final amountMoney = _extractTransactionAmount(
      workText,
      defaultCurrency: defaultSmsCurrency,
    );
    if (amountMoney == null || amountMoney.minorUnits <= 0) {
      return null;
    }

    final normalizedAmount = _normalizeMoney(amountMoney, resolvedTarget);

    // 6. Determine transaction type (income vs expense) on text with
    // PSP names masked out.
    final typeText = workText
        .replaceAll('به‌پرداخت', ' ')
        .replaceAll('به پرداخت', ' ')
        .replaceAll('پرداخت الکترونیک', ' ');
    final txType = _detectTransactionType(typeText);
    if (txType == null) {
      return null;
    }

    // 7. Match saved user account (card digits first, then bank name).
    final matchedAccount = _matchAccount(
      accounts,
      hintDigits: accountHintDigits,
      bankDef: bankDef,
    );

    // 8. Derive human-readable Persian description & suggested category.
    final description = _buildDescription(
      type: txType,
      normalizedText: typeText,
      bankName: bankDef?.displayName,
      hintDigits: accountHintDigits,
    );
    final suggestedCategory = _suggestCategory(txType, typeText);

    return ParsedTransactionDraft(
      originalText: cleanOriginal,
      description: description,
      amount: normalizedAmount,
      type: txType,
      suggestedCategory: suggestedCategory,
      date: txDate,
      confidence: bankDef != null || accountHintDigits != null ? 0.98 : 0.92,
      matchedAccountId: matchedAccount?.id,
      bankName: bankDef?.displayName,
      remainingBalance: remainingBalance,
      accountHintDigits: accountHintDigits,
    );
  }

  static String _normalizeInput(String rawInput) {
    final faNormalized = TextNormalizer.normalizePersian(rawInput)
        .replaceAll('\u200c', ' ')
        .replaceAll('\r\n', '\n')
        .replaceAll('٫', '.')
        .replaceAll('ريال', 'ریال');
    return TextNormalizer.toLatinDigits(faNormalized).trim();
  }

  static Currency _inferDefaultCurrency(String normalized) {
    final lower = normalized.toLowerCase();
    final hasToman = _hasWord(lower, 'تومان') || _hasWord(lower, 'تومن');
    final hasRial = _hasWord(lower, 'ریال') || _hasWord(lower, 'irr');
    if (hasToman && !hasRial) return Currency.toman;
    return Currency.irr;
  }

  static Currency _currencyFromUnit(String? unit, Currency fallback) {
    final u = unit?.trim().toLowerCase();
    if (u == 'تومان' || u == 'تومن') return Currency.toman;
    if (u == 'ریال' || u == 'irr') return Currency.irr;
    return fallback;
  }

  static Money _normalizeMoney(Money money, Currency target) {
    if (money.currency == target) return money;
    if (money.isCompatibleWith(target)) {
      return money.normalizeTo(target);
    }
    return money;
  }

  static _BankDef? _detectBank(String normalized) {
    for (final bank in _banks) {
      for (final alias in bank.aliases) {
        if (!alias.contains(' ') && alias.length <= 5) {
          if (_hasWord(normalized, alias)) return bank;
        } else if (normalized.contains(alias)) {
          return bank;
        }
      }
    }
    return null;
  }

  static int? _parseGroupedInt(String raw) {
    final digitsOnly = raw.replaceAll(RegExp(r'[,،\s]'), '');
    return int.tryParse(digitsOnly);
  }

  static _BalanceMatch? _findBalanceMatch(
    String text,
    Currency defaultCurrency,
  ) {
    final balanceRegex = RegExp(
      r'(?<!افزایش\s)(?<!کاهش\s)(?:مانده(?:\s+(?:حساب|فعلی|قابل\s+برداشت|موجودی))?|موجودی\s+فعلی|موجودی(?:\s+حساب)?(?=\s*[:：\-]))\s*[:：\-]?\s*([0-9][0-9,،]*)\s*(ریال|تومان|تومن|irr)?',
      caseSensitive: false,
    );
    final match = balanceRegex.firstMatch(text);
    if (match == null) return null;

    final amountInt = _parseGroupedInt(match.group(1) ?? '');
    if (amountInt == null) return null;

    final currency = _currencyFromUnit(match.group(2), defaultCurrency);
    return _BalanceMatch(
      money: Money.fromMinor(amountInt, currency),
      start: match.start,
      end: match.end,
    );
  }

  static String? _extractAccountDigits(String text) {
    // 1. Masked PAN or asterisk-prefixed 4 digits: 6037********4321, *4321
    final maskedMatch = RegExp(r'(?:\d{4}[\s\-*xX]+|\*{2,}|\*|\.{2,})(\d{4})\b')
        .firstMatch(text);
    if (maskedMatch != null) return maskedMatch.group(1);

    // 2. Explicit account/card label with numeric identifier
    final labeledMatch = RegExp(
      r'(?:شماره\s*)?(?:کارت|حساب|سپرده)\s*[:：\-]?\s*[0-9.*\-]{4,}',
    ).firstMatch(text);
    if (labeledMatch != null) {
      final onlyDigits = labeledMatch.group(0)!.replaceAll(RegExp(r'\D'), '');
      if (onlyDigits.length >= 4) {
        return onlyDigits.substring(onlyDigits.length - 4);
      }
    }
    return null;
  }

  static String _maskSensitiveIdentifiers(String text) {
    var out = text;
    // Mask tracking / reference numbers.
    out = out.replaceAll(
      RegExp(r'(?:کد\s*)?(?:پیگیری|رهگیری|ارجاع|پایانه)\s*[:：\-]?\s*\d+'),
      ' ',
    );
    // Mask dotted account numbers like 205.8100.123456.1
    out = out.replaceAll(RegExp(r'\b\d+(?:\.\d+){2,}\b'), ' ');
    // Mask full/masked card numbers like 6037********4321 or ****1122
    out = out.replaceAll(
      RegExp(r'(?:\d{4,6})?[\s\-*xX]{2,}\d{4}\b|\*{1,}\d{4}|\.{2,}\d{4}'),
      ' ',
    );
    // Mask labeled account/card IDs whose numbers might remain
    out = out.replaceAll(
      RegExp(
        r'(?:(?:شماره\s*)?(?:کارت|حساب|سپرده)(?:\s+به)?)\s*[:：\-]?\s*[0-9.*\-]{4,}',
      ),
      ' ',
    );
    return out;
  }

  static (DateTime, String) _extractAndMaskDateTime(
    String text, {
    DateTime? referenceDate,
  }) {
    final fallbackNow = referenceDate ?? DateTime.now();
    var masked = text;

    // Match YYYY/MM/DD or YY/MM/DD optionally followed by HH:mm(:ss)?
    final dateMatch = RegExp(
      r'(?:تاریخ\s*[:：\-]?\s*)?\b(\d{2,4})[/-](\d{1,2})[/-](\d{1,2})\b(?:\s*[-،,]?\s*(\d{1,2}):(\d{2})(?::(\d{2}))?)?',
    ).firstMatch(masked);

    DateTime resolved = fallbackNow;
    if (dateMatch != null) {
      final rawYear = int.tryParse(dateMatch.group(1)!);
      final month = int.tryParse(dateMatch.group(2)!);
      final day = int.tryParse(dateMatch.group(3)!);
      final hour = int.tryParse(dateMatch.group(4) ?? '12') ?? 12;
      final minute = int.tryParse(dateMatch.group(5) ?? '0') ?? 0;
      final second = int.tryParse(dateMatch.group(6) ?? '0') ?? 0;

      if (rawYear != null &&
          month != null &&
          day != null &&
          month >= 1 &&
          month <= 12 &&
          day >= 1 &&
          day <= 31 &&
          hour >= 0 &&
          hour <= 23 &&
          minute >= 0 &&
          minute <= 59 &&
          second >= 0 &&
          second <= 59) {
        if (rawYear >= 1900) {
          resolved = DateTime(rawYear, month, day, hour, minute, second);
        } else {
          final jalaliYear = rawYear < 100
              ? (rawYear <= 50 ? 1400 + rawYear : 1300 + rawYear)
              : rawYear;
          if (jalaliYear >= 1300 && jalaliYear <= 1500) {
            final maxDay = month <= 6 ? 31 : 30;
            if (day <= maxDay) {
              resolved = JalaliDate(
                jalaliYear,
                month,
                day,
              ).toDateTime(hour, minute, second);
            }
          }
        }
      }
      masked = _maskSpan(masked, dateMatch.start, dateMatch.end);
    }

    // Mask any standalone time tokens left behind (e.g. "ساعت 14:23")
    masked = masked.replaceAll(
      RegExp(r'(?:ساعت\s*[:：\-]?\s*)?\b\d{1,2}:\d{2}(?::\d{2})?\b'),
      ' ',
    );

    return (resolved, masked);
  }

  static Money? _extractTransactionAmount(
    String workText, {
    required Currency defaultCurrency,
  }) {
    // 1. Explicit labeled amount: "مبلغ: 2,500,000 ریال" or "برداشت: 950,000 ریال"
    final labeledRegex = RegExp(
      r'(?:مبلغ|برداشت(?:\s+از\s+(?:حساب|کارت))?|وار[یی]ز(?:\s+به(?:\s+(?:حساب|کارت))?)?|خرید(?:\s+(?:با\s+کارت|اینترنتی|حضوری))?|انتقال(?:\s+(?:از\s+کارت|وجه))?|افزایش\s+موجودی|کاهش\s+موجودی|کسر|پرداخت(?:\s+قبض)?)\s*[:：\-]?\s*([0-9][0-9,،]*)\s*(ریال|تومان|تومن|irr)?',
      caseSensitive: false,
    );
    final labeledMatch = labeledRegex.firstMatch(workText);
    if (labeledMatch != null) {
      final val = _parseGroupedInt(labeledMatch.group(1) ?? '');
      if (val != null && val > 0) {
        return Money.fromMinor(
          val,
          _currencyFromUnit(labeledMatch.group(2), defaultCurrency),
        );
      }
    }

    // 2. Amount-first neobank phrasing: "250,000 تومان از حسابت برداشت شد"
    final neobankRegex = RegExp(
      r'([0-9][0-9,،]*)\s*(ریال|تومان|تومن)\s*(?:از\s+حسابت|به\s+حسابت)',
      caseSensitive: false,
    );
    final neoMatch = neobankRegex.firstMatch(workText);
    if (neoMatch != null) {
      final val = _parseGroupedInt(neoMatch.group(1) ?? '');
      if (val != null && val > 0) {
        return Money.fromMinor(
          val,
          _currencyFromUnit(neoMatch.group(2), defaultCurrency),
        );
      }
    }

    // 3. Generic fallback: first explicit number paired with currency unit
    final unitRegex = RegExp(
      r'([0-9][0-9,،]*)\s*(ریال|تومان|تومن|irr)\b',
      caseSensitive: false,
    );
    final unitMatch = unitRegex.firstMatch(workText);
    if (unitMatch != null) {
      final val = _parseGroupedInt(unitMatch.group(1) ?? '');
      if (val != null && val > 0) {
        return Money.fromMinor(
          val,
          _currencyFromUnit(unitMatch.group(2), defaultCurrency),
        );
      }
    }

    return null;
  }

  static TransactionType? _detectTransactionType(String text) {
    final lower = text.toLowerCase();

    int earliestIncome = 1 << 30;
    for (final kw in const [
      'افزایش موجودی',
      'به حسابت واریز',
      'واریز',
      'افزایش',
      'عودت',
      'برگشت وجه',
      'بستانکار',
      'سود',
    ]) {
      final idx = lower.indexOf(kw);
      if (idx != -1 && _hasWord(lower, kw.split(' ').first)) {
        if (idx < earliestIncome) earliestIncome = idx;
      } else if (idx != -1 && kw.contains(' ')) {
        if (idx < earliestIncome) earliestIncome = idx;
      }
    }

    int earliestExpense = 1 << 30;
    for (final kw in const [
      'کاهش موجودی',
      'از حسابت برداشت',
      'برداشت',
      'خرید',
      'کاهش',
      'کسر',
      'پرداخت',
      'انتقال',
      'کارت به کارت',
      'کارمزد',
      'قسط',
    ]) {
      final idx = lower.indexOf(kw);
      if (idx != -1) {
        final singleWordOk = kw.contains(' ') || _hasWord(lower, kw);
        if (singleWordOk && idx < earliestExpense) {
          earliestExpense = idx;
        }
      }
    }

    if (earliestIncome == (1 << 30) && earliestExpense == (1 << 30)) {
      return null;
    }
    return earliestIncome < earliestExpense
        ? TransactionType.income
        : TransactionType.expense;
  }

  static AccountEntity? _matchAccount(
    List<AccountEntity>? accounts, {
    required String? hintDigits,
    required _BankDef? bankDef,
  }) {
    if (accounts == null || accounts.isEmpty) return null;
    final active = accounts
        .where((a) => !a.isDeleted && !a.isArchived)
        .toList();
    if (active.isEmpty) return null;

    if (hintDigits != null && hintDigits.length == 4) {
      for (final acc in active) {
        final cardDigits = TextNormalizer.toLatinDigits(
          acc.cardNumberLastFour ?? '',
        ).replaceAll(RegExp(r'\D'), '');
        if (cardDigits.length >= 4 &&
            cardDigits.substring(cardDigits.length - 4) == hintDigits) {
          return acc;
        }
      }
      for (final acc in active) {
        final normalizedName = TextNormalizer.toLatinDigits(acc.name);
        if (normalizedName.contains(hintDigits)) {
          return acc;
        }
      }
    }

    if (bankDef != null) {
      final keyword = TextNormalizer.normalizeForSearch(bankDef.matchKeyword);
      for (final acc in active) {
        final bankField = TextNormalizer.normalizeForSearch(acc.bankName ?? '');
        final nameField = TextNormalizer.normalizeForSearch(acc.name);
        if (bankField.contains(keyword) || nameField.contains(keyword)) {
          return acc;
        }
      }
    }

    return null;
  }

  static String _buildDescription({
    required TransactionType type,
    required String normalizedText,
    required String? bankName,
    required String? hintDigits,
  }) {
    final String actionLabel;
    if (type == TransactionType.income) {
      actionLabel = normalizedText.contains('سود')
          ? 'سود بانکی'
          : (normalizedText.contains('عودت') ? 'عودت وجه' : 'واریز به حساب');
    } else if (normalizedText.contains('خرید')) {
      actionLabel = 'خرید با کارت';
    } else if (normalizedText.contains('انتقال') ||
        normalizedText.contains('کارت به کارت')) {
      actionLabel = 'انتقال وجه';
    } else if (normalizedText.contains('پرداخت')) {
      actionLabel = 'پرداخت';
    } else {
      actionLabel = 'برداشت از حساب';
    }

    final parts = <String>[actionLabel];
    if (bankName != null) parts.add(bankName);
    if (hintDigits != null) {
      parts.add(TextNormalizer.auto('*$hintDigits'));
    }
    return parts.join(' - ');
  }

  static String _suggestCategory(TransactionType type, String text) {
    if (type == TransactionType.income) return 'حقوق و درآمد';
    final lower = text.toLowerCase();
    if (lower.contains('قبض') ||
        lower.contains('برق') ||
        lower.contains('اینترنت') ||
        _hasWord(lower, 'گاز') ||
        _hasWord(lower, 'آب')) {
      return 'قبوض و خانه';
    }
    if (lower.contains('اسنپ') ||
        lower.contains('تپسی') ||
        lower.contains('بنزین')) {
      return 'حمل و نقل';
    }
    if (lower.contains('سوپرمارکت') || lower.contains('رستوران')) {
      return 'خوراک و غذا';
    }
    return 'سایر هزینه‌ها';
  }

  static String _maskSpan(String text, int start, int end) {
    return '${text.substring(0, start)} ${text.substring(end)}';
  }
}
