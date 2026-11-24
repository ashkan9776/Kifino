import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/text_normalizer.dart';

/// How often a recurring rule repeats.
enum RecurrenceFrequency {
  daily('daily', 'روزانه', 'روز'),
  weekly('weekly', 'هفتگی', 'هفته'),
  monthly('monthly', 'ماهانه', 'ماه'),
  yearly('yearly', 'سالانه', 'سال');

  final String code;
  final String titleFa;

  /// Unit noun for "every N …" phrasing («هر ۲ ماه»).
  final String unitFa;

  const RecurrenceFrequency(this.code, this.titleFa, this.unitFa);

  static RecurrenceFrequency fromCode(String code) {
    for (final f in values) {
      if (f.code == code) return f;
    }
    return RecurrenceFrequency.monthly;
  }
}

/// Date math for recurring rules.
///
/// Every occurrence is computed from the START date (never from the
/// previous occurrence), so a rule on 31 Shahrivar lands on 30 Mehr and is
/// back on 31 in the next 31-day month instead of drifting to the 30th
/// forever. Months and years follow the Jalali calendar.
abstract final class Recurrence {
  /// Date of occurrence [index] (0-based) for a rule starting on [start].
  static DateTime occurrence({
    required DateTime start,
    required RecurrenceFrequency frequency,
    required int interval,
    required int index,
  }) {
    final step = interval < 1 ? 1 : interval;
    final n = index * step;
    switch (frequency) {
      case RecurrenceFrequency.daily:
        return _addDays(start, n);
      case RecurrenceFrequency.weekly:
        return _addDays(start, n * 7);
      case RecurrenceFrequency.monthly:
        return addJalaliMonths(start, n);
      case RecurrenceFrequency.yearly:
        return addJalaliMonths(start, n * 12);
    }
  }

  /// Human phrasing: «ماهانه», «هر ۲ هفته».
  static String describeFa(RecurrenceFrequency frequency, int interval) {
    if (interval <= 1) return frequency.titleFa;
    return TextNormalizer.auto('هر $interval ${frequency.unitFa}');
  }

  static DateTime _addDays(DateTime d, int days) => DateTime(
    d.year,
    d.month,
    d.day + days,
    d.hour,
    d.minute,
    d.second,
    d.millisecond,
  );
}
