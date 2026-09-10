import 'package:intl/intl.dart';

/// Day labels for conversation separators, in WhatsApp's wording.
///
/// Recent days are named rather than dated — "Today", "Yesterday", then the
/// weekday for the rest of the past week — because that is how people actually
/// place a conversation in time. Anything older falls back to a date.
String chatDateLabel(DateTime when, {DateTime? now, String? locale}) {
  final today = _dayOf(now ?? DateTime.now());
  final day = _dayOf(when);
  final difference = today.difference(day).inDays;

  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';

  // Within the last week, the weekday alone is unambiguous and reads faster
  // than a date.
  if (difference < 7) return DateFormat.EEEE(locale).format(day);

  // Same year: the year would be noise on every separator.
  if (day.year == today.year) return DateFormat.MMMd(locale).format(day);

  return DateFormat.yMMMd(locale).format(day);
}

/// True when the two timestamps fall on different calendar days, i.e. a
/// separator belongs between them.
bool isNewDay(DateTime? previous, DateTime current) {
  if (previous == null) return true;

  return _dayOf(previous) != _dayOf(current);
}

DateTime _dayOf(DateTime value) {
  final local = value.toLocal();

  return DateTime(local.year, local.month, local.day);
}
