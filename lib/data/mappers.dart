import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/models.dart';
import 'database.dart';

Set<int> _parseDays(String csv) =>
    csv.isEmpty ? const {} : csv.split(',').map(int.parse).toSet();

String _formatDays(Set<int> days) => (days.toList()..sort()).join(',');

Snooze? _snooze(int? intervalMinutes, int? maxCount) {
  if (intervalMinutes == null || maxCount == null) return null;
  return Snooze(
    intervalMinutes: normalizeSnoozeInterval(intervalMinutes),
    maxCount: normalizeSnoozeMaxCount(maxCount),
  );
}

Kakugo? _kakugo(
  String? hostage,
  int? rate,
  int? cap, {
  int? snoozePenalty,
  bool? snoozeResetsClock,
}) {
  if (rate == null || cap == null) return null;
  return Kakugo(
    hostage: HostageType.values.firstWhere(
      (h) => h.name == hostage,
      orElse: () => HostageType.coin,
    ),
    ratePerMinute: rate,
    cap: cap,
    // Null is a row from before stage B: snoozing was free and never stopped
    // the clock, which is exactly what these two defaults mean.
    snoozePenalty: normalizeSnoozePenalty(snoozePenalty ?? 0),
    snoozeResetsClock: snoozeResetsClock ?? false,
  );
}

/// The snooze presses of one session, stored as a JSON list of epoch millis.
/// Anything unreadable is treated as "never snoozed" rather than crashing a
/// read — the alternative is an app that cannot open its own history.
List<DateTime> _parseSnoozes(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    return [
      for (final ms in jsonDecode(json) as List)
        DateTime.fromMillisecondsSinceEpoch(ms as int),
    ];
  } on Object {
    return const [];
  }
}

String _formatSnoozes(List<DateTime> snoozes) =>
    jsonEncode([for (final t in snoozes) t.millisecondsSinceEpoch]);

extension AlarmRowMapper on AlarmRow {
  Alarm toModel() => Alarm(
    id: id,
    hour: hour,
    minute: minute,
    repeatDays: _parseDays(repeatDays),
    enabled: enabled,
    wakeCheck: WakeCheckType.values.firstWhere(
      (w) => w.name == wakeCheck,
      orElse: () => WakeCheckType.longPress,
    ),
    graceMinutes: normalizeGraceMinutes(graceMinutes),
    snooze: _snooze(snoozeIntervalMinutes, snoozeMaxCount),
    soundId: soundId,
    kakugo: _kakugo(
      kakugoHostage,
      kakugoRatePerMinute,
      kakugoCap,
      snoozePenalty: kakugoSnoozePenalty,
      snoozeResetsClock: kakugoSnoozeResetsClock,
    ),
  );
}

extension AlarmMapper on Alarm {
  AlarmRowsCompanion toCompanion() => AlarmRowsCompanion(
    id: Value(id),
    hour: Value(hour),
    minute: Value(minute),
    repeatDays: Value(_formatDays(repeatDays)),
    enabled: Value(enabled),
    wakeCheck: Value(wakeCheck.name),
    graceMinutes: Value(normalizeGraceMinutes(graceMinutes)),
    snoozeIntervalMinutes: Value(
      snooze == null ? null : normalizeSnoozeInterval(snooze!.intervalMinutes),
    ),
    snoozeMaxCount: Value(
      snooze == null ? null : normalizeSnoozeMaxCount(snooze!.maxCount),
    ),
    soundId: Value(soundId),
    kakugoHostage: Value(kakugo?.hostage.name),
    kakugoRatePerMinute: Value(kakugo?.ratePerMinute),
    kakugoCap: Value(kakugo?.cap),
    kakugoSnoozePenalty: Value(
      kakugo == null ? null : normalizeSnoozePenalty(kakugo!.snoozePenalty),
    ),
    kakugoSnoozeResetsClock: Value(kakugo?.snoozeResetsClock),
  );
}

extension AlarmSessionRowMapper on AlarmSessionRow {
  AlarmSession toModel() => AlarmSession(
    id: id,
    alarmId: alarmId,
    firedAt: DateTime.fromMillisecondsSinceEpoch(firedAtMs),
    dismissedAt: dismissedAtMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(dismissedAtMs!),
    status: SessionStatus.values.firstWhere(
      (s) => s.name == status,
      orElse: () => SessionStatus.ringing,
    ),
    loss: loss,
    kakugoSnapshot: _kakugo(
      kakugoHostage,
      kakugoRatePerMinute,
      kakugoCap,
      snoozePenalty: kakugoSnoozePenalty,
      snoozeResetsClock: kakugoSnoozeResetsClock,
    ),
    coinsAtFire: coinsAtFire,
    graceMinutes: normalizeGraceMinutes(graceMinutes),
    wakeCheckResolved: wakeCheckTypeByName(wakeCheckResolved),
    snoozes: _parseSnoozes(snoozes),
    currentRingAt: currentRingAtMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(currentRingAtMs!),
  );
}

extension AlarmSessionMapper on AlarmSession {
  AlarmSessionRowsCompanion toCompanion() => AlarmSessionRowsCompanion(
    id: Value(id),
    alarmId: Value(alarmId),
    firedAtMs: Value(firedAt.millisecondsSinceEpoch),
    dismissedAtMs: Value(dismissedAt?.millisecondsSinceEpoch),
    status: Value(status.name),
    loss: Value(loss),
    kakugoHostage: Value(kakugoSnapshot?.hostage.name),
    kakugoRatePerMinute: Value(kakugoSnapshot?.ratePerMinute),
    kakugoCap: Value(kakugoSnapshot?.cap),
    kakugoSnoozePenalty: Value(
      kakugoSnapshot == null
          ? null
          : normalizeSnoozePenalty(kakugoSnapshot!.snoozePenalty),
    ),
    kakugoSnoozeResetsClock: Value(kakugoSnapshot?.snoozeResetsClock),
    coinsAtFire: Value(coinsAtFire),
    graceMinutes: Value(normalizeGraceMinutes(graceMinutes)),
    wakeCheckResolved: Value(wakeCheckResolved?.name),
    snoozes: Value(_formatSnoozes(snoozes)),
    currentRingAtMs: Value(currentRingAt.millisecondsSinceEpoch),
  );
}
