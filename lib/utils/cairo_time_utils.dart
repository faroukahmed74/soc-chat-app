import 'package:intl/intl.dart';

class CairoTimeUtils {
  static const Duration _utcOffset = Duration(hours: 2);

  static DateTime toCairo(DateTime? dateTime) {
    if (dateTime == null) return DateTime.now().toUtc().add(_utcOffset);
    final utc = dateTime.toUtc();
    return utc.add(_utcOffset);
  }

  static DateTime now() {
    return DateTime.now().toUtc().add(_utcOffset);
  }

  static String format(DateTime? dateTime, {String pattern = 'yyyy-MM-dd HH:mm'}) {
    final cairo = toCairo(dateTime);
    return DateFormat(pattern).format(cairo);
  }

  static Duration differenceFromNow(DateTime? dateTime) {
    final cairo = toCairo(dateTime);
    return now().difference(cairo);
  }
}

