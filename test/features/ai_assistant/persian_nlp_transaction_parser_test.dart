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
