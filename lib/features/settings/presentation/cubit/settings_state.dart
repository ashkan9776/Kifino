import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';

/// App-wide user preferences. Loaded once at startup and re-emitted on change.
class SettingsState extends Equatable {
  final Locale locale;
  final Currency currency;
  final ThemeMode themeMode;
  final bool onboardingCompleted;
  final bool loaded;

  const SettingsState({
    this.locale = const Locale('fa'),
    this.currency = Currency.toman,
    this.themeMode = ThemeMode.system,
    this.onboardingCompleted = false,
    this.loaded = false,
  });

  SettingsState copyWith({
    Locale? locale,
    Currency? currency,
    ThemeMode? themeMode,
    bool? onboardingCompleted,
    bool? loaded,
  }) {
    return SettingsState(
      locale: locale ?? this.locale,
      currency: currency ?? this.currency,
      themeMode: themeMode ?? this.themeMode,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      loaded: loaded ?? this.loaded,
    );
  }

  @override
  List<Object?> get props => [
    locale,
    currency,
    themeMode,
    onboardingCompleted,
    loaded,
  ];
}
