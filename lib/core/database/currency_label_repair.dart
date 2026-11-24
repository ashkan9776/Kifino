import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_logger.dart';
import '../utils/money.dart';
import 'app_database.dart';

/// One-time data repair for a labelling bug in older versions.
///
/// The create forms for debts, installments, checks and assets showed
/// «تومان» next to the amount field but saved the typed number as IRR. The
/// number is what the user meant; only the unit is wrong. With a Toman base
/// currency this relabels those rows (and the installment/check transactions
/// generated from them) as TOMAN, keeping every amount unchanged.
///
/// When the base currency is Rial the stored unit already matches what the
/// rest of the app shows, so nothing is touched. Runs once per company
/// database.
abstract final class CurrencyLabelRepair {
  static String _flagKey(String companyId) =>
      'repair_irr_form_labels_v1_$companyId';

  static Future<int> runIfNeeded({
    required AppDatabase db,
    required SharedPreferences prefs,
    required String companyId,
    required Currency base,
  }) async {
    final key = _flagKey(companyId);
    if (prefs.getBool(key) ?? false) return 0;

    var changed = 0;
    if (base == Currency.toman) {
      try {
        await db.transaction(() async {
          for (final table in const [
            'debts_receivables',
            'installments',
            'checks',
            'assets',
          ]) {
            changed += await db.customUpdate(
              "UPDATE $table SET currency = 'TOMAN' WHERE currency = 'IRR'",
            );
          }
          changed += await db.customUpdate(
            "UPDATE transactions SET currency = 'TOMAN' "
            "WHERE currency = 'IRR' AND source_type IN ('installment', 'check')",
          );
        });
      } catch (e, st) {
        // Leave the flag unset so the repair is retried next launch.
        AppLogger.error(
          'Currency label repair failed',
          error: e,
          stackTrace: st,
        );
        return 0;
      }
    }
    await prefs.setBool(key, true);
    if (changed > 0) AppLogger.info('Currency label repair: $changed rows');
    return changed;
  }
}
