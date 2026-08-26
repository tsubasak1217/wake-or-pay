import 'package:drift/drift.dart';

import '../domain/models.dart';
import 'database.dart';

Set<int> _parseDays(String csv) =>
    csv.isEmpty ? const {} : csv.split(',').map(int.parse).toSet();

String _formatDays(Set<int> days) => (days.toList()..sort()).join(',');

Kakugo? _kakugo(String? hostage, int? rate, int? cap) {
  if (rate == null || cap == null) return null;
  return Kakugo(
    hostage: HostageType.values.firstWhere(
      (h) => h.name == hostage,
      orElse: () => HostageType.coin,
    ),
    ratePerMinute: rate,
    cap: cap,
  );
}

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
    kakugo: _kakugo(kakugoHostage, kakugoRatePerMinute, kakugoCap),
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
    kakugoHostage: Value(kakugo?.hostage.name),
    kakugoRatePerMinute: Value(kakugo?.ratePerMinute),
    kakugoCap: Value(kakugo?.cap),
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
    kakugoSnapshot: _kakugo(kakugoHostage, kakugoRatePerMinute, kakugoCap),
    coinsAtFire: coinsAtFire,
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
    coinsAtFire: Value(coinsAtFire),
  );
}
