import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/database.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';

import '../helpers.dart';

/// The v1 schema, exactly as it shipped, plus one alarm and one settled
/// session. Neither table had a graceMinutes column.
const _v1 = '''
CREATE TABLE alarm_rows (
  id TEXT NOT NULL,
  hour INTEGER NOT NULL,
  minute INTEGER NOT NULL,
  repeat_days TEXT NOT NULL DEFAULT '',
  enabled INTEGER NOT NULL DEFAULT 1 CHECK ("enabled" IN (0, 1)),
  wake_check TEXT NOT NULL,
  kakugo_hostage TEXT NULL,
  kakugo_rate_per_minute INTEGER NULL,
  kakugo_cap INTEGER NULL,
  PRIMARY KEY (id)
);
CREATE TABLE alarm_session_rows (
  id TEXT NOT NULL,
  alarm_id TEXT NOT NULL,
  fired_at_ms INTEGER NOT NULL,
  dismissed_at_ms INTEGER NULL,
  status TEXT NOT NULL,
  loss INTEGER NOT NULL DEFAULT 0,
  kakugo_hostage TEXT NULL,
  kakugo_rate_per_minute INTEGER NULL,
  kakugo_cap INTEGER NULL,
  coins_at_fire INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
);
CREATE TABLE wallet_rows (
  id INTEGER NOT NULL,
  coins INTEGER NOT NULL DEFAULT 0,
  tokens INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
);
CREATE TABLE ojisan_rows (
  id INTEGER NOT NULL,
  total_oversleeps INTEGER NOT NULL DEFAULT 0,
  total_earned INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
);
INSERT INTO alarm_rows
  (id, hour, minute, repeat_days, enabled, wake_check,
   kakugo_hostage, kakugo_rate_per_minute, kakugo_cap)
  VALUES ('a1', 6, 30, '1,5', 1, 'math', 'coin', 100, 2000);
INSERT INTO alarm_session_rows
  (id, alarm_id, fired_at_ms, dismissed_at_ms, status, loss,
   kakugo_hostage, kakugo_rate_per_minute, kakugo_cap, coins_at_fire)
  VALUES ('s1', 'a1', 1000000, 1420000, 'failed', 700,
          'coin', 100, 2000, 5000);
PRAGMA user_version = 1;
''';

/// The v2 schema — v1 plus the two grace columns — with a placed alarm and a
/// settled session. Neither garden table existed yet.
const _v2 = '''
CREATE TABLE alarm_rows (
  id TEXT NOT NULL,
  hour INTEGER NOT NULL,
  minute INTEGER NOT NULL,
  repeat_days TEXT NOT NULL DEFAULT '',
  enabled INTEGER NOT NULL DEFAULT 1 CHECK ("enabled" IN (0, 1)),
  wake_check TEXT NOT NULL,
  grace_minutes INTEGER NOT NULL DEFAULT 1,
  kakugo_hostage TEXT NULL,
  kakugo_rate_per_minute INTEGER NULL,
  kakugo_cap INTEGER NULL,
  PRIMARY KEY (id)
);
CREATE TABLE alarm_session_rows (
  id TEXT NOT NULL,
  alarm_id TEXT NOT NULL,
  fired_at_ms INTEGER NOT NULL,
  dismissed_at_ms INTEGER NULL,
  status TEXT NOT NULL,
  loss INTEGER NOT NULL DEFAULT 0,
  kakugo_hostage TEXT NULL,
  kakugo_rate_per_minute INTEGER NULL,
  kakugo_cap INTEGER NULL,
  coins_at_fire INTEGER NOT NULL DEFAULT 0,
  grace_minutes INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (id)
);
CREATE TABLE wallet_rows (
  id INTEGER NOT NULL,
  coins INTEGER NOT NULL DEFAULT 0,
  tokens INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
);
CREATE TABLE ojisan_rows (
  id INTEGER NOT NULL,
  total_oversleeps INTEGER NOT NULL DEFAULT 0,
  total_earned INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
);
INSERT INTO alarm_rows
  (id, hour, minute, repeat_days, enabled, wake_check, grace_minutes,
   kakugo_hostage, kakugo_rate_per_minute, kakugo_cap)
  VALUES ('a1', 6, 30, '1,5', 1, 'math', 3, 'coin', 100, 2000);
INSERT INTO alarm_session_rows
  (id, alarm_id, fired_at_ms, dismissed_at_ms, status, loss,
   kakugo_hostage, kakugo_rate_per_minute, kakugo_cap, coins_at_fire,
   grace_minutes)
  VALUES ('s1', 'a1', 1000000, 1420000, 'failed', 700,
          'coin', 100, 2000, 5000, 3);
INSERT INTO wallet_rows (id, coins, tokens) VALUES (0, 4300, 120);
PRAGMA user_version = 2;
''';

