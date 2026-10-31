import 'package:bloc_test/bloc_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/budgets/data/repositories/budget_repository_impl.dart';
import 'package:kifino/features/budgets/domain/entities/budget_entity.dart';
import 'package:kifino/features/budgets/presentation/bloc/budget_bloc.dart';

void main() {
  late AppDatabase db;
  late BudgetRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = BudgetRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('BudgetBloc Tests', () {
    blocTest<BudgetBloc, BudgetState>(
      'emits [BudgetLoading, BudgetLoaded] on WatchBudgetsStarted',
      build: () => BudgetBloc(repository),
      act: (bloc) => bloc.add(const WatchBudgetsStarted()),
      expect: () => [
        isA<BudgetLoading>(),
        isA<BudgetLoaded>(),
      ],
    );

    blocTest<BudgetBloc, BudgetState>(
      'emits updated BudgetLoaded with calculated health metrics when budget is created',
      build: () => BudgetBloc(repository),
      act: (bloc) async {
        bloc.add(const WatchBudgetsStarted());
        await Future.delayed(const Duration(milliseconds: 30));
        final now = DateTime.now();
        bloc.add(
          BudgetCreateSubmitted(
            BudgetEntity(
              id: 'b-new',
              name: 'سفر',
              amountLimit: const Money(minorUnits: 10000000, currency: Currency.irr),
              amountSpent: const Money(minorUnits: 5000000, currency: Currency.irr),
              startDate: now.subtract(const Duration(days: 1)),
              endDate: now.add(const Duration(days: 30)),
              createdAt: now,
              updatedAt: now,
            ),
          ),
        );
      },
      wait: const Duration(milliseconds: 200),
      expect: () => [
        isA<BudgetLoading>(),
        isA<BudgetLoaded>(),
        isA<BudgetLoaded>(),
      ],
      verify: (bloc) {
        final state = bloc.state as BudgetLoaded;
        expect(state.budgets.length, equals(1));
        expect(state.health.totalBudgets, equals(1));
      },
    );
  });
}
