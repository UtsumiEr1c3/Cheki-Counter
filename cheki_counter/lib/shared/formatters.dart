import 'package:intl/intl.dart';

final _dateFormat = DateFormat('yyyy-MM-dd');

/// Format a DateTime to YYYY-MM-DD string.
String formatDate(DateTime date) => _dateFormat.format(date);

/// Format an integer amount to two-decimal string (e.g. 60 -> "60.00").
String formatAmount(int amount) => amount.toStringAsFixed(2);

/// Format an integer as display string with no decimals.
String formatCount(int count) => count.toString();
