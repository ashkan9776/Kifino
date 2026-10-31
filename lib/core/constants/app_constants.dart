class AppConstants {
  static const String appName = 'Kifino';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Your Financial Operating System';

  // Storage Keys
  static const String prefLanguageKey = 'pref_language';
  static const String prefCurrencyKey = 'pref_currency';
  static const String prefThemeModeKey = 'pref_theme_mode';
  static const String prefUseJalaliKey = 'pref_use_jalali';
  static const String prefBiometricEnabledKey = 'pref_biometric_enabled';
  static const String prefPinHashKey = 'pref_pin_hash';
  static const String prefOnboardingCompletedKey = 'pref_onboarding_completed';

  // Security
  static const int minPinLength = 4;
  static const int maxPinLength = 6;
  static const int pinLockoutSeconds = 30;

  // Defaults
  static const String defaultCurrencyCode = 'TOMAN';
  static const String defaultLocale = 'fa';

  // Database
  static const String databaseName = 'kifino_local.db';
  static const int databaseVersion = 4;

  // Sync
  static const int defaultSyncIntervalMinutes = 15;
  static const int maxSyncRetries = 5;
}
