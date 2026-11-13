import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/ai_assistant/domain/services/financial_context_provider.dart';
import 'package:kifino/features/ai_assistant/domain/services/persian_nlp_transaction_parser.dart';
import 'package:kifino/features/ai_assistant/domain/services/rule_based_financial_advisor.dart';
import 'package:kifino/features/transactions/domain/entities/transaction_entity.dart';

void main() {
  group('PersianNlpTransactionParser Tests', () {
    test('extracts food expense with thousand Tomans correctly', () {
      final draft = PersianNlpTransactionParser.parse(
        'خرید ناهار رستوران ۲۵۰ هزار تومان',
        targetCurrency: Currency.toman,
      );
      expect(draft, isNotNull);
      expect(draft!.type, equals(TransactionType.expense));
      // 250,000 Tomans — normalized to the TOMAN base currency
      expect(draft.amount.currency, equals(Currency.toman));
      expect(draft.amount.minorUnits, equals(250000));
      expect(draft.suggestedCategory, equals('خوراک و غذا'));
      expect(draft.description, contains('ناهار رستوران'));
    });

    test('extracts transport expense with Snapp correctly', () {
      final draft = PersianNlpTransactionParser.parse(
        'اسنپ تا شرکت ۶۵ تومن',
        targetCurrency: Currency.toman,
      );
      expect(draft, isNotNull);
      expect(draft!.type, equals(TransactionType.expense));
      // 65 (<= 500 colloquial "تومن") treated as 65,000 Tomans
      expect(draft.amount.currency, equals(Currency.toman));
      expect(draft.amount.minorUnits, equals(65000));
      expect(draft.suggestedCategory, equals('حمل و نقل'));
    });

    test('extracts income transaction with million Tomans correctly', () {
      final draft = PersianNlpTransactionParser.parse(
        'واریز حقوق شرکت ۴۵ میلیون تومان',
        targetCurrency: Currency.toman,
      );
      expect(draft, isNotNull);
      expect(draft!.type, equals(TransactionType.income));
      expect(draft.amount.currency, equals(Currency.toman));
      expect(draft.amount.minorUnits, equals(45000000));
      expect(draft.suggestedCategory, equals('حقوق و درآمد'));
    });

    test('extracts rent / bills correctly', () {
      final draft = PersianNlpTransactionParser.parse(
        'قبض برق ۱۲۰ هزار تومان',
        targetCurrency: Currency.toman,
      );
      expect(draft, isNotNull);
      expect(draft!.type, equals(TransactionType.expense));
      expect(draft.suggestedCategory, equals('قبوض و خانه'));
      expect(draft.amount.minorUnits, equals(120000));
    });

    test('CURRENCY CONSISTENCY: spoken Toman and spoken Rial produce the SAME amount', () {
      final fromToman = PersianNlpTransactionParser.parse(
        '۳۵۰ هزار تومن خرید سوپرمارکت',
        targetCurrency: Currency.toman,
      );
      final fromRial = PersianNlpTransactionParser.parse(
        '۳,۵۰۰,۰۰۰ ریال خرید سوپرمارکت',
        targetCurrency: Currency.toman,
      );
      expect(fromToman, isNotNull);
      expect(fromRial, isNotNull);
      expect(fromToman!.amount.currency, equals(Currency.toman));
      expect(fromRial!.amount.currency, equals(Currency.toman));
      expect(fromToman.amount.minorUnits, equals(fromRial.amount.minorUnits));
      expect(fromToman.amount.minorUnits, equals(350000));
    });

    test('converts spoken Rial to Toman base currency', () {
      final draft = PersianNlpTransactionParser.parse(
        'قبض برق ۱,۰۰۰,۰۰۰ ریال',
        targetCurrency: Currency.toman,
      );
      expect(draft, isNotNull);
      expect(draft!.amount.currency, equals(Currency.toman));
      // 1,000,000 Rials = 100,000 Tomans
      expect(draft.amount.minorUnits, equals(100000));
      // No colloquial inflation on an explicit ریال amount
      expect(draft.amount.minorUnits, isNot(equals(1000000)));
    });

    test('supports an IRR base target with spoken Toman', () {
      final draft = PersianNlpTransactionParser.parse(
        'اسنپ ۳۰ هزار تومن',
        targetCurrency: Currency.irr,
      );
      expect(draft, isNotNull);
      expect(draft!.amount.currency, equals(Currency.irr));
      // 30,000 Tomans = 300,000 Rials
      expect(draft.amount.minorUnits, equals(300000));
    });

    test('explicit "تومان" amount is literal (no colloquial inflation)', () {
      final draft = PersianNlpTransactionParser.parse(
        'شارژ ساختمان ۲۵۰ تومان',
        targetCurrency: Currency.toman,
      );
      expect(draft, isNotNull);
      expect(draft!.amount.currency, equals(Currency.toman));
      expect(draft.amount.minorUnits, equals(250));
      expect(draft.suggestedCategory, equals('قبوض و خانه'));
    });

    test('returns null for text with no monetary numbers', () {
      final draft = PersianNlpTransactionParser.parse('امروز هوا خیلی گرم بود');
      expect(draft, isNull);
    });

    test('فروشگاه (shop) is not misread as فروش (a sale → income)', () {
      final draft = PersianNlpTransactionParser.parse(
        '۴۵ هزار تومن خرید فروشگاه',
        targetCurrency: Currency.toman,
      );
      expect(draft, isNotNull);
      expect(draft!.type, equals(TransactionType.expense));
    });

    test('واریز به حساب detects transfer instead of income', () {
      final draft = PersianNlpTransactionParser.parse(
        'واریز به حساب ۵۰۰ هزار تومان',
        targetCurrency: Currency.toman,
      );
      expect(draft, isNotNull);
      expect(draft!.type, equals(TransactionType.transfer));
      expect(draft.amount.minorUnits, equals(500000));
    });

    test('word boundaries avoid false positives (آناناس, سودابه, جوراب, روغن مایع, سریال)', () {
      final pineapple = PersianNlpTransactionParser.parse(
        'خرید آناناس ۱۰۰ هزار تومان',
        targetCurrency: Currency.toman,
      );
      expect(pineapple!.suggestedCategory, equals('سایر هزینه‌ها'));

      final lebanon = PersianNlpTransactionParser.parse(
        'بلیت سفر لبنان ۵ میلیون تومان',
        targetCurrency: Currency.toman,
      );
      expect(lebanon!.suggestedCategory, equals('سایر هزینه‌ها'));

      final soudabeh = PersianNlpTransactionParser.parse(
        'پرداخت به سودابه ۵۰۰ هزار تومان',
        targetCurrency: Currency.toman,
      );
      expect(soudabeh!.type, equals(TransactionType.expense));

      final worn = PersianNlpTransactionParser.parse(
        'تعویض قطعات فرسوده ۳۰۰ هزار تومان',
        targetCurrency: Currency.toman,
      );
      expect(worn!.type, equals(TransactionType.expense));

      final socks = PersianNlpTransactionParser.parse(
        'خرید جوراب ۱۵۰ هزار تومان',
        targetCurrency: Currency.toman,
      );
      expect(socks!.suggestedCategory, equals('سایر هزینه‌ها'));

      final liquidOil = PersianNlpTransactionParser.parse(
        'خرید روغن مایع ۲۲۰ هزار تومان',
        targetCurrency: Currency.toman,
      );
      expect(liquidOil!.suggestedCategory, equals('خوراک و غذا'));

      final oliveOil = PersianNlpTransactionParser.parse(
        'روغن زیتون ۳۵۰ هزار تومان',
        targetCurrency: Currency.toman,
      );
      expect(oliveOil!.suggestedCategory, equals('خوراک و غذا'));

      final engineOil = PersianNlpTransactionParser.parse(
        'تعویض روغن ماشین ۴۰۰ هزار تومان',
        targetCurrency: Currency.toman,
      );
      expect(engineOil!.suggestedCategory, equals('حمل و نقل'));

      final serial = PersianNlpTransactionParser.parse(
        'خرید اشتراک سریال ۱۵۰ هزار تومان',
        targetCurrency: Currency.toman,
      );
      expect(serial!.description, contains('سریال'));
    });

    test('parses compound numeric and Persian word-number expressions', () {
      final d1 = PersianNlpTransactionParser.parse(
        '۱ میلیون و ۵۰۰ هزار تومان خرید گوشی',
        targetCurrency: Currency.toman,
      );
      expect(d1!.amount.minorUnits, equals(1500000));
      expect(d1.description, equals('خرید گوشی'));

      final d2 = PersianNlpTransactionParser.parse(
        'یک میلیون و دویست هزار تومن خرید کفش',
        targetCurrency: Currency.toman,
      );
      expect(d2!.amount.minorUnits, equals(1200000));
      expect(d2.description, equals('خرید کفش'));

      final d3 = PersianNlpTransactionParser.parse(
        '۲ و نیم میلیون تومان قسط مسکن',
        targetCurrency: Currency.toman,
      );
      expect(d3!.amount.minorUnits, equals(2500000));

      final d4 = PersianNlpTransactionParser.parse(
        'دو میلیون و نیم خرید طلا',
        targetCurrency: Currency.toman,
      );
      expect(d4!.amount.minorUnits, equals(2500000));

      final d5 = PersianNlpTransactionParser.parse(
        'بیست و پنج هزار تومان نان سنگک',
        targetCurrency: Currency.toman,
      );
      expect(d5!.amount.minorUnits, equals(25000));
      expect(d5.suggestedCategory, equals('خوراک و غذا'));

      final d6 = PersianNlpTransactionParser.parse(
        'دو میلیارد و پانصد میلیون تومان خرید آپارتمان',
        targetCurrency: Currency.toman,
      );
      expect(d6!.amount.minorUnits, equals(2500000000));
    });

    test('supports relative Persian dates دیروز and پریروز', () {
      final today = DateTime.now();
      final yesterday = PersianNlpTransactionParser.parse(
        'دیروز ۲۰۰ هزار تومان ناهار',
        targetCurrency: Currency.toman,
      );
      expect(yesterday!.amount.minorUnits, equals(200000));
      expect(
        yesterday.date.day,
        equals(today.subtract(const Duration(days: 1)).day),
      );
      expect(yesterday.description, equals('ناهار'));

      final dayBefore = PersianNlpTransactionParser.parse(
        'پریروز ۸۰ هزار تومان اسنپ',
        targetCurrency: Currency.toman,
      );
      expect(dayBefore!.amount.minorUnits, equals(80000));
      expect(
        dayBefore.date.day,
        equals(today.subtract(const Duration(days: 2)).day),
      );
    });
  });

  group('RuleBasedFinancialAdvisor Tests', () {
    final mockSummary = FinancialContextSummary(
      netWorth: const Money(minorUnits: 150000000, currency: Currency.irr),
      monthlyIncome: const Money(minorUnits: 30000000, currency: Currency.irr),
      monthlyExpense: const Money(minorUnits: 20000000, currency: Currency.irr),
      savingsRate: 33.3,
      runwayMonths: 7.5,
      overspentBudgetsCount: 0,
      totalDebts: const Money(minorUnits: 10000000, currency: Currency.irr),
      totalReceivables: const Money(
        minorUnits: 5000000,
        currency: Currency.irr,
      ),
      topSpendingCategories: const {'خوراک و غذا': 8000000, 'مسکن': 10000000},
      healthScore: 85,
    );

    test('answers runway queries in Persian', () {
      final answer = RuleBasedFinancialAdvisor.answerQuery(
        query: 'چقدر دوام می‌آورم بدون درآمد؟ تاب‌آوری مالی من چند ماهه؟',
        context: mockSummary,
        isPersian: true,
      );
      expect(answer, contains('تاب‌آوری'));
      expect(answer, contains('7.5'));
    });

    test('answers health score queries in Persian', () {
      final answer = RuleBasedFinancialAdvisor.answerQuery(
        query: 'وضعیت سلامت مالی من چطوره؟',
        context: mockSummary,
        isPersian: true,
      );
      expect(answer, contains('85'));
    });

    test('answers debt queries in Persian', () {
      final answer = RuleBasedFinancialAdvisor.answerQuery(
        query: 'چقدر بدهی دارم؟',
        context: mockSummary,
        isPersian: true,
      );
      expect(answer, contains('بدهی'));
    });
  });
}
