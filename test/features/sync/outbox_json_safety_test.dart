import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/assets/data/repositories/asset_repository_impl.dart';
import 'package:kifino/features/assets/domain/entities/asset_entity.dart';
import 'package:kifino/features/business/data/repositories/business_repository_impl.dart';
import 'package:kifino/features/business/domain/entities/contact_entity.dart';
import 'package:kifino/features/checks/data/repositories/check_repository_impl.dart';
import 'package:kifino/features/checks/domain/entities/check_entity.dart';
import 'package:kifino/features/debts/data/repositories/debt_repository_impl.dart';
import 'package:kifino/features/debts/domain/entities/debt_entity.dart';
import 'package:kifino/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:kifino/features/goals/domain/entities/goal_entity.dart';
import 'package:kifino/features/installments/data/repositories/installment_repository_impl.dart';
import 'package:kifino/features/installments/domain/entities/installment_entity.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  test('all repositories produce valid jsonEncode payloads even with quotes and newlines', () async {
    final now = DateTime.now();
    const trickyText = 'تست "کوتیشن" و \\ اسلش\nخط دوم';

    final goalRepo = GoalRepositoryImpl(db);
    await goalRepo.createGoal(
      GoalEntity(
        id: 'g-tricky',
        name: trickyText,
        targetAmount: const Money(minorUnits: 50000, currency: Currency.toman),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await goalRepo.updateGoal(
      GoalEntity(
        id: 'g-tricky',
        name: trickyText,
        targetAmount: const Money(minorUnits: 60000, currency: Currency.toman),
        createdAt: now,
        updatedAt: now,
      ),
    );

    final debtRepo = DebtRepositoryImpl(db);
    await debtRepo.createDebt(
      DebtEntity(
        id: 'd-tricky',
        contactName: trickyText,
        type: DebtType.debt,
        totalAmount: const Money(minorUnits: 100000, currency: Currency.toman),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await debtRepo.deleteDebt('d-tricky');

    final instRepo = InstallmentRepositoryImpl(db);
    await instRepo.createInstallment(
      InstallmentEntity(
        id: 'i-tricky',
        title: trickyText,
        accountId: 'acc-1',
        totalAmount: const Money(minorUnits: 200000, currency: Currency.toman),
        numberOfInstallments: 2,
        installmentAmount:
            const Money(minorUnits: 100000, currency: Currency.toman),
        startDate: now,
        nextDueDate: now.add(const Duration(days: 30)),
        createdAt: now,
        updatedAt: now,
      ),
    );

    final checkRepo = CheckRepositoryImpl(db);
    await checkRepo.createCheck(
      CheckEntity(
        id: 'ch-tricky',
        checkNumber: '123"45',
        bankName: 'ملت',
        type: CheckType.issued,
        amount: const Money(minorUnits: 300000, currency: Currency.toman),
        partyName: trickyText,
        dueDate: now.add(const Duration(days: 10)),
        createdAt: now,
        updatedAt: now,
      ),
    );

    final bizRepo = BusinessRepositoryImpl(db);
    await bizRepo.createContact(
      ContactEntity(
        id: 'c-tricky',
        name: trickyText,
        type: ContactType.customer,
        outstandingBalance: Money.zero(Currency.toman),
        createdAt: now,
        updatedAt: now,
      ),
    );

    final assetRepo = AssetRepositoryImpl(db);
    await assetRepo.createAsset(
      AssetEntity(
        id: 'a-tricky',
        name: trickyText,
        category: AssetCategory.other,
        quantity: 1,
        unit: 'عدد',
        costBasis: const Money(minorUnits: 100000, currency: Currency.toman),
        currentValue: const Money(minorUnits: 100000, currency: Currency.toman),
        purchaseDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final rows = await db.select(db.syncQueueTable).get();
    expect(rows.length, equals(8));

    // Every single row MUST parse cleanly via jsonDecode
    for (final row in rows) {
      expect(() => jsonDecode(row.payloadJson), returnsNormally);
    }

    // Check GoalRepositoryImpl uses unified 'financial_goals' on updateGoal
    final goalUpdate = rows.firstWhere(
      (r) => r.entityId == 'g-tricky' && r.operation == 'UPDATE',
    );
    expect(goalUpdate.syncEntityName, equals('financial_goals'));

    // Check DebtRepositoryImpl enqueued DELETE
    expect(
      rows.any(
        (r) =>
            r.syncEntityName == 'debts_receivables' &&
            r.entityId == 'd-tricky' &&
            r.operation == 'DELETE',
      ),
      isTrue,
    );
  });
}
