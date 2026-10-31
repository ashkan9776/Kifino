import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_currency.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../app/router/app_router.dart';
import '../../domain/services/settings_service.dart';
import 'settings_state.dart';

/// Single source of truth for language, currency and theme preferences.
/// Persists every change immediately.
class SettingsCubit extends Cubit<SettingsState> {
  final SettingsService _service;

  SettingsCubit(this._service) : super(const SettingsState());

  /// Loads persisted preferences at startup and notifies the router so the
  /// onboarding gate works from the very first frame.
  Future<void> init() async {
    final locale = Locale(_service.loadLanguageCode());
    final currency = Currency.fromCode(_service.loadCurrencyCode());
    final themeIndex = _service.loadThemeModeIndex();
    final onboarded = _service.loadOnboardingCompleted();

    TextNormalizer.setPersianDigitsEnabled(enabled: locale.languageCode == 'fa');
    AppCurrency.set(currency);
    AppRouter.onboardingCompleted = onboarded;

    emit(state.copyWith(
      locale: locale,
      currency: currency,
      themeMode: ThemeMode.values[themeIndex.clamp(0, ThemeMode.values.length - 1)],
      onboardingCompleted: onboarded,
      loaded: true,
    ));
    AppRouter.refresh();
  }

  Future<void> setLocale(Locale locale) async {
    await _service.setLanguageCode(locale.languageCode);
    TextNormalizer.setPersianDigitsEnabled(enabled: locale.languageCode == 'fa');
    emit(state.copyWith(locale: locale));
  }

  Future<void> setCurrency(Currency currency) async {
    await _service.setCurrencyCode(currency.code);
    AppCurrency.set(currency);
    emit(state.copyWith(currency: currency));
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    await _service.setThemeModeIndex(themeMode.index);
    emit(state.copyWith(themeMode: themeMode));
  }

  /// Called by the onboarding flow: persists language/currency choice and
  /// unblocks the router gate. Does NOT refresh the router here — the caller
  /// navigates explicitly right after, which re-evaluates the redirect with
  /// the flag already set (avoids a redirect/navigation race).
  Future<void> completeOnboarding({
    required Locale locale,
    required Currency currency,
  }) async {
    await _service.setLanguageCode(locale.languageCode);
    await _service.setCurrencyCode(currency.code);
    await _service.setOnboardingCompleted(completed: true);

    TextNormalizer.setPersianDigitsEnabled(enabled: locale.languageCode == 'fa');
    AppCurrency.set(currency);
    AppRouter.onboardingCompleted = true;
    emit(state.copyWith(
      locale: locale,
      currency: currency,
      onboardingCompleted: true,
    ));
  }
}
