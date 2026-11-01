import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/features/accounting/data/repositories/accounting_repository_impl.dart';
import 'package:kifino/features/accounting/domain/services/auto_voucher_service.dart';
import 'package:kifino/features/accounting/domain/services/voucher_settings_service.dart';
import 'package:kifino/features/checks/data/repositories/check_repository_impl.dart';
import 'package:kifino/features/checks/domain/entities/check_entity.dart';
import 'package:kifino/features/checks/presentation/bloc/check_bloc.dart';
import 'package:kifino/features/notifications/domain/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression suite for the check status-change bug (2026-11-01): the status
/// menu popped its sheet before dispatching, so the event never reached the
/// bloc. These tests pin the bloc path: CheckStatusUpdated must actually
/// update the row for EVERY target status (bounced/cancelled/transferred/
/// cleared/pending) and refresh the watched state.
void main() {
  late AppDatabase db;
  late CheckRepositoryImpl repo;
  late CheckBloc bloc;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = CheckRepositoryImpl(db);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    bloc = CheckBloc(
      repo,
      NotificationService(db: db),
      AutoVoucherService(
        AccountingRepositoryImpl(db),
        settingsService: VoucherSettingsService(prefs),
      ),
    );

    await db.into(db.checksTable).insertOnConflictUpdate(
      ChecksTableCompanion.insert(
        id: 'ch-1',
        checkNumber: '123',
        bankName: 'ملت',
        type: 'received',
        amountMinor: 5000000,
        currency: 'TOMAN',
        partyName: 'مشتری الف',
        dueDate: DateTime(2026, 3, 1).millisecondsSinceEpoch,
        status: 'pending',
        createdAt: DateTime(2026, 1, 1).millisecondsSinceEpoch,
        updatedAt: DateTime(2026, 1, 1).millisecondsSinceEpoch,
      ),
    );
  });

  tearDown(() async {
    await bloc.close();
    await db.close();
  });

  Future<String> statusOf(String id) async {
    final row = await (db.select(db.checksTable)..where((t) => t.id.equals(id)))
        .getSingle();
    return row.status;
  }

  test('WatchChecksStarted emits CheckLoaded with the seeded check', () async {
    final states = <CheckState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const WatchChecksStarted());
    await Future.delayed(const Duration(milliseconds: 200));

    await sub.cancel();
    final loaded = states.whereType<CheckLoaded>().last;
    expect(loaded.checks.length, equals(1));
    expect(loaded.checks.first.status, equals(CheckStatus.pending));
  });

  test('status change to bounced actually persists (the reported bug)', () async {
    bloc.add(const WatchChecksStarted());
    await Future.delayed(const Duration(milliseconds: 200));

    bloc.add(const CheckStatusUpdated(id: 'ch-1', status: CheckStatus.bounced));
    await Future.delayed(const Duration(milliseconds: 300));

    expect(await statusOf('ch-1'), equals('bounced'));
  });

  test('status change to cancelled persists', () async {
    bloc.add(const WatchChecksStarted());
    await Future.delayed(const Duration(milliseconds: 200));

    bloc.add(const CheckStatusUpdated(id: 'ch-1', status: CheckStatus.cancelled));
    await Future.delayed(const Duration(milliseconds: 300));

    expect(await statusOf('ch-1'), equals('cancelled'));
  });

  test('status change to transferred persists', () async {
    bloc.add(const WatchChecksStarted());
    await Future.delayed(const Duration(milliseconds: 200));

    bloc.add(const CheckStatusUpdated(id: 'ch-1', status: CheckStatus.transferred));
    await Future.delayed(const Duration(milliseconds: 300));

    expect(await statusOf('ch-1'), equals('transferred'));
  });

  test('clearing then correcting back to pending round-trips', () async {
    bloc.add(const WatchChecksStarted());
    await Future.delayed(const Duration(milliseconds: 200));

    bloc.add(const CheckStatusUpdated(id: 'ch-1', status: CheckStatus.cleared));
    await Future.delayed(const Duration(milliseconds: 300));
    expect(await statusOf('ch-1'), equals('cleared'));

    bloc.add(const CheckStatusUpdated(id: 'ch-1', status: CheckStatus.pending));
    await Future.delayed(const Duration(milliseconds: 300));
    expect(await statusOf('ch-1'), equals('pending'));
  });

  test('watched state reflects the new status after the event', () async {
    final states = <CheckState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const WatchChecksStarted());
    await Future.delayed(const Duration(milliseconds: 200));

    bloc.add(const CheckStatusUpdated(id: 'ch-1', status: CheckStatus.bounced));
    await Future.delayed(const Duration(milliseconds: 400));

    await sub.cancel();
    final loaded = states.whereType<CheckLoaded>().last;
    expect(loaded.checks.first.status, equals(CheckStatus.bounced));
  });
}
