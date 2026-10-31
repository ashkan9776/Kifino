import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/company_registry.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/features/accounting/data/repositories/accounting_repository_impl.dart';
import 'package:kifino/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:kifino/features/accounts/domain/entities/account_entity.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase-5 multi-company tests: registry persistence, per-company database
/// file naming and data isolation between two company databases.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CompanyRegistry', () {
    late SharedPreferences prefs;
    late CompanyRegistry registry;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      registry = CompanyRegistry(prefs);
    });

    test('seeds the default company on first read', () async {
      final companies = await registry.getCompanies();
      expect(companies.length, equals(1));
      expect(companies.first.id, equals(CompanyRegistry.defaultCompanyId));
    });

    test('adds, switches and removes companies', () async {
      final company = await registry.addCompany('دفتر دوم');
      expect((await registry.getCompanies()).length, equals(2));

      await registry.setActiveCompanyId(company.id);
      expect(registry.activeCompanyId, equals(company.id));

      await registry.removeCompany(company.id);
      expect((await registry.getCompanies()).length, equals(1));
      expect(registry.activeCompanyId, equals(CompanyRegistry.defaultCompanyId));
    });

    test('persists the active company across registry instances', () async {
      final company = await registry.addCompany('شرکت دوم');
      await registry.setActiveCompanyId(company.id);

      final second = CompanyRegistry(prefs); // same prefs = same storage
      expect(second.activeCompanyId, equals(company.id));
    });

    test('maps company ids to database file names', () {
      expect(
        CompanyRegistry.dbFileNameFor(CompanyRegistry.defaultCompanyId),
        equals('kifino_local.db'),
      );
      expect(
        CompanyRegistry.dbFileNameFor('12345'),
        equals('kifino_company_12345.db'),
      );
    });
  });

  group('Multi-company database isolation', () {
    test('two company databases are fully independent', () async {
      // Company A database
      final dbA = AppDatabase(NativeDatabase.memory(), 'company-a');
      final repoA = AccountRepositoryImpl(dbA);
      await repoA.createAccount(AccountEntity(
        id: 'acc-A',
        name: 'حساب شرکت الف',
        type: AccountType.bankCard,
        currency: Currency.toman,
        initialBalance: Money.fromMinor(1000000, Currency.toman),
        currentBalance: Money.fromMinor(1000000, Currency.toman),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Company B database (separate file in production, separate memory here)
      final dbB = AppDatabase(NativeDatabase.memory(), 'company-b');
      final repoB = AccountRepositoryImpl(dbB);
      final accountsB = await repoB.getAccounts();
      expect(accountsB.dataOrNull, isEmpty); // A's data must not leak into B

      // And B's data is invisible to A.
      final accountsA = await repoA.getAccounts();
      expect(accountsA.dataOrNull?.length, equals(1));
      expect(accountsA.dataOrNull!.first.id, equals('acc-A'));

      await dbA.close();
      await dbB.close();
    });

    test('fresh company database seeds its own chart of accounts', () async {
      final dbB = AppDatabase(NativeDatabase.memory(), 'company-b');
      final repoB = AccountingRepositoryImpl(dbB);

      await repoB.seedChartOfAccountsIfNotExists();
      final subjects = await repoB.getAllSubjects();
      expect(subjects, isNotEmpty); // Iranian chart seeded per company

      await dbB.close();
    });
  });
}
