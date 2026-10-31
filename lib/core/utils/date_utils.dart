import 'package:intl/intl.dart';
import 'text_normalizer.dart';

/// Representation of a Solar Hijri (Jalali / Shamsi) calendar date.
class JalaliDate {
  final int year;
  final int month;
  final int day;

  const JalaliDate(this.year, this.month, this.day);

  static const List<String> persianMonthNames = [
    'فروردین', 'اردیبهشت', 'خرداد',
    'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر',
    'دی', 'بهمن', 'اسفند',
  ];

  static const List<String> englishPersianMonthNames = [
    'Farvardin', 'Ordibehesht', 'Khordad',
    'Tir', 'Mordad', 'Shahrivar',
    'Mehr', 'Aban', 'Azar',
    'Dey', 'Bahman', 'Esfand',
  ];

  String get monthName => persianMonthNames[month - 1];

  /// Converts a Gregorian DateTime to JalaliDate
  factory JalaliDate.fromDateTime(DateTime date) {
    final gYear = date.year;
    final gMonth = date.month;
    final gDay = date.day;

    final gDaysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    final jDaysInMonth = [31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 29];

    int gy = gYear - 1600;
    int gm = gMonth - 1;
    int gd = gDay - 1;

    int gDayNo = 365 * gy + ((gy + 3) ~/ 4) - ((gy + 99) ~/ 100) + ((gy + 399) ~/ 400);

    for (int i = 0; i < gm; ++i) {
      gDayNo += gDaysInMonth[i];
    }
    if (gm > 1 && ((gy % 4 == 0 && gy % 100 != 0) || (gy % 400 == 0))) {
      // leap and after Feb
      gDayNo++;
    }
    gDayNo += gd;

    int jDayNo = gDayNo - 79;

    int jNp = jDayNo ~/ 12053;
    jDayNo %= 12053;

    int jy = 979 + 33 * jNp + 4 * (jDayNo ~/ 1461);
    jDayNo %= 1461;

    if (jDayNo >= 366) {
      jy += ((jDayNo - 1) ~/ 365);
      jDayNo = (jDayNo - 1) % 365;
    }

    int jm = 0;
    for (int i = 0; i < 11 && jDayNo >= jDaysInMonth[i]; ++i) {
      jDayNo -= jDaysInMonth[i];
      jm = i + 1;
    }
    int jd = jDayNo + 1;

    return JalaliDate(jy, jm + 1, jd);
  }

  /// Converts this JalaliDate back to a Gregorian DateTime
  DateTime toDateTime([int hour = 0, int minute = 0, int second = 0]) {
    int jy = year - 979;
    int jm = month - 1;
    int jd = day - 1;

    int jDayNo = 365 * jy + (jy ~/ 33) * 8 + (((jy % 33) + 3) ~/ 4);
    for (int i = 0; i < jm; ++i) {
      jDayNo += (i < 6) ? 31 : 30;
    }
    jDayNo += jd;

    int gDayNo = jDayNo + 79;

    int gy = 1600 + 400 * (gDayNo ~/ 146097);
    gDayNo %= 146097;

    bool leap = true;
    if (gDayNo >= 36525) {
      gDayNo--;
      gy += 100 * (gDayNo ~/ 36524);
      gDayNo %= 36524;

      if (gDayNo >= 365) {
        gDayNo++;
      } else {
        leap = false;
      }
    }

    gy += 4 * (gDayNo ~/ 1461);
    gDayNo %= 1461;

    if (gDayNo >= 366) {
      leap = false;
      gDayNo--;
      gy += (gDayNo ~/ 365);
      gDayNo %= 365;
    }

    final gDaysInMonth = [
      31,
      (leap ? 29 : 28),
      31, 30, 31, 30, 31, 31, 30, 31, 30, 31
    ];

    int gm = 0;
    for (int i = 0; i < 12 && gDayNo >= gDaysInMonth[i]; ++i) {
      gDayNo -= gDaysInMonth[i];
      gm = i + 1;
    }
    int gd = gDayNo + 1;

    return DateTime(gy, gm + 1, gd, hour, minute, second);
  }

  String format({bool usePersianDigits = true}) {
    final str = '$year/${month.toString().padLeft(2, '0')}/${day.toString().padLeft(2, '0')}';
    return usePersianDigits ? TextNormalizer.toPersianDigits(str) : str;
  }

  String formatFull({bool usePersianDigits = true}) {
    final dStr = usePersianDigits ? TextNormalizer.toPersianDigits('$day') : '$day';
    final yStr = usePersianDigits ? TextNormalizer.toPersianDigits('$year') : '$year';
    return '$dStr $monthName $yStr';
  }

  @override
  String toString() => format(usePersianDigits: false);
}

class AppDateFormatter {
  static String format(DateTime date, {String locale = 'en', bool isJalali = false}) {
    if (isJalali || locale.startsWith('fa')) {
      final j = JalaliDate.fromDateTime(date);
      return j.formatFull(usePersianDigits: locale.startsWith('fa'));
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  static String formatShort(DateTime date, {String locale = 'en', bool isJalali = false}) {
    if (isJalali || locale.startsWith('fa')) {
      final j = JalaliDate.fromDateTime(date);
      return j.format(usePersianDigits: locale.startsWith('fa'));
    } else {
      return DateFormat('yyyy/MM/dd').format(date);
    }
  }

  static String formatTime(DateTime date, {String locale = 'en'}) {
    final formatted = DateFormat('HH:mm').format(date);
    return locale.startsWith('fa') ? TextNormalizer.toPersianDigits(formatted) : formatted;
  }

  static String formatRelative(DateTime date, {String locale = 'en'}) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (locale.startsWith('fa')) {
      if (difference.inSeconds < 60) return 'همین الان';
      if (difference.inMinutes < 60) {
        return '${TextNormalizer.toPersianDigits('${difference.inMinutes}')} دقیقه پیش';
      }
      if (difference.inHours < 24) {
        return '${TextNormalizer.toPersianDigits('${difference.inHours}')} ساعت پیش';
      }
      if (difference.inDays == 1) return 'دیروز';
      if (difference.inDays < 7) {
        return '${TextNormalizer.toPersianDigits('${difference.inDays}')} روز پیش';
      }
      return JalaliDate.fromDateTime(date).formatFull(usePersianDigits: true);
    } else {
      if (difference.inSeconds < 60) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays == 1) return 'Yesterday';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}
