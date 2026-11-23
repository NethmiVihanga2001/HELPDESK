import 'package:intl/intl.dart';

final _dateTime = DateFormat('d MMM yyyy, h:mm a');
final _date = DateFormat('d MMM yyyy');

/// "23 Nov 2026, 2:05 PM" in local time.
String formatDateTime(DateTime? value) => value == null ? '-' : _dateTime.format(value);

/// "23 Nov 2026" in local time.
String formatDate(DateTime? value) => value == null ? '-' : _date.format(value);

/// "just now", "5m ago", "3h ago", "2d ago", then the date.
String formatRelative(DateTime? value, {DateTime? now}) {
  if (value == null) return '';
  final diff = (now ?? DateTime.now()).difference(value);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return _date.format(value);
}

/// "18.5 h" or "2.3 days".
String formatHours(double? hours) {
  if (hours == null) return '–';
  return hours < 24 ? '${hours.toStringAsFixed(1)} h' : '${(hours / 24).toStringAsFixed(1)} days';
}
