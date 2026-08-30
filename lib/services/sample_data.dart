import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../data/repositories/alarm_session_repository.dart';
import '../data/repositories/contact_event_repository.dart';
import '../data/repositories/pending_charge_repository.dart';
import '../domain/models.dart';

/// Every row this generator writes starts with this, and nothing else in the
/// app ever writes an id that does. That one property is what makes 削除
/// exact: the sweep is 「id が sample- で始まる行」, not 「最近の行」, so a real
/// morning can never be caught by it.
const sampleIdPrefix = 'sample-';

/// The alarm the sample sessions claim to belong to. No `AlarmRow` is written
/// for it — the charts read sessions, not alarms, and inventing an alarm the
/// user never made would put a row in their alarm list.
const sampleAlarmId = '${sampleIdPrefix}alarm';

/// How far back [SampleDataGenerator] reaches: the last twelve months,
/// counting today.
const sampleDays = 365;

/// The seed used when nobody names one. Fixed, so 「作成」 twice in a row hands
/// back the same twelve months rather than a different history each time.
const defaultSampleSeed = 20260830;

/// One generated history: what would be written, and nothing written yet.
@immutable
class SampleData {
  const SampleData({
    required this.sessions,
    required this.charges,
    required this.events,
  });

  final List<AlarmSession> sessions;
  final List<PendingCharge> charges;
  final List<ContactEvent> events;

  /// What the SnackBar counts — every row that would land in a repository.
  int get rowCount => sessions.length + charges.length + events.length;

  @override
  String toString() =>
      'SampleData(${sessions.length} sessions, ${charges.length} charges, '
      '${events.length} events)';
}

/// Makes up twelve months of mornings.
///
/// **Pure**: same seed and same `now` ⇒ byte-identical output, which is what
/// lets a test pin it and what makes 作成 idempotent when combined with the
/// delete-first rule in [SampleDataService.generate]. Nothing here touches a
/// repository, a clock, or `Random()` without a seed.
class SampleDataGenerator {
  const SampleDataGenerator({this.seed = defaultSampleSeed});

  final int seed;

  SampleData generate(DateTime now) {
    final random = math.Random(seed);
    final sessions = <AlarmSession>[];
    final charges = <PendingCharge>[];
    final events = <ContactEvent>[];

    final today = DateTime(now.year, now.month, now.day);

    for (var back = sampleDays - 1; back >= 0; back--) {
      // Built by subtracting from the day-of-month rather than by subtracting
      // a Duration, so a DST change cannot slide a morning onto the day
      // before it.
      final day = DateTime(today.year, today.month, today.day - back);

      // ~15% of days have no ring at all: a history with no gaps in it does
      // not exercise the 「記録なし」 column the chart has to draw.
      if (random.nextDouble() < 0.15) continue;

      // A few days ring twice — the chart's "failed wins over success" rule
      // only has anything to chew on when some day has two outcomes.
      final rings = random.nextDouble() < 0.05 ? 2 : 1;

      for (var n = 1; n <= rings; n++) {
        final built = _session(random, day, n, secondRing: n > 1);
        sessions.add(built);
        final charge = _chargeFor(built);
        if (charge != null) charges.add(charge);
        events.addAll(_eventsFor(random, built));
      }
    }

    return SampleData(sessions: sessions, charges: charges, events: events);
  }

  AlarmSession _session(
    math.Random random,
    DateTime day,
    int index, {
    required bool secondRing,
  }) {
    final firedAt = _fireTime(random, day, secondRing: secondRing);
    final failed = random.nextDouble() < 0.25;

    final overslept = failed
        ? 6 + random.nextInt(65) // 6..70 minutes
        : 1 + random.nextInt(4); // 1..4 minutes
    final dismissedAt = firedAt.add(Duration(minutes: overslept));

    final snoozes = <DateTime>[];
    if (failed && random.nextDouble() < 0.3) {
      final presses = 1 + random.nextInt(3);
      for (var i = 1; i <= presses; i++) {
        // Spread evenly through the oversleep so the presses always sit
        // between the ring and the dismissal, whatever `overslept` came out at.
        snoozes.add(
          firedAt.add(Duration(minutes: (overslept * i) ~/ (presses + 1))),
        );
      }
    }

    final hostage = _hostage(random);
    final graceMinutes = 1 + random.nextInt(3); // 1..3
    final rate = 10 + random.nextInt(91); // 10..100
    final cap = 1000 + random.nextInt(4001); // 1000..5000
    final coinsAtFire = 500 + random.nextInt(9501); // 500..10000

    final kakugo = Kakugo(
      hostage: hostage,
      // A pledge with nothing at stake is stored with a rate under
      // [minKakugoRate] — that is what `hostageFor` reads 人質なし back off, so
      // writing 10 here would make the row load as a コイン pledge.
      ratePerMinute: hostage == HostageType.none ? 0 : rate,
      cap: cap,
      snoozePenalty: 0,
      snoozeResetsClock: false,
    );

    final loss = failed
        ? _loss(
            hostage: hostage,
            overslept: overslept,
            graceMinutes: graceMinutes,
            rate: rate,
            cap: cap,
            coinsAtFire: coinsAtFire,
          )
        : 0;

    return AlarmSession(
      id: '$sampleIdPrefix${_ymd(day)}-$index',
      alarmId: sampleAlarmId,
      firedAt: firedAt,
      dismissedAt: dismissedAt,
      status: failed ? SessionStatus.failed : SessionStatus.success,
      loss: loss,
      kakugoSnapshot: kakugo,
      coinsAtFire: coinsAtFire,
      graceMinutes: graceMinutes,
      snoozes: snoozes,
      currentRingAt: snoozes.isEmpty ? firedAt : snoozes.last,
    );
  }

