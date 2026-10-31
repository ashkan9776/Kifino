import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';

/// Persists user preferences (language, currency, theme mode, onboarding flag)
/// in SharedPreferences as plain primitives. Non-sensitive data only.
class SettingsService {
  final SharedPreferences prefs;

  const SettingsService(this.prefs);

  /// ISO language code: 'fa' (default) or 'en'.
  String loadLanguageCode() =>
      prefs.getString(AppConstants.prefLanguageKey) ?? AppConstants.defaultLocale;

  /// Currency code, e.g. 'TOMAN' (default).
  String loadCurrencyCode() =>
      prefs.getString(AppConstants.prefCurrencyKey) ?? AppConstants.defaultCurrencyCode;

  /// Index into ThemeMode.values (0=system, 1=light, 2=dark).
  int loadThemeModeIndex() => int.tryParse(
        prefs.getString(AppConstants.prefThemeModeKey) ?? '',
      ) ??
      ThemeModeIndex.system;

  bool loadOnboardingCompleted() =>
      prefs.getBool(AppConstants.prefOnboardingCompletedKey) ?? false;

  Future<void> setLanguageCode(String code) =>
      prefs.setString(AppConstants.prefLanguageKey, code);

  Future<void> setCurrencyCode(String code) =>
      prefs.setString(AppConstants.prefCurrencyKey, code);

  Future<void> setThemeModeIndex(int index) =>
      prefs.setString(AppConstants.prefThemeModeKey, index.toString());

  Future<void> setOnboardingCompleted({required bool completed}) =>
      prefs.setBool(AppConstants.prefOnboardingCompletedKey, completed);
}

/// Stable indices for theme mode persistence.
abstract final class ThemeModeIndex {
  static const int system = 0;
  static const int light = 1;
  static const int dark = 2;
}
