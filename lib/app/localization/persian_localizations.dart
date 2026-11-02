import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';

import '../../core/utils/text_normalizer.dart';

/// Persian Material localizations that accurately formats numbers and dates
/// in Persian/Shamsi script and calendar. Supports both 'fa' and 'fa_IR'.
class AppPersianMaterialLocalizations extends PersianMaterialLocalizations {
  const AppPersianMaterialLocalizations();

  static const LocalizationsDelegate<MaterialLocalizations> delegate =
      _AppPersianMaterialLocalizationsDelegate();

  @override
  String formatDecimal(int number) =>
      TextNormalizer.toPersianDigits(number.toString());

  @override
  String formatYear(DateTime date) =>
      TextNormalizer.toPersianDigits(super.formatYear(date));

  @override
  String formatMediumDate(DateTime date) =>
      TextNormalizer.toPersianDigits(super.formatMediumDate(date));

  @override
  String formatShortMonthDay(DateTime date) =>
      TextNormalizer.toPersianDigits(super.formatShortMonthDay(date));

  @override
  String formatShortDate(DateTime date) =>
      TextNormalizer.toPersianDigits(super.formatShortDate(date));

  @override
  String formatMonthYear(DateTime date) =>
      TextNormalizer.toPersianDigits(super.formatMonthYear(date));

  @override
  String formatFullDate(DateTime date) =>
      TextNormalizer.toPersianDigits(super.formatFullDate(date));

  @override
  String formatCompactDate(DateTime date) =>
      TextNormalizer.toPersianDigits(super.formatCompactDate(date));

  @override
  String formatTimeOfDay(
    TimeOfDay timeOfDay, {
    bool alwaysUse24HourFormat = false,
  }) => TextNormalizer.toPersianDigits(
    super.formatTimeOfDay(
      timeOfDay,
      alwaysUse24HourFormat: alwaysUse24HourFormat,
    ),
  );

  @override
  String formatHour(
    TimeOfDay timeOfDay, {
    bool alwaysUse24HourFormat = false,
  }) => TextNormalizer.toPersianDigits(
    super.formatHour(timeOfDay, alwaysUse24HourFormat: alwaysUse24HourFormat),
  );

  @override
  String formatMinute(TimeOfDay timeOfDay) =>
      TextNormalizer.toPersianDigits(super.formatMinute(timeOfDay));
}

class _AppPersianMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _AppPersianMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'fa';

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    return SynchronousFuture<MaterialLocalizations>(
      const AppPersianMaterialLocalizations(),
    );
  }

  @override
  bool shouldReload(_AppPersianMaterialLocalizationsDelegate old) => false;
}

class AppPersianCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const AppPersianCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'fa';

  @override
  Future<CupertinoLocalizations> load(Locale locale) async {
    return SynchronousFuture<CupertinoLocalizations>(
      const PersianCupertinoLocalizations(),
    );
  }

  @override
  bool shouldReload(AppPersianCupertinoLocalizationsDelegate old) => false;
}
