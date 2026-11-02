import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/accounting/data/datasources/standard_chart_of_accounts_seed.dart';
import 'package:kifino/features/accounting/domain/entities/accounting_document_entity.dart';
import 'package:kifino/features/accounting/domain/entities/accounting_subject_entity.dart';
import 'package:kifino/features/accounting/domain/entities/accounting_transaction_entity.dart';
import 'package:kifino/features/accounting/domain/entities/trial_balance_entry.dart';

void main() {
  group('Accounting Domain & Equilibrium Tests', () {
    test('Standard Chart of Accounts contains all essential Iranian standard accounts', () {
      final codes = standardIranianChartOfAccounts.map((s) => s.code).toSet();

      // Key Kol accounts from FreeAmir & Iranian standard coding
      expect(codes.contains('010'), isTrue); // بانکها
      expect(codes.contains('011'), isTrue); // موجودیهای نقدی
      expect(codes.contains('011001'), isTrue); // صندوق
      expect(codes.contains('012'), isTrue); // بدهکاران تجاری
      expect(codes.contains('013'), isTrue); // اسناد دریافتنی
      expect(codes.contains('014'), isTrue); // اسناد در جریان وصول
      expect(codes.contains('015'), isTrue); // موجودی کالا
      expect(codes.contains('017'), isTrue); // دارایی‌های ثابت
      expect(codes.contains('020'), isTrue); // اسناد پرداختنی
      expect(
        codes.contains('023'),
        isTrue,
      ); // سایر حساب‌های پرداختنی و بستانکاران
      expect(codes.contains('030'), isTrue); // حقوق صاحبان سهام
      expect(codes.contains('040'), isTrue); // هزینه‌ها
      expect(codes.contains('060'), isTrue); // فروش
      expect(
        codes.contains('070'),
        isTrue,
      ); // بهای تمام شده کالای فروش رفته (COGS)

      // Permanency classification
      final bankKol = standardIranianChartOfAccounts.firstWhere(
        (s) => s.code == '010',
      );
      expect(bankKol.isPermanent, isTrue); // Balance Sheet

      final salesKol = standardIranianChartOfAccounts.firstWhere(
        (s) => s.code == '060',
      );
      expect(salesKol.isPermanent, isFalse); // Income Statement (Temporary)

      final expenseKol = standardIranianChartOfAccounts.firstWhere(
        (s) => s.code == '040',
      );
      expect(expenseKol.isPermanent, isFalse); // Income Statement (Temporary)
    });

    test('AccountingDocumentEntity correctly verifies equilibrium (Debit == Credit)', () {
      final now = DateTime.now();

      final balancedDoc = AccountingDocumentEntity(
        id: 'doc-1',
        number: 101,
        date: now,
        title: 'خرید لوازم اداری نقداً',
        transactions: [
          AccountingTransactionEntity(
            id: 'tx-1',
            documentId: 'doc-1',
            subjectId: 'sub-40',
            debit: Money.fromMinor(5000000), // 500,000 تومان بدهکار هزینه
            credit: const Money.zero(),
            description: 'هزینه ملزومات اداری',
            rowOrder: 1,
            createdAt: now,
            updatedAt: now,
          ),
          AccountingTransactionEntity(
            id: 'tx-2',
            documentId: 'doc-1',
            subjectId: 'sub-11',
            debit: const Money.zero(),
            credit: Money.fromMinor(5000000), // 500,000 تومان بستانکار صندوق
            description: 'پرداخت از صندوق',
            rowOrder: 2,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      expect(balancedDoc.totalDebit.minorUnits, equals(5000000));
      expect(balancedDoc.totalCredit.minorUnits, equals(5000000));
      expect(balancedDoc.isBalanced, isTrue);
      expect(balancedDoc.imbalanceDifference.minorUnits, equals(0));

      final imbalancedDoc = AccountingDocumentEntity(
        id: 'doc-2',
        number: 102,
        date: now,
        title: 'سند ناتراز دستی',
        transactions: [
          AccountingTransactionEntity(
            id: 'tx-3',
            documentId: 'doc-2',
            subjectId: 'sub-40',
            debit: Money.fromMinor(5000000),
            credit: const Money.zero(),
            description: 'هزینه',
            rowOrder: 1,
            createdAt: now,
            updatedAt: now,
          ),
          AccountingTransactionEntity(
            id: 'tx-4',
            documentId: 'doc-2',
            subjectId: 'sub-11',
            debit: const Money.zero(),
            credit: Money.fromMinor(3000000),
            description: 'پرداخت ناقص',
            rowOrder: 2,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      expect(imbalancedDoc.isBalanced, isFalse);
      expect(imbalancedDoc.imbalanceDifference.minorUnits, equals(2000000));
    });

    test('TrialBalanceReport verifies equilibrium across all accounts', () {
      final now = DateTime.now();

      final bankSubject = AccountingSubjectEntity(
        id: 's-1',
        code: '010',
        name: 'بانک‌ها',
        level: AccountingSubjectLevel.kol,
        createdAt: now,
        updatedAt: now,
      );

      final salesSubject = AccountingSubjectEntity(
        id: 's-2',
        code: '060',
        name: 'فروش کالا',
        level: AccountingSubjectLevel.kol,
        createdAt: now,
        updatedAt: now,
      );

      final report = TrialBalanceReport(
        entries: [
          TrialBalanceEntry(
            subject: bankSubject,
            openingDebit: const Money.zero(),
            openingCredit: const Money.zero(),
            periodDebit: Money.fromMinor(10000000),
            periodCredit: const Money.zero(),
          ),
          TrialBalanceEntry(
            subject: salesSubject,
            openingDebit: const Money.zero(),
            openingCredit: const Money.zero(),
            periodDebit: const Money.zero(),
            periodCredit: Money.fromMinor(10000000),
          ),
        ],
      );

      expect(report.sumTotalDebit.minorUnits, equals(10000000));
      expect(report.sumTotalCredit.minorUnits, equals(10000000));
      expect(report.isBalanced, isTrue);
    });

    test('AccountingSubjectEntity formattedCode formats standard Iranian 3-digit coding', () {
      final now = DateTime.now();
      final kol = AccountingSubjectEntity(
        id: '1',
        code: '011',
        name: 'موجودی‌های نقدی',
        level: AccountingSubjectLevel.kol,
        createdAt: now,
        updatedAt: now,
      );
      expect(kol.formattedCode, equals('011'));

      final moein = AccountingSubjectEntity(
        id: '2',
        code: '011001',
        name: 'صندوق',
        level: AccountingSubjectLevel.moein,
        createdAt: now,
        updatedAt: now,
      );
      expect(moein.formattedCode, equals('011/001'));

      final tafsili = AccountingSubjectEntity(
        id: '3',
        code: '011001001',
        name: 'صندوق مرکزی فروشگاه',
        level: AccountingSubjectLevel.tafsili,
        createdAt: now,
        updatedAt: now,
      );
      expect(tafsili.formattedCode, equals('011/001/001'));
      expect(
        tafsili.formattedName,
        equals('011/001/001 - صندوق مرکزی فروشگاه'),
      );
    });
  });
}
