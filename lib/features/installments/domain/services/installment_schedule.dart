import '../../../../core/utils/date_utils.dart';

/// Due-date math for installment plans.
///
/// Intervals that are a whole number of 30-day blocks (30, 60, 90, …) are
/// treated as Jalali calendar months, so a loan due on the 5th of every month
/// stays on the 5th instead of drifting ~5 days per year. Any other interval
/// (e.g. 7 or 14) is an exact number of days.
class InstallmentSchedule {
  const InstallmentSchedule._();

  static bool isMonthly(int intervalDays) =>
      intervalDays > 0 && intervalDays % 30 == 0;

  /// Moves [from] by [steps] intervals (negative steps go back in time).
  static DateTime step(DateTime from, int intervalDays, int steps) {
    if (steps == 0) return from;
    if (isMonthly(intervalDays)) {
      return addJalaliMonths(from, steps * (intervalDays ~/ 30));
    }
    return DateTime(
      from.year,
      from.month,
      from.day + steps * intervalDays,
      from.hour,
      from.minute,
      from.second,
      from.millisecond,
    );
  }

  /// Due date of installment number [index] (1-based) of a plan whose first
  /// installment is due on [firstDue].
  static DateTime dueDateFor({
    required DateTime firstDue,
    required int intervalDays,
    required int index,
  }) => step(firstDue, intervalDays, index - 1);

  /// Recovers the first due date for plans created before it was stored:
  /// the next due date is installment `paidCount + 1`.
  static DateTime inferFirstDue({
    required DateTime nextDue,
    required int intervalDays,
    required int paidCount,
  }) => step(nextDue, intervalDays, -paidCount);
}
