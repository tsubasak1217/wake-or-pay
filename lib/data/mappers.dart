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
    // One rule, shared with [Kakugo.fromJson]: no name reads as coins, and a
    // rate below the bound reads as 人質なし however it was labelled.
    hostage: hostageFor(hostage, rate),
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

/// The oversleep contact, stored whole as one JSON blob because it is only
/// ever read and written whole. Unreadable JSON reads as "no contact" — the
/// worst that costs is a message not sent, which is already the case today.
OversleepContact? _parseContact(String? json) {
  if (json == null || json.isEmpty) return null;
  try {
    final contact = OversleepContact.fromJson(
      (jsonDecode(json) as Map).cast<String, dynamic>(),
    );
    return contact.isUsable ? contact : null;
  } on Object {
    return null;
  }
}

/// The oversleep share, on exactly the same terms as [_parseContact].
OversleepShare? _parseShare(String? json) {
  if (json == null || json.isEmpty) return null;
  try {
    final share = OversleepShare.fromJson(
      (jsonDecode(json) as Map).cast<String, dynamic>(),
    );
    return share.isUsable ? share : null;
  } on Object {
    return null;
  }
}

/// The delay a **v6** row kept inside its contact blob. Pure.
///
/// Until v7 the trigger delay belonged to the contact; now it belongs to the
/// alarm, because the 共有 uses the same number. A row written before that move
/// has no column to read, so the number is dug back out of the JSON it was
/// written into — and only from there. Anything unreadable, absent, or not an
/// integer gives null, and the caller falls through to the default.
int? legacyTriggerMinutesIn(Map<String, dynamic>? contactJson) {
  final value = contactJson?['triggerMinutesAfterGrace'];
  return value is int ? normalizeContactTriggerMinutes(value) : null;
}

/// [legacyTriggerMinutesIn] applied to the raw column. Unreadable JSON is not
/// an error here either: it already read as "no contact" above.
int? _legacyTriggerMinutes(String? json) {
  if (json == null || json.isEmpty) return null;
  try {
    return legacyTriggerMinutesIn(
      (jsonDecode(json) as Map).cast<String, dynamic>(),
    );
  } on Object {
    return null;
  }
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
    contact: _parseContact(oversleepContact),
    share: _parseShare(oversleepShare),
    // The column first, then the v6 blob that used to hold it, then the
    // default: a row only ever reads as null once, because the writer below
    // always fills the column in.
    oversleepTriggerMinutes: normalizeContactTriggerMinutes(
      oversleepTriggerMinutes ??
          _legacyTriggerMinutes(oversleepContact) ??
          defaultContactTriggerMinutes,
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
    oversleepContact: Value(
      contact == null || !contact!.isUsable
          ? null
          : jsonEncode(contact!.toJson()),
    ),
    oversleepShare: Value(
      share == null || !share!.isUsable ? null : jsonEncode(share!.toJson()),
    ),
    // Always written, never left null: that is what retires the v6 read-through
    // above after one save.
    oversleepTriggerMinutes: Value(triggerMinutes),
  );
}

extension DiscordWebhookRowMapper on DiscordWebhookRow {
  DiscordWebhook toModel() => DiscordWebhook(
    id: id,
    url: url,
    displayName: displayName,
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
  );
}

extension DiscordWebhookMapper on DiscordWebhook {
  DiscordWebhookRowsCompanion toCompanion() => DiscordWebhookRowsCompanion(
    id: Value(id),
    url: Value(url),
    displayName: Value(displayName),
    createdAtMs: Value(createdAt.millisecondsSinceEpoch),
  );
}

extension PendingChargeRowMapper on PendingChargeRow {
  PendingCharge toModel() => PendingCharge(
    sessionId: sessionId,
    alarmId: alarmId,
    amount: amount,
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
    currency: currency,
    status: PendingChargeStatus.byName(status),
  );
}

extension PendingChargeMapper on PendingCharge {
  PendingChargeRowsCompanion toCompanion() => PendingChargeRowsCompanion(
    sessionId: Value(sessionId),
    alarmId: Value(alarmId),
    amount: Value(amount),
    createdAtMs: Value(createdAt.millisecondsSinceEpoch),
    currency: Value(currency),
    status: Value(status.name),
  );
}

extension ContactEventRowMapper on ContactEventRow {
  ContactEvent toModel() => ContactEvent(
    id: id,
    sessionId: sessionId,
    firedAt: DateTime.fromMillisecondsSinceEpoch(firedAtMs),
    contactName: contactName,
    channel: contactChannelByName(channel),
    detail: detail,
  );
}

extension ContactEventMapper on ContactEvent {
  ContactEventRowsCompanion toCompanion() => ContactEventRowsCompanion(
    id: Value(id),
    sessionId: Value(sessionId),
    firedAtMs: Value(firedAt.millisecondsSinceEpoch),
    contactName: Value(contactName),
    channel: Value(channel.name),
    detail: Value(detail),
  );
}

extension ContactBookRowMapper on ContactBookRow {
  ContactEntry toModel() => ContactEntry(
    id: id,
    name: name,
    reading: reading,
    phone: phone,
    email: email,
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
  );
}

extension ContactEntryMapper on ContactEntry {
  ContactBookRowsCompanion toCompanion() => ContactBookRowsCompanion(
    id: Value(id),
    name: Value(name),
    reading: Value(reading),
    phone: Value(phone),
    email: Value(email),
    createdAtMs: Value(createdAt.millisecondsSinceEpoch),
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
