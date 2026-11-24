import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/database/currency_label_repair.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  Future<void> seed() async {
    await db
        .into(db.checksTable)
        .insert(
          ChecksTableCompanion.insert(
            id: 'chk',
            checkNumber: '1',
            bankName: 'ملت',
            type: 'received',
            amountMinor: 1000000, // typed next to a «تومان» label
            currency: 'IRR',
            partyName: 'علی',
            dueDate: 1,
            status: 'pending',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    Future<void> tx(String id, String? source) => db
        .into(db.transactionsTable)
        .insert(
          TransactionsTableCompanion.insert(
            id: id,
            accountId: 'acc',
            type: 'income',
            amountMinor: 1000000,
            currency: 'IRR',
            transactionDate: 1,
            description: id,
            sourceType: Value(source),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await tx('cheque_tx_chk', 'check');
    await tx('sms-tx', null); // a genuine Rial amount parsed from an SMS
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    await seed();
  });
  tearDown(() => db.close());

  test(
    'Toman base: relabels form rows and their generated transactions',
    () async {
      final changed = await CurrencyLabelRepair.runIfNeeded(
        db: db,
        prefs: prefs,
        companyId: 'default',
        base: Currency.toman,
      );

      expect(changed, 2);
      final check = await db.select(db.checksTable).getSingle();
      expect(check.currency, 'TOMAN');
      expect(check.amountMinor, 1000000); // the number is kept as typed
      final txs = {
        for (final t in await db.select(db.transactionsTable).get()) t.id: t,
      };
      expect(txs['cheque_tx_chk']!.currency, 'TOMAN');
      expect(txs['sms-tx']!.currency, 'IRR'); // user-entered Rial untouched
    },
  );

  test('runs once per company', () async {
    await CurrencyLabelRepair.runIfNeeded(
      db: db,
      prefs: prefs,
      companyId: 'default',
      base: Currency.toman,
    );
    // A Rial row created afterwards (e.g. restored) is not touched again.
    await (db.update(db.checksTable))
        .write(const ChecksTableCompanion(currency: Value('IRR')));
    final again = await CurrencyLabelRepair.runIfNeeded(
      db: db,
      prefs: prefs,
      companyId: 'default',
      base: Currency.toman,
    );
    expect(again, 0);
    expect((await db.select(db.checksTable).getSingle()).currency, 'IRR');
  });

  test('Rial base: nothing changes', () async {
    final changed = await CurrencyLabelRepair.runIfNeeded(
      db: db,
      prefs: prefs,
      companyId: 'default',
      base: Currency.irr,
    );
    expect(changed, 0);
    expect((await db.select(db.checksTable).getSingle()).currency, 'IRR');
  });
}