/// The v3 schema — v2 plus the two garden tables — with an alarm, a settled
/// session, a wallet and a placed plant. No alarm could be snoozed, every alarm
/// rang with the one bundled sound, and no session had a drawn wake check.
const _v3 = '''
CREATE TABLE alarm_rows (
  id TEXT NOT NULL,
  hour INTEGER NOT NULL,
  minute INTEGER NOT NULL,
  repeat_days TEXT NOT NULL DEFAULT '',
  enabled INTEGER NOT NULL DEFAULT 1 CHECK ("enabled" IN (0, 1)),
  wake_check TEXT NOT NULL,
  grace_minutes INTEGER NOT NULL DEFAULT 1,
  kakugo_hostage TEXT NULL,
  kakugo_rate_per_minute INTEGER NULL,
  kakugo_cap INTEGER NULL,
  PRIMARY KEY (id)
);
CREATE TABLE alarm_session_rows (
  id TEXT NOT NULL,
  alarm_id TEXT NOT NULL,
  fired_at_ms INTEGER NOT NULL,
  dismissed_at_ms INTEGER NULL,
  status TEXT NOT NULL,
  loss INTEGER NOT NULL DEFAULT 0,
  kakugo_hostage TEXT NULL,
  kakugo_rate_per_minute INTEGER NULL,
  kakugo_cap INTEGER NULL,
  coins_at_fire INTEGER NOT NULL DEFAULT 0,
  grace_minutes INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (id)
);
CREATE TABLE wallet_rows (
  id INTEGER NOT NULL,
  coins INTEGER NOT NULL DEFAULT 0,
  tokens INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
);
CREATE TABLE ojisan_rows (
  id INTEGER NOT NULL,
  total_oversleeps INTEGER NOT NULL DEFAULT 0,
  total_earned INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
);
CREATE TABLE garden_placement_rows (
  id TEXT NOT NULL,
  item_id TEXT NOT NULL,
  x INTEGER NOT NULL,
  y INTEGER NOT NULL,
  placed_at_ms INTEGER NOT NULL,
  growth_stage INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
);
CREATE TABLE garden_inventory_rows (
  item_id TEXT NOT NULL,
  count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (item_id)
);
INSERT INTO alarm_rows
  (id, hour, minute, repeat_days, enabled, wake_check, grace_minutes,
   kakugo_hostage, kakugo_rate_per_minute, kakugo_cap)
  VALUES ('a1', 6, 30, '1,5', 1, 'math', 3, 'coin', 100, 2000);
INSERT INTO alarm_session_rows
  (id, alarm_id, fired_at_ms, dismissed_at_ms, status, loss,
   kakugo_hostage, kakugo_rate_per_minute, kakugo_cap, coins_at_fire,
   grace_minutes)
  VALUES ('s1', 'a1', 1000000, 1420000, 'failed', 700,
          'coin', 100, 2000, 5000, 3);
INSERT INTO wallet_rows (id, coins, tokens) VALUES (0, 4300, 120);
INSERT INTO garden_placement_rows
  (id, item_id, x, y, placed_at_ms, growth_stage)
  VALUES ('p1', 'plant_small', 3, 2, 1000000, 2);
INSERT INTO garden_inventory_rows (item_id, count) VALUES ('deco_pebble', 2);
PRAGMA user_version = 3;
''';

