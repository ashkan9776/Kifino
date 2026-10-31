import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:kifino/features/goals/domain/entities/goal_entity.dart';

void main() {
  late AppDatabase db;
  late GoalRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = GoalRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('GoalRepositoryImpl in-memory tests', () {
    test('Creates goal and watch emits it', () async {
      final now = DateTime.now();
      final goal = GoalEntity(
        id: 'goal-1',
        name: 'سفر شمال',
        targetAmount: const Money(minorUnits: 10000000, currency: Currency.toman),
        currentAmount: const Money(minorUnits: 0, currency: Currency.toman),
        targetDate: now.add(const Duration(days: 30)),
        createdAt: now,
        updatedAt: now,
      );

      // Watch stream starts empty and emits the created goal reactively
      final emissions = <List<GoalEntity>>[];
      final sub = repository.watchGoals().listen(emissions.add);

      await pumpEventQueue();
      expect(emissions.first, isEmpty);

      final result = await repository.createGoal(goal);
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull!.id, equals('goal-1'));
      expect(result.dataOrNull!.targetAmount.minorUnits, equals(10000000));
      expect(result.dataOrNull!.status, equals(GoalStatus.active));

      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.any((l) => l.length == 1 && l.first.id == 'goal-1'), isTrue);
      expect(emissions.any((l) => l.length == 1 && l.first.name == 'سفر شمال'), isTrue);
    });

    test('Contribute adds to current amount and auto-achieves at target', () async {
      final now = DateTime.now();
      final goal = GoalEntity(
        id: 'goal-2',
        name: 'خرید لپ‌تاپ',
        targetAmount: const Money(minorUnits: 1000000, currency: Currency.toman),
        currentAmount: const Money(minorUnits: 0, currency: Currency.toman),
        createdAt: now,
        updatedAt: now,
      );

      await repository.createGoal(goal);

      // Partial contribution keeps goal active
      final partial = await repository.contributeToGoal(
        'goal-2',
        Money.fromMinor(400000, Currency.toman),
      );
      expect(partial.isSuccess, isTrue);
      expect(partial.dataOrNull!.currentAmount.minorUnits, equals(400000));
      expect(partial.dataOrNull!.status, equals(GoalStatus.active));
      expect(partial.dataOrNull!.version, equals(2));

      // Reaching the target flips status to achieved
      final finalContribution = await repository.contributeToGoal(
        'goal-2',
        Money.fromMinor(600000, Currency.toman),
      );
      expect(finalContribution.isSuccess, isTrue);
      expect(finalContribution.dataOrNull!.currentAmount.minorUnits, equals(1000000));
      expect(finalContribution.dataOrNull!.status, equals(GoalStatus.achieved));
      expect(finalContribution.dataOrNull!.progressPercent, equals(100.0));
    });

    test('Soft delete hides goal from watch', () async {
      final now = DateTime.now();
      final goal = GoalEntity(
        id: 'goal-3',
        name: 'حذف شونده',
        targetAmount: const Money(minorUnits: 5000000, currency: Currency.toman),
        currentAmount: const Money(minorUnits: 0, currency: Currency.toman),
        createdAt: now,
        updatedAt: now,
      );

      await repository.createGoal(goal);

      final before = await repository.watchGoals().first;
      expect(before.length, equals(1));

      final deleteResult = await repository.deleteGoal('goal-3');
      expect(deleteResult.isSuccess, isTrue);

      final after = await repository.watchGoals().first;
      expect(after.isEmpty, isTrue);
    });

    test('Watch goals ordered by createdAt descending', () async {
      final now = DateTime.now();
      await repository.createGoal(GoalEntity(
        id: 'goal-a',
        name: 'قدیمی',
        targetAmount: const Money(minorUnits: 100, currency: Currency.toman),
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now,
      ));
      await repository.createGoal(GoalEntity(
        id: 'goal-b',
        name: 'جدید',
        targetAmount: const Money(minorUnits: 200, currency: Currency.toman),
        createdAt: now,
        updatedAt: now,
      ));

      final goals = await repository.watchGoals().first;
      expect(goals.first.id, equals('goal-b'));
      expect(goals.last.id, equals('goal-a'));
    });
  });
}
