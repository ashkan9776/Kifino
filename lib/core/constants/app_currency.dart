import 'app_constants.dart';
import '../utils/money.dart';

/// The app-wide BASE currency (the unit the whole ledger speaks).
///
/// Mirrors the user's SettingsCubit choice — blocs and calculators read this
/// instead of hardcoding a constant, and every Iranian-currency amount is
/// normalized into it before being summed (see [Money.normalizeTo]).
abstract final class AppCurrency {
  static Currency _base = Currency.fromCode(AppConstants.defaultCurrencyCode);

  static Currency get base => _base;

  static void set(Currency currency) => _base = currency;
}