  /// Somewhere between 06:00 and 08:30, drifting later through the winter.
  ///
  /// The seasonal term peaks in mid-January and bottoms in mid-July, so the
  /// 起床時間の遷移 line has an actual shape to draw instead of a flat band of
  /// noise.
  DateTime _fireTime(
    math.Random random,
    DateTime day, {
    required bool secondRing,
  }) {
    final dayOfYear = day.difference(DateTime(day.year)).inDays;
    final seasonal = 40 * math.cos(2 * math.pi * (dayOfYear - 15) / 365);
    final noise = random.nextDouble() * 50 - 25;
    final minutes = (390 + seasonal + noise).round().clamp(
      6 * 60,
      8 * 60 + 30,
    );
    // A second ring is the backup alarm, half an hour behind the first — still
    // inside the window, because the window is what the chart's axis is.
    final withBackup = secondRing ? math.min(minutes + 30, 8 * 60 + 30)
        : minutes;
    return DateTime(day.year, day.month, day.day, 0, withBackup);
  }

  HostageType _hostage(math.Random random) {
    final roll = random.nextDouble();
    if (roll < 0.6) return HostageType.coin;
    if (roll < 0.9) return HostageType.card;
    return HostageType.none;
  }

  /// The same arithmetic a real settle does: minutes past the grace window,
  /// times the rate, capped — and never more than the balance the ring froze.
  int _loss({
    required HostageType hostage,
    required int overslept,
    required int graceMinutes,
    required int rate,
    required int cap,
    required int coinsAtFire,
  }) {
    if (!hostage.burns) return 0;
    final billable = overslept - graceMinutes;
    if (billable <= 0) return 0;
    final raw = billable * rate;
    // The card is billed whatever the pledge allows; coins can only ever burn
    // what was actually there when the alarm fired.
    final ceiling = hostage == HostageType.card
        ? cap
        : math.min(cap, coinsAtFire);
    return raw.clamp(0, ceiling);
  }

  /// The 請求台帳 row for a カード人質 ring that cost something. Null otherwise —
  /// a コイン ring never writes one, and that absence is what
  /// `activity_stats` reads the pocket off.
  PendingCharge? _chargeFor(AlarmSession session) {
    if (session.loss <= 0) return null;
    if (session.kakugoSnapshot?.hostage != HostageType.card) return null;
    return PendingCharge(
      sessionId: session.id,
      alarmId: session.alarmId,
      amount: session.loss,
      createdAt: session.dismissedAt ?? session.firedAt,
    );
  }

  static const _channels = [
    (ContactChannel.sms, 'サンプル 太郎'),
    (ContactChannel.email, 'サンプル 花子'),
    (ContactChannel.discord, 'Discord 1件'),
  ];

  List<ContactEvent> _eventsFor(math.Random random, AlarmSession session) {
    if (session.status != SessionStatus.failed) return const [];
    if (random.nextDouble() >= 0.5) return const [];

    final count = 1 + random.nextInt(2);
    final base = session.dismissedAt ?? session.firedAt;
    return [
      for (var i = 0; i < count; i++)
        () {
          final (channel, name) = _channels[random.nextInt(_channels.length)];
          final trigger = random.nextInt(16); // 0..15 minutes
          final ok = random.nextDouble() < 0.7;
          return ContactEvent(
            id: '${session.id}-contact-${i + 1}',
            sessionId: session.id,
            firedAt: base.add(Duration(minutes: trigger)),
            contactName: name,
            channel: channel,
            detail: ok ? 'サンプル: 送信しました' : 'サンプル: 送信できませんでした',
          );
        }(),
    ];
  }

  static String _ymd(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}'
      '${day.month.toString().padLeft(2, '0')}'
      '${day.day.toString().padLeft(2, '0')}';
}

/// Writes and removes the generated history.
///
/// Deliberately **not** routed through `SessionService.settle`: a sample
/// morning is a drawing, not an event. Nothing here touches the wallet, the
/// ojisan counters, ログイン日数 or the garden — the rows go straight into the
/// three repositories the charts read, and come straight back out again.
class SampleDataService {
  const SampleDataService({
    required this.sessions,
    required this.charges,
    required this.events,
    required this.clock,
  });

  final AlarmSessionRepository sessions;
  final PendingChargeRepository charges;
  final ContactEventRepository events;
  final DateTime Function() clock;

  /// Removes any previous sample rows and writes a fresh twelve months.
  /// Answers how many rows were written.
  ///
  /// Delete-first, so pressing 作成 twice leaves exactly one history rather
  /// than two overlapping ones.
  Future<int> generate({int seed = defaultSampleSeed}) async {
    await delete();
    final data = SampleDataGenerator(seed: seed).generate(clock());
    for (final session in data.sessions) {
      await sessions.save(session);
    }
    for (final charge in data.charges) {
      await charges.insertIfAbsent(charge);
    }
    for (final event in data.events) {
      await events.save(event);
    }
    return data.rowCount;
  }

  /// Every row whose id starts with [sampleIdPrefix], and nothing else.
  Future<void> delete() async {
    await events.deleteWithIdPrefix(sampleIdPrefix);
    await charges.deleteWithSessionIdPrefix(sampleIdPrefix);
    await sessions.deleteWithIdPrefix(sampleIdPrefix);
  }
}

final sampleDataServiceProvider = Provider(
  (ref) => SampleDataService(
    sessions: ref.watch(alarmSessionRepositoryProvider),
    charges: ref.watch(pendingChargeRepositoryProvider),
    events: ref.watch(contactEventRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);
