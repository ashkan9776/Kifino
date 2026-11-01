import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/accounting/data/datasources/standard_chart_of_accounts_seed.dart';
import 'package:kifino/features/accounting/data/repositories/accounting_repository_impl.dart';
import 'package:kifino/features/accounting/domain/entities/accounting_subject_entity.dart';
import 'package:kifino/features/accounting/domain/services/auto_voucher_service.dart';
import 'package:kifino/features/accounting/domain/services/voucher_settings_service.dart';
import 'package:kifino/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:kifino/features/accounts/domain/entities/account_entity.dart';
import 'package:kifino/features/checks/data/repositories/check_repository_impl.dart';
import 'package:kifino/features/checks/domain/entities/check_entity.dart';
import 'package:kifino/features/checks/presentation/bloc/check_bloc.dart';
import 'package:kifino/features/notifications/domain/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late CheckRepositoryImpl checkRepo;
  late AccountRepositoryImpl accountRepo;
  late AccountingRepositoryImpl accountingRepo;
  late AutoVoucherService autoVoucherService;
  late VoucherSettingsService voucherSettings;
  late CheckBloc bloc;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    checkRepo = CheckRepositoryImpl(db);
    accountRepo = AccountRepositoryImpl(db);
    accountingRepo = AccountingRepositoryImpl(db);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    voucherSettings = VoucherSettingsService(prefs);
    autoVoucherService = AutoVoucherService(
      accountingRepo,
      settingsService: voucherSettings,
    );
    bloc = CheckBloc(
      checkRepo,
      NotificationService(db: db),
      autoVoucherService,
    );

    // Seed standard chart of accounts
    for (final item in standardIranianChartOfAccounts) {
      await db
          .into(db.accountingSubjectsTable)
          .insert(
            AccountingSubjectsTableCompanion.insert(
              id: item.code,
              code: item.code,
              name: item.name,
              type: item.type.name,
              level: item.level.name,
              isPermanent: Value(item.isPermanent),
              parentId: Value(item.parentCode),
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }

    // Seed bank account
    await accountRepo.createAccount(
      AccountEntity(
        id: 'bank-acc-1',
        name: 'حساب جاری ملت',
        type: AccountType.bankCard,
        currency: Currency.irr,
        initialBalance: const Money(
          minorUnits: 10000000,
          currency: Currency.irr,
        ), // 10M
        currentBalance: const Money(
          minorUnits: 10000000,
          currency: Currency.irr,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await bloc.close();
    await db.close();
  });

  group('P0-5 Cheque Accounting Chain & Transaction Tracking', () {
    test('clearing a check creates a corresponding row in transactionsTable', () async {
      final now = DateTime.now();
      final check = CheckEntity(
        id: 'chk-t1',
        checkNumber: '887766',
        bankName: 'ملی',
        type: CheckType.received,
        amount: const Money(minorUnits: 3000000, currency: Currency.irr),
        partyName: 'خریدار تست',
        dueDate: now.add(const Duration(days: 1)),
        accountId: 'bank-acc-1',
        createdAt: now,
        updatedAt: now,
      );

      await checkRepo.createCheck(check);
      await checkRepo.updateCheckStatus('chk-t1', CheckStatus.cleared);

      // Verify transaction table has the transaction
      final txRows =
          await (db.select(db.transactionsTable)..where(
                (t) => t.accountId.equals('bank-acc-1') & t.deletedAt.isNull(),
              ))
              .get();

      expect(
        txRows,
        isNotEmpty,
        reason:
            'Cleared check must create a transaction row in transactionsTable',
      );
      expect(txRows.first.amountMinor, equals(3000000));
      expect(txRows.first.type, equals('income'));

      // If check status transitions away from cleared, transaction row must be reverted
      await checkRepo.updateCheckStatus('chk-t1', CheckStatus.bounced);
      final activeRows =
          await (db.select(db.transactionsTable)..where(
                (t) => t.accountId.equals('bank-acc-1') & t.deletedAt.isNull(),
              ))
              .get();
      expect(
        activeRows,
        isEmpty,
        reason: 'Reverting cleared status must revert/soft-delete the transaction row',
      );
    });

    test('full received cheque lifecycle preserves audit trail and keeps trial balance balanced', () async {
      final now = DateTime.now();
      final check = CheckEntity(
        id: 'chk-recv-chain',
        checkNumber: '445566',
        bankName: 'صادرات',
        type: CheckType.received,
        amount: const Money(minorUnits: 5000000, currency: Currency.irr),
        partyName: 'آقای احمدی',
        dueDate: now.add(const Duration(days: 2)),
        accountId: 'bank-acc-1',
        createdAt: now,
        updatedAt: now,
      );

      // Step 1: Register (Creation)
      bloc.add(CheckCreateSubmitted(check));
      await Future.delayed(const Duration(milliseconds: 300));

      var docs = await accountingRepo.getDocuments();
      expect(
        docs.any(
          (d) =>
              d.referenceType == 'cheque:register' &&
              d.referenceId == 'chk-recv-chain',
        ),
        isTrue,
        reason: 'Check creation must create cheque:register voucher',
      );

      // Notes receivable (013001) must have debit 5M
      var tb = await accountingRepo.getTrialBalanceReport(
        level: AccountingSubjectLevel.moein,
      );
      var notesRec = tb.entries.firstWhere((e) => e.subject.code == '013001');
      expect(notesRec.totalDebit.minorUnits, equals(5000000));
      expect(notesRec.totalCredit.minorUnits, equals(0));

      // Step 2: Transfer to bank for collection
      bloc.add(
        const CheckStatusUpdated(
          id: 'chk-recv-chain',
          status: CheckStatus.transferred,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 300));

      docs = await accountingRepo.getDocuments();
      expect(
        docs.any(
          (d) =>
              d.referenceType == 'cheque:register' &&
              d.referenceId == 'chk-recv-chain',
        ),
        isTrue,
        reason: 'Transferring check must NOT delete register voucher',
      );
      expect(
        docs.any(
          (d) =>
              d.referenceType == 'cheque:deposit' &&
              d.referenceId == 'chk-recv-chain',
        ),
        isTrue,
        reason: 'Transferring check must create cheque:deposit voucher',
      );

      tb = await accountingRepo.getTrialBalanceReport(
        level: AccountingSubjectLevel.moein,
      );
      notesRec = tb.entries.firstWhere((e) => e.subject.code == '013001');
      // Notes receivable debit 5M and credit 5M -> net ending debit is 0
      expect(notesRec.totalDebit.minorUnits, equals(5000000));
      expect(notesRec.totalCredit.minorUnits, equals(5000000));
      expect(notesRec.endingDebit.minorUnits, equals(0));

      var notesInCol = tb.entries.firstWhere((e) => e.subject.code == '014001');
      expect(notesInCol.endingDebit.minorUnits, equals(5000000));

      // Step 3: Clear check
      bloc.add(
        const CheckStatusUpdated(
          id: 'chk-recv-chain',
          status: CheckStatus.cleared,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 300));

      docs = await accountingRepo.getDocuments();
      expect(
        docs
            .where(
              (d) =>
                  d.referenceId == 'chk-recv-chain' &&
                  d.status.name == 'approved',
            )
            .length,
        equals(3),
        reason: 'All 3 vouchers (register, deposit, clear) must coexist',
      );

      tb = await accountingRepo.getTrialBalanceReport(
        level: AccountingSubjectLevel.moein,
      );
      notesInCol = tb.entries.firstWhere((e) => e.subject.code == '014001');
      // Notes in collection is now cleared to 0
      expect(notesInCol.endingDebit.minorUnits, equals(0));

      // Trial balance at Kol level must balance
      final tbKol = await accountingRepo.getTrialBalanceReport(
        level: AccountingSubjectLevel.kol,
      );
      expect(tbKol.isBalanced, isTrue);
    });

    test('full issued cheque lifecycle creates issue and clear vouchers and balances', () async {
      final now = DateTime.now();
      final check = CheckEntity(
        id: 'chk-issue-chain',
        checkNumber: '991122',
        bankName: 'ملت',
        type: CheckType.issued,
        amount: const Money(minorUnits: 2000000, currency: Currency.irr),
        partyName: 'تأمین‌کننده پارس',
        dueDate: now.add(const Duration(days: 3)),
        accountId: 'bank-acc-1',
        createdAt: now,
        updatedAt: now,
      );

      // Step 1: Issue
      bloc.add(CheckCreateSubmitted(check));
      await Future.delayed(const Duration(milliseconds: 300));

      var docs = await accountingRepo.getDocuments();
      expect(
        docs.any(
          (d) =>
              d.referenceType == 'cheque:issue' &&
              d.referenceId == 'chk-issue-chain',
        ),
        isTrue,
        reason: 'Issuing check must create cheque:issue voucher',
      );

      var tb = await accountingRepo.getTrialBalanceReport(
        level: AccountingSubjectLevel.moein,
      );
      var notesPayable = tb.entries.firstWhere(
        (e) => e.subject.code == '020001',
      );
      expect(notesPayable.endingCredit.minorUnits, equals(2000000));

      // Step 2: Clear
      bloc.add(
        const CheckStatusUpdated(
          id: 'chk-issue-chain',
          status: CheckStatus.cleared,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 300));

      docs = await accountingRepo.getDocuments();
      expect(
        docs
            .where(
              (d) =>
                  d.referenceId == 'chk-issue-chain' &&
                  d.status.name == 'approved',
            )
            .length,
        equals(2),
        reason: 'Both issue and clear vouchers must exist',
      );

      tb = await accountingRepo.getTrialBalanceReport(
        level: AccountingSubjectLevel.moein,
      );
      notesPayable = tb.entries.firstWhere((e) => e.subject.code == '020001');
      expect(
        notesPayable.endingCredit.minorUnits,
        equals(0),
        reason: 'Notes payable settled to zero',
      );

      final tbKol = await accountingRepo.getTrialBalanceReport(
        level: AccountingSubjectLevel.kol,
      );
      expect(tbKol.isBalanced, isTrue);
    });

    test('validates accounts before creating cheque voucher and throws clear error if subject missing', () async {
      final now = DateTime.now();
      final check = CheckEntity(
        id: 'chk-invalid-sub',
        checkNumber: '112233',
        bankName: 'ملی',
        type: CheckType.received,
        amount: const Money(minorUnits: 1000000, currency: Currency.irr),
        partyName: 'ناشناس',
        dueDate: now,
        createdAt: now,
        updatedAt: now,
      );

      // Point notesReceivableCode to a non-existent subject
      await voucherSettings.save(
        voucherSettings.load().copyWith(notesReceivableCode: '999999'),
      );

      expect(
        autoVoucherService.generateChequeVoucher(check, 'register'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('سرفصل اسناد دریافتنی'),
          ),
        ),
      );
    });
  });
}
