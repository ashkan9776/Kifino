import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:shamsi_date/shamsi_date.dart' as shamsi;

import '../utils/date_utils.dart';
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
}) {
  final isFa = isFaLocale(context);
  final first = firstDate ?? DateTime(1300);
  final last = lastDate ?? DateTime(1500);

  if (isFa) {
    return showPersianDatePicker(
      context: context,
      initialDate: JalaliDate.fromDateTime(initialDate).toShamsi(),
      firstDate: JalaliDate.fromDateTime(first).toShamsi(),
      lastDate: JalaliDate.fromDateTime(last).toShamsi(),
      helpText: helpText,
    ).then((picked) => picked?.toDateTime());
  }

  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: first,
    lastDate: last,
    helpText: helpText,
  );
}


/// Bridges between our JalaliDate wrapper and the picker's shamsi_date types.
extension JalaliDateToShamsi on JalaliDate {
  shamsi.Jalali toShamsi() => shamsi.Jalali(year, month, day);
}

extension ShamsiToDateTime on shamsi.Jalali {
  DateTime toDateTime() => DateTime(year, month, day);
}
