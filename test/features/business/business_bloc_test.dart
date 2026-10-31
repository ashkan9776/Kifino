import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/features/accounting/data/repositories/accounting_repository_impl.dart';
import 'package:kifino/features/accounting/domain/services/auto_voucher_service.dart';
import 'package:kifino/features/business/data/repositories/business_repository_impl.dart';
import 'package:kifino/features/business/presentation/bloc/business_bloc.dart';
import 'package:kifino/features/business/presentation/bloc/business_event.dart';
import 'package:kifino/features/business/presentation/bloc/business_state.dart';

void main() {
  late AppDatabase db;
  late BusinessRepositoryImpl repo;
  late BusinessBloc bloc;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = BusinessRepositoryImpl(db);
    bloc = BusinessBloc(repo, AutoVoucherService(AccountingRepositoryImpl(db)));
  });

  tearDown(() async {
    await bloc.close();
    await db.close();
  });

  group('BusinessBloc Tests', () {
    test('emits [BusinessLoading, BusinessLoaded] on WatchBusinessDataStarted', () async {
      final states = <BusinessState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const WatchBusinessDataStarted());
      await Future.delayed(const Duration(milliseconds: 100));

      expect(states.isNotEmpty, isTrue);
      expect(states.first, isA<BusinessLoading>());
      expect(states.last, isA<BusinessLoaded>());

      await sub.cancel();
    });
  });
}
