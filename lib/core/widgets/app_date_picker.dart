import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:shamsi_date/shamsi_date.dart' as shamsi;

import '../utils/persian_input.dart';

/// Single entry point for picking dates across the app (§56 date system).
///
/// When the app language is Persian this opens a full Jalali (شمسی) calendar
/// via the persian_datetime_picker package; English keeps the Gregorian
/// Material picker. Both return a normal [DateTime] to the caller.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  String? helpText,
}) async {
  final isFa = isFaLocale(context);

  // Default date bounds in Jalali span years 1300 to 1500 (approx 1921 to 2121 Gregorian).
  var first = firstDate ?? shamsi.Jalali(1300, 1, 1).toDateTime();
  var last = lastDate ?? shamsi.Jalali(1500, 12, 29).toDateTime();

  if (last.isBefore(first)) {
    last = first.add(const Duration(days: 3650));
  }

  var effectiveInitial = initialDate;
  if (effectiveInitial.isBefore(first)) {
    effectiveInitial = first;
  } else if (effectiveInitial.isAfter(last)) {
    effectiveInitial = last;
  }

  if (isFa) {
    final jInitialRaw = shamsi.Jalali.fromDateTime(effectiveInitial);
    final jFirstRaw = shamsi.Jalali.fromDateTime(first);
    final jLastRaw = shamsi.Jalali.fromDateTime(last);

    // Strip time components to prevent minute/second assertion edge cases
    var jFirst = shamsi.Jalali(jFirstRaw.year, jFirstRaw.month, jFirstRaw.day);
    var jLast = shamsi.Jalali(jLastRaw.year, jLastRaw.month, jLastRaw.day);
    var jInitial = shamsi.Jalali(
      jInitialRaw.year,
      jInitialRaw.month,
      jInitialRaw.day,
    );

    if (jLast.compareTo(jFirst) < 0) {
      jLast = jFirst;
    }
    if (jInitial.compareTo(jFirst) < 0) {
      jInitial = jFirst;
    } else if (jInitial.compareTo(jLast) > 0) {
      jInitial = jLast;
    }

    final picked = await showPersianDatePicker(
      context: context,
      initialDate: jInitial,
      firstDate: jFirst,
      lastDate: jLast,
      helpText: helpText ?? 'انتخاب تاریخ',
      confirmText: 'تأیید',
      cancelText: 'انصراف',
      locale: const Locale('fa', 'IR'),
      textDirection: TextDirection.rtl,
    );

    if (picked == null) return null;

    final gDate = picked.toDateTime();
    return DateTime(
      gDate.year,
      gDate.month,
      gDate.day,
      initialDate.hour,
      initialDate.minute,
      initialDate.second,
    );
  }

  return showDatePicker(
    context: context,
    initialDate: effectiveInitial,
    firstDate: first,
    lastDate: last,
    helpText: helpText,
  );
}
