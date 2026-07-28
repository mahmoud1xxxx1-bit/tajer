import 'package:intl/intl.dart';

class AppDateFormatter {
  static String format(DateTime date) {
    // Format: 15-08-2023 | 02:30 PM
    return DateFormat('yyyy/MM/dd | hh:mm a').format(date);
  }
}
