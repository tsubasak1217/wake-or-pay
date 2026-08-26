import 'models.dart';

/// The next wall-clock time [alarm] should ring, strictly after [from].
///
/// Pure. With no [Alarm.repeatDays] the alarm is a one shot: today if its time
/// is still ahead, otherwise tomorrow. With repeat days set, the next matching
/// weekday (1 = Monday … 7 = Sunday), scanning up to 7 days ahead.
DateTime nextFireTime(Alarm alarm, DateTime from) {
  final todayAtTime = DateTime(
    from.year,
    from.month,
    from.day,
    alarm.hour,
    alarm.minute,
  );

  if (alarm.repeatDays.isEmpty) {
    return todayAtTime.isAfter(from)
        ? todayAtTime
        : todayAtTime.add(const Duration(days: 1));
  }

  for (var offset = 0; offset <= 7; offset++) {
    final candidate = DateTime(
      from.year,
      from.month,
      from.day + offset,
      alarm.hour,
      alarm.minute,
    );
    if (candidate.isAfter(from) &&
        alarm.repeatDays.contains(candidate.weekday)) {
      return candidate;
    }
  }

  // Unreachable for a non-empty repeatDays containing valid weekdays.
  throw ArgumentError.value(
    alarm.repeatDays,
    'repeatDays',
    'contains no valid weekday (1-7)',
  );
}