/// The v4 schema, with an alarm that already carries the stage B alarm columns
/// and a settled session whose frozen pledge could not carry them yet.
const _v4 = '''
CREATE TABLE alarm_rows (
  id TEXT NOT NULL,
  hour INTEGER NOT NULL,
  minute INTEGER NOT NULL,
  repeat_days TEXT NOT NULL DEFAULT '',
  enabled INTEGER NOT NULL DEFAULT 1 CHECK ("enabled" IN (0, 1)),
  wake_check TEXT NOT NULL,
  grace_minutes INTEGER NOT NULL DEFAULT 1,
  snooze_interval_minutes INTEGER NULL,
  snooze_max_count INTEGER NULL,
  sound_id TEXT NOT NULL DEFAULT 'bell',
  kakugo_hostage TEXT NULL,
  kakugo_rate_per_minute INTEGER NULL,
  kakugo_cap INTEGER NULL,
  kakugo_snooze_penalty INTEGER NULL,
  kakugo_snooze_resets_clock INTEGER NULL,
  oversleep_contact TEXT NULL,
  PRIMARY KEY (id)
);
CREATE TABLE alarm_session_rows (
  id TEXT NOT NULL,
  alarm_id TEXT NOT NULL,
  fired_at_ms INTEGER NOT NULL,
  dismissed_at_ms INTEGER NULL,
  status TEXT NOT NULL,
  loss INTEGER NOT NULL DEFAULT 0,
  kakugo_hostage TEXT NULL,
  kakugo_rate_per_minute INTEGER NULL,
  kakugo_cap INTEGER NULL,
  coins_at_fire INTEGER NOT NULL DEFAULT 0,
  grace_minutes INTEGER NOT NULL DEFAULT 1,
  wake_check_resolved TEXT NULL,
  snoozes TEXT NULL,
  current_ring_at_ms INTEGER NULL,
  PRIMARY KEY (id)
);
CREATE TABLE wallet_rows (
  id INTEGER NOT NULL,
  coins INTEGER NOT NULL DEFAULT 0,
  tokens INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
);
CREATE TABLE ojisan_rows (
  id INTEGER NOT NULL,
  total_oversleeps INTEGER NOT NULL DEFAULT 0,
  total_earned INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
);
CREATE TABLE garden_placement_rows (
  id TEXT NOT NULL,
  item_id TEXT NOT NULL,
  x INTEGER NOT NULL,
  y INTEGER NOT NULL,
  placed_at_ms INTEGER NOT NULL,
  growth_stage INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
);
CREATE TABLE garden_inventory_rows (
  item_id TEXT NOT NULL,
  count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (item_id)
);
CREATE TABLE contact_event_rows (
  id TEXT NOT NULL,
  session_id TEXT NOT NULL,
  fired_at_ms INTEGER NOT NULL,
  contact_name TEXT NOT NULL,
  channel TEXT NOT NULL,
  detail TEXT NULL,
  PRIMARY KEY (id)
);
INSERT INTO alarm_rows
  (id, hour, minute, repeat_days, enabled, wake_check, grace_minutes,
   snooze_interval_minutes, snooze_max_count, sound_id,
   kakugo_hostage, kakugo_rate_per_minute, kakugo_cap)
  VALUES ('a1', 6, 30, '1,5', 1, 'math', 3, 9, 4, 'siren',
          'coin', 100, 2000);
INSERT INTO alarm_session_rows
  (id, alarm_id, fired_at_ms, dismissed_at_ms, status, loss,
   kakugo_hostage, kakugo_rate_per_minute, kakugo_cap, coins_at_fire,
   grace_minutes)
  VALUES ('s1', 'a1', 1000000, 1420000, 'failed', 700,
          'coin', 100, 2000, 5000, 3);
INSERT INTO wallet_rows (id, coins, tokens) VALUES (0, 4300, 120);
PRAGMA user_version = 4;
''';

