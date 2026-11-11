import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/utils/date_utils.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/accounts/domain/entities/account_entity.dart';
import 'package:kifino/features/ai_assistant/domain/services/iranian_bank_sms_parser.dart';
import 'package:kifino/features/ai_assistant/domain/services/persian_nlp_transaction_parser.dart';
import 'package:kifino/features/transactions/domain/entities/transaction_entity.dart';

void main() {
  final now = DateTime(2025, 1, 1);

  final sampleAccounts = [
    AccountEntity(
      id: 'acc-mellat',
      name: 'حساب اصلی ملت',
      type: AccountType.bankCard,
      currency: Currency.toman,
      initialBalance: const Money.fromMinor(10000000, Currency.toman),
      currentBalance: const Money.fromMinor(10000000, Currency.toman),
      cardNumberLastFour: '6542',
      bankName: 'بانک ملت',
      createdAt: now,
      updatedAt: now,
    ),
    AccountEntity(
      id: 'acc-blu',
      name: 'بلوبانک شخصی',
      type: AccountType.bankCard,
      currency: Currency.toman,
      initialBalance: const Money.fromMinor(5000000, Currency.toman),
      currentBalance: const Money.fromMinor(5000000, Currency.toman),
      cardNumberLastFour: '9012',
      bankName: 'بلوبانک',
      createdAt: now,
      updatedAt: now,
    ),
    AccountEntity(
      id: 'acc-melli',
      name: 'کارت ملی',
      type: AccountType.bankCard,
      currency: Currency.toman,
      initialBalance: const Money.fromMinor(2000000, Currency.toman),
      currentBalance: const Money.fromMinor(2000000, Currency.toman),
      cardNumberLastFour: '4321',
      bankName: 'بانک ملی',
      createdAt: now,
      updatedAt: now,
    ),
    AccountEntity(
      id: 'acc-archived',
      name: 'کارت بایگانی',
      type: AccountType.bankCard,
      currency: Currency.toman,
      initialBalance: const Money.fromMinor(0, Currency.toman),
      currentBalance: const Money.fromMinor(0, Currency.toman),
      cardNumberLastFour: '1122',
      bankName: 'بانک صادرات',
      isArchived: true,
      createdAt: now,
      updatedAt: now,
    ),
  ];

  group('IranianBankSmsParser Tests', () {
    test('parses Bank Mellat Rial withdrawal, Jalali timestamp, balance & card match', () {
      const sms = '''
بانک ملت
برداشت از حساب: ...6542
مبلغ: 2,500,000 ریال
تاریخ: 1403/08/15 14:23
مانده: 18,450,000 ریال
''';
      final draft = IranianBankSmsParser.parse(
        sms,
        targetCurrency: Currency.toman,
        accounts: sampleAccounts,
      );

      expect(draft, isNotNull);
      expect(draft!.type, equals(TransactionType.expense));
      expect(draft.amount.currency, equals(Currency.toman));
      expect(draft.amount.minorUnits, equals(250000));
      expect(draft.remainingBalance?.minorUnits, equals(1845000));
      expect(draft.bankName, equals('بانک ملت'));
      expect(draft.accountHintDigits, equals('6542'));
      expect(draft.matchedAccountId, equals('acc-mellat'));

      final expectedDate = const JalaliDate(1403, 8, 15).toDateTime(14, 23);
      expect(draft.date, equals(expectedDate));
    });

    test('parses Bank Melli outgoing transfer as expense without failing transfer validation', () {
      const sms = '''
بانک ملی ایران
انتقال از کارت: 6037********4321
مبلغ: 4,200,000 ریال
1403/08/20-18:40
موجودی: 12,500,000 ریال
''';
      final draft = IranianBankSmsParser.parse(
        sms,
        targetCurrency: Currency.toman,
        accounts: sampleAccounts,
      );

      expect(draft, isNotNull);
      expect(draft!.type, equals(TransactionType.expense));
      expect(draft.amount.minorUnits, equals(420000));
      expect(draft.remainingBalance?.minorUnits, equals(1250000));
      expect(draft.accountHintDigits, equals('4321'));
      expect(draft.matchedAccountId, equals('acc-melli'));
      expect(draft.bankName, equals('بانک ملی'));
    });

    test('parses BluBank Toman withdrawal and deposit without double dividing', () {
      const withdrawSms = '''
بلوبانک
۲۵۰,۰۰۰ تومان از حسابت برداشت شد.
مانده: ۳,۴۲۰,۰۰۰ تومان
1403/08/21 11:05
''';
      final withdraw = IranianBankSmsParser.parse(
        withdrawSms,
        targetCurrency: Currency.toman,
        accounts: sampleAccounts,
      );
      expect(withdraw, isNotNull);
      expect(withdraw!.type, equals(TransactionType.expense));
      expect(withdraw.amount.minorUnits, equals(250000));
      expect(withdraw.remainingBalance?.minorUnits, equals(3420000));
      expect(withdraw.matchedAccountId, equals('acc-blu'));

      const depositSms = '''
سلام، 1,500,000 تومان به حسابت واریز شد.
موجودی فعلی: 5,200,000 تومان
بلو
''';
      final deposit = IranianBankSmsParser.parse(
        depositSms,
        targetCurrency: Currency.toman,
        accounts: sampleAccounts,
      );
      expect(deposit, isNotNull);
      expect(deposit!.type, equals(TransactionType.income));
      expect(deposit.amount.minorUnits, equals(1500000));
      expect(deposit.remainingBalance?.minorUnits, equals(5200000));
      expect(deposit.bankName, equals('بلوبانک'));
      expect(deposit.matchedAccountId, equals('acc-blu'));
    });

    test('parses Bank Saman and Bank Saderat 2-digit Jalali year & skips archived accounts', () {
      const samanSms = '''
بانک سامان
برداشت 6,000,000 ریال
کارت *3456
1403/08/18 16:22
مانده 24,000,000 ریال
''';
      final saman = IranianBankSmsParser.parse(
        samanSms,
        targetCurrency: Currency.toman,
      );
      expect(saman, isNotNull);
      expect(saman!.type, equals(TransactionType.expense));
      expect(saman.amount.minorUnits, equals(600000));
      expect(saman.accountHintDigits, equals('3456'));
      expect(saman.bankName, equals('بانک سامان'));

      const saderatSms = '''
بانک صادرات ایران
کارت: ****1122
برداشت: 950,000 ریال
تاریخ: 03/08/14 10:15
مانده: 8,000,000 ریال
''';
      final saderat = IranianBankSmsParser.parse(
        saderatSms,
        targetCurrency: Currency.toman,
        accounts: sampleAccounts,
      );
      expect(saderat, isNotNull);
      expect(saderat!.amount.minorUnits, equals(95000));
      expect(
        saderat.date,
        equals(const JalaliDate(1403, 8, 14).toDateTime(10, 15)),
      );
      expect(saderat.matchedAccountId, isNull); // acc-archived is archived
    });

    test('parses Pasargad dense SMS and Keshavarzi افزایش/کاهش موجودی accurately', () {
      const pasargadSms = '''
بانک پاسارگاد
برداشت:3,200,000ریال
حساب:205.8100.123456.1
تاریخ:1403/08/10-12:30
مانده:45,000,000ریال
''';
      final pasargad = IranianBankSmsParser.parse(
        pasargadSms,
        targetCurrency: Currency.toman,
      );
      expect(pasargad, isNotNull);
      expect(pasargad!.type, equals(TransactionType.expense));
      expect(pasargad.amount.minorUnits, equals(320000));
      expect(pasargad.remainingBalance?.minorUnits, equals(4500000));
      expect(pasargad.bankName, equals('بانک پاسارگاد'));

      const keshavarziIncome = '''
بانک کشاورزی
افزایش موجودی: 20,000,000 ریال
حساب: *5566
1403/08/05 08:00
مانده: 41,000,000 ریال
''';
      final keshInc = IranianBankSmsParser.parse(
        keshavarziIncome,
        targetCurrency: Currency.toman,
      );
      expect(keshInc, isNotNull);
      expect(keshInc!.type, equals(TransactionType.income));
      expect(keshInc.amount.minorUnits, equals(2000000));
      expect(keshInc.remainingBalance?.minorUnits, equals(4100000));

      const keshavarziExpense = '''
بانک کشاورزی
کاهش موجودی: 1,200,000 ریال
حساب: *5566
''';
      final keshExp = IranianBankSmsParser.parse(
        keshavarziExpense,
        targetCurrency: Currency.toman,
      );
      expect(keshExp, isNotNull);
      expect(keshExp!.type, equals(TransactionType.expense));
      expect(keshExp.amount.minorUnits, equals(120000));
    });

    test('parses Tejarat, Resalat, and Behpardakht refund without false PSP expense hit', () {
      const tejaratSms = '''
بانک تجارت
برداشت از کارت 5859****7788
مبلغ: 850,000 ریال
مانده: 14,150,000 ریال
''';
      final tej = IranianBankSmsParser.parse(
        tejaratSms,
        targetCurrency: Currency.toman,
      );
      expect(tej!.type, equals(TransactionType.expense));
      expect(tej.amount.minorUnits, equals(85000));
      expect(tej.accountHintDigits, equals('7788'));

      const resalatSms = '''
بانک قرض الحسنه رسالت
واریز: 10,000,000 ریال
سپرده: *9988
مانده: 15,000,000 ریال
''';
      final res = IranianBankSmsParser.parse(
        resalatSms,
        targetCurrency: Currency.toman,
      );
      expect(res!.type, equals(TransactionType.income));
      expect(res.amount.minorUnits, equals(1000000));
      expect(res.bankName, equals('بانک رسالت'));

      const refundSms = '''
به‌پرداخت ملت
عودت وجه به کارت *6542
مبلغ: 5,000,000 ریال
مانده: 20,000,000 ریال
''';
      final refund = IranianBankSmsParser.parse(
        refundSms,
        targetCurrency: Currency.toman,
        accounts: sampleAccounts,
      );
      expect(refund, isNotNull);
      expect(refund!.type, equals(TransactionType.income));
      expect(refund.amount.minorUnits, equals(500000));
      expect(refund.matchedAccountId, equals('acc-mellat'));
    });

    test('converts Toman neobank SMS to IRR when targetCurrency is IRR', () {
      const bluSms = '''
بلوبانک
250,000 تومان از حسابت برداشت شد.
مانده: 1,000,000 تومان
''';
      final draft = IranianBankSmsParser.parse(
        bluSms,
        targetCurrency: Currency.irr,
      );
      expect(draft, isNotNull);
      expect(draft!.amount.currency, equals(Currency.irr));
      expect(draft.amount.minorUnits, equals(2500000));
      expect(draft.remainingBalance?.minorUnits, equals(10000000));
    });

    test('rejects SMS containing only مانده or invalid/non-SMS strings', () {
      const balanceOnly = '''
بانک ملت
حساب: ...6542
مانده: 18,450,000 ریال
''';
      expect(IranianBankSmsParser.parse(balanceOnly), isNull);
      expect(IranianBankSmsParser.parse(''), isNull);
      expect(IranianBankSmsParser.parse('سلام وضعیت مالیم چطوره؟'), isNull);
      expect(
        IranianBankSmsParser.looksLikeBankSms('واریز به حساب ۵۰۰ هزار تومان'),
        isFalse,
      );
    });

    test('integrates cleanly with PersianNlpTransactionParser without breaking transfers', () {
      const sms = '''
بانک ملت
واریز به حساب: ...6542
مبلغ: 12,000,000 ریال
مانده: 30,000,000 ریال
''';
      final smsDraft = PersianNlpTransactionParser.parse(
        sms,
        targetCurrency: Currency.toman,
        accounts: sampleAccounts,
      );
      expect(smsDraft, isNotNull);
      expect(smsDraft!.type, equals(TransactionType.income));
      expect(smsDraft.amount.minorUnits, equals(1200000));
      expect(smsDraft.matchedAccountId, equals('acc-mellat'));

      final casualTransfer = PersianNlpTransactionParser.parse(
        'واریز به حساب ۵۰۰ هزار تومان',
        targetCurrency: Currency.toman,
        accounts: sampleAccounts,
      );
      expect(casualTransfer, isNotNull);
      expect(casualTransfer!.type, equals(TransactionType.transfer));
      expect(casualTransfer.amount.minorUnits, equals(500000));
    });
  });
}