void main() {
  test(
    'v1 databases upgrade to v2 with grace 1, changing nothing else',
    () async {
      final container = await testContainer(
        extra: [
          appDatabaseProvider.overrideWith((ref) {
            final db = AppDatabase(
              NativeDatabase.memory(setup: (raw) => raw.execute(_v1)),
            );
            ref.onDispose(db.close);
            return db;
          }),
        ],
      );

      // Opening through the repository runs the migration.
      final alarm = await container.read(alarmRepositoryProvider).getById('a1');
      expect(alarm, isNotNull);
      expect(
        alarm!.graceMinutes,
        1,
        reason: 'the rule the row was written under',
      );
      expect(alarm.hour, 6);
      expect(alarm.minute, 30);
      expect(alarm.repeatDays, {1, 5});
      expect(alarm.wakeCheck, WakeCheckType.math);
      expect(alarm.kakugo, const Kakugo(ratePerMinute: 100, cap: 2000));

      final session = await container
          .read(alarmSessionRepositoryProvider)
          .getById('s1');
      expect(session!.graceMinutes, 1);
      expect(session.loss, 700, reason: 'a settled loss is never recomputed');
      expect(session.status, SessionStatus.failed);
      expect(session.coinsAtFire, 5000);

      // The upgraded database is writable at the new schema.
      await container
          .read(alarmRepositoryProvider)
          .save(alarm.copyWith(graceMinutes: 5));
      expect(
        (await container.read(alarmRepositoryProvider).getById('a1'))!
            .graceMinutes,
        5,
      );
    },
  );

  test('v2 databases upgrade to v3 with an empty, writable garden', () async {
    final container = await testContainer(
      extra: [
        appDatabaseProvider.overrideWith((ref) {
          final db = AppDatabase(
            NativeDatabase.memory(setup: (raw) => raw.execute(_v2)),
          );
          ref.onDispose(db.close);
          return db;
        }),
      ],
    );

    final garden = container.read(gardenRepositoryProvider);
    final before = await garden.read();
    expect(before.placements, isEmpty, reason: 'the new tables start empty');
    expect(before.inventory.owned, isEmpty);

    // Nothing the upgrade touched changed underneath the existing rows.
    final alarm = await container.read(alarmRepositoryProvider).getById('a1');
    expect(alarm!.graceMinutes, 3);
    expect(alarm.kakugo, const Kakugo(ratePerMinute: 100, cap: 2000));
    final session = await container
        .read(alarmSessionRepositoryProvider)
        .getById('s1');
    expect(session!.loss, 700);
    expect(session.graceMinutes, 3);
    expect(
      await container.read(walletRepositoryProvider).read(),
      const Wallet(coins: 4300, tokens: 120),
    );

    // An upgrading install gets the same free items a fresh one does.
    final granted = await garden.grantInitialIfNeeded(
      now: DateTime(2026, 8, 27),
    );
    expect(granted.placements.single.itemId, 'plant_small');
    expect(granted.inventory.countOf('deco_pebble'), 2);
    expect((await garden.read()).placements, hasLength(1));
  });

  test(
    'v3 databases upgrade to v4 with no snooze and the bundled sound',
    () async {
      final container = await testContainer(
        extra: [
          appDatabaseProvider.overrideWith((ref) {
            final db = AppDatabase(
              NativeDatabase.memory(setup: (raw) => raw.execute(_v3)),
            );
            ref.onDispose(db.close);
            return db;
          }),
        ],
      );

      // The v3 row reads back under the rules it was written under.
      final alarm = await container.read(alarmRepositoryProvider).getById('a1');
      expect(alarm!.snooze, isNull, reason: 'v3 alarms could not be snoozed');
      expect(alarm.soundId, defaultSoundId, reason: 'the one bundled sound');
      expect(alarm.graceMinutes, 3);
      expect(alarm.hour, 6);
      expect(alarm.minute, 30);
      expect(alarm.repeatDays, {1, 5});
      expect(alarm.wakeCheck, WakeCheckType.math);
      expect(alarm.kakugo, const Kakugo(ratePerMinute: 100, cap: 2000));

      final session = await container
          .read(alarmSessionRepositoryProvider)
          .getById('s1');
      expect(
        session!.wakeCheckResolved,
        isNull,
        reason: 'no draw was ever made',
      );
      expect(session.loss, 700, reason: 'a settled loss is never recomputed');
      expect(session.status, SessionStatus.failed);
      expect(session.graceMinutes, 3);
      expect(session.coinsAtFire, 5000);

      // Nothing else the upgrade touched moved either.
      expect(
        await container.read(walletRepositoryProvider).read(),
        const Wallet(coins: 4300, tokens: 120),
      );
      final garden = await container.read(gardenRepositoryProvider).read();
      expect(garden.placements.single.itemId, 'plant_small');
      expect(garden.inventory.countOf('deco_pebble'), 2);

      // The upgraded database is writable at the new schema.
      final snoozed = alarm.copyWith(
        snooze: const Snooze(intervalMinutes: 9, maxCount: 4),
        soundId: 'siren',
      );
      await container.read(alarmRepositoryProvider).save(snoozed);
      final reread = await container
          .read(alarmRepositoryProvider)
          .getById('a1');
      expect(reread!.snooze, const Snooze(intervalMinutes: 9, maxCount: 4));
      expect(reread.soundId, 'siren');

      // And the stage B table exists, empty.
      final db = container.read(appDatabaseProvider);
      expect(await db.select(db.contactEventRows).get(), isEmpty);
    },
  );

  test('v4 databases upgrade to v5 with a free, non-resetting snooze', () async {
    final container = await testContainer(
      extra: [
        appDatabaseProvider.overrideWith((ref) {
          final db = AppDatabase(
            NativeDatabase.memory(setup: (raw) => raw.execute(_v4)),
          );
          ref.onDispose(db.close);
          return db;
        }),
      ],
    );

    final alarm = await container.read(alarmRepositoryProvider).getById('a1');
    expect(alarm!.snooze, const Snooze(intervalMinutes: 9, maxCount: 4));
    expect(alarm.soundId, 'siren');
    expect(alarm.graceMinutes, 3);
    expect(
      alarm.kakugo,
      const Kakugo(ratePerMinute: 100, cap: 2000),
      reason: 'penalty 0, clock never resets — the rule the row was under',
    );

    final session = await container
        .read(alarmSessionRepositoryProvider)
        .getById('s1');
    expect(session!.loss, 700, reason: 'a settled loss is never recomputed');
    expect(session.status, SessionStatus.failed);
    expect(session.snoozes, isEmpty);
    expect(
      session.currentRingAt,
      session.firedAt,
      reason: 'a session that was never snoozed still rings from firedAt',
    );
    expect(session.kakugoSnapshot!.snoozePenalty, 0);
    expect(session.kakugoSnapshot!.snoozeResetsClock, isFalse);
    expect(
      await container.read(walletRepositoryProvider).read(),
      const Wallet(coins: 4300, tokens: 120),
    );

    // The upgraded database is writable at the new schema, on both tables.
    await container
        .read(alarmRepositoryProvider)
        .save(
          alarm.copyWith(
            kakugo: alarm.kakugo!.copyWith(
              snoozePenalty: 250,
              snoozeResetsClock: true,
            ),
          ),
        );
    final reread = await container.read(alarmRepositoryProvider).getById('a1');
    expect(reread!.kakugo!.snoozePenalty, 250);
    expect(reread.kakugo!.snoozeResetsClock, isTrue);

    final fired = DateTime.fromMillisecondsSinceEpoch(1000000);
    await container
        .read(alarmSessionRepositoryProvider)
        .save(
          AlarmSession(
            id: 's2',
            alarmId: 'a1',
            firedAt: fired,
            kakugoSnapshot: reread.kakugo,
            snoozes: [fired.add(const Duration(minutes: 2))],
            currentRingAt: fired.add(const Duration(minutes: 7)),
          ),
        );
    final s2 = await container
        .read(alarmSessionRepositoryProvider)
        .getById('s2');
    expect(s2!.snoozes, [fired.add(const Duration(minutes: 2))]);
    expect(s2.currentRingAt, fired.add(const Duration(minutes: 7)));
    expect(s2.kakugoSnapshot!.snoozePenalty, 250);
    expect(s2.kakugoSnapshot!.snoozeResetsClock, isTrue);
  });
}
