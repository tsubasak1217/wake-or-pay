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

/// The v5 schema — v4 plus the session's two pledge columns — with an alarm
/// that already carries a contact and a settled session. The 連絡帳 table did
/// not exist yet, so that alarm's contact references nobody.
const _v5 = '''
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
  kakugo_snooze_penalty INTEGER NULL,
  kakugo_snooze_resets_clock INTEGER NULL,
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
   kakugo_hostage, kakugo_rate_per_minute, kakugo_cap,
   kakugo_snooze_penalty, kakugo_snooze_resets_clock, oversleep_contact)
  VALUES ('a1', 6, 30, '1,5', 1, 'math', 3, 9, 4, 'siren',
          'coin', 100, 2000, 50, 0,
          '{"name":"母","phone":"090-0000-0000","email":null,"triggerMinutesAfterGrace":5,"message":"起きて","recordingPath":"/tmp/a.m4a"}');
INSERT INTO alarm_session_rows
  (id, alarm_id, fired_at_ms, dismissed_at_ms, status, loss,
   kakugo_hostage, kakugo_rate_per_minute, kakugo_cap, coins_at_fire,
   grace_minutes)
  VALUES ('s1', 'a1', 1000000, 1420000, 'failed', 700,
          'coin', 100, 2000, 5000, 3);
INSERT INTO wallet_rows (id, coins, tokens) VALUES (0, 4300, 120);
PRAGMA user_version = 5;
''';

/// The v6 schema — v5 plus the 連絡帳 — with an alarm whose contact is written
/// in the shape 改訂2 gave it: a mail mode beside a phone mode, a recording for
/// the automated voice that no longer exists, and the trigger delay still
/// inside the blob rather than in a column of its own.
const _v6 = '''
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
  kakugo_snooze_penalty INTEGER NULL,
  kakugo_snooze_resets_clock INTEGER NULL,
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
CREATE TABLE contact_book_rows (
  id TEXT NOT NULL,
  name TEXT NOT NULL,
  reading TEXT NULL,
  phone TEXT NULL,
  email TEXT NULL,
  created_at_ms INTEGER NOT NULL,
  PRIMARY KEY (id)
);
INSERT INTO alarm_rows
  (id, hour, minute, repeat_days, enabled, wake_check, grace_minutes,
   snooze_interval_minutes, snooze_max_count, sound_id,
   kakugo_hostage, kakugo_rate_per_minute, kakugo_cap,
   kakugo_snooze_penalty, kakugo_snooze_resets_clock, oversleep_contact)
  VALUES ('a1', 6, 30, '1,5', 1, 'math', 3, 9, 4, 'siren',
          'coin', 100, 2000, 50, 0,
          '{"name":"母","phone":"090-0000-0000","email":null,"phoneEnabled":true,"emailEnabled":false,"mailMode":"custom","message":"起きて","phoneMode":"custom","recordingPath":"/tmp/a.m4a","recordingWaveform":[0.5],"triggerMinutesAfterGrace":7}');
INSERT INTO alarm_session_rows
  (id, alarm_id, fired_at_ms, dismissed_at_ms, status, loss,
   kakugo_hostage, kakugo_rate_per_minute, kakugo_cap, coins_at_fire,
   grace_minutes)
  VALUES ('s1', 'a1', 1000000, 1420000, 'failed', 700,
          'coin', 100, 2000, 5000, 3);
INSERT INTO wallet_rows (id, coins, tokens) VALUES (0, 4300, 120);
PRAGMA user_version = 6;
''';

/// The v7 schema — v6 plus the share blob, the shared delay and the Discord
/// 共有先 table — as it shipped before 人質 was a choice.
///
/// Three alarms, because reading a stored 人質 back is the whole point of the
/// v8 upgrade: `a1` never had a name written down at all, `a2` names the coins,
/// and `a3` is the old spelling of 連絡だけの覚悟 — a hostage named, at a price
/// of nothing a minute.
const _v7 = '''
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
  oversleep_share TEXT NULL,
  oversleep_trigger_minutes INTEGER NULL,
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
  kakugo_snooze_penalty INTEGER NULL,
  kakugo_snooze_resets_clock INTEGER NULL,
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
CREATE TABLE contact_book_rows (
  id TEXT NOT NULL,
  name TEXT NOT NULL,
  reading TEXT NULL,
  phone TEXT NULL,
  email TEXT NULL,
  created_at_ms INTEGER NOT NULL,
  PRIMARY KEY (id)
);
CREATE TABLE discord_webhook_rows (
  id TEXT NOT NULL,
  url TEXT NOT NULL,
  display_name TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  PRIMARY KEY (id)
);
INSERT INTO alarm_rows
  (id, hour, minute, repeat_days, enabled, wake_check, grace_minutes,
   snooze_interval_minutes, snooze_max_count, sound_id,
   kakugo_hostage, kakugo_rate_per_minute, kakugo_cap,
   kakugo_snooze_penalty, kakugo_snooze_resets_clock,
   oversleep_trigger_minutes)
  VALUES ('a1', 6, 30, '1,5', 1, 'math', 3, 9, 4, 'siren',
          NULL, 100, 2000, 50, 0, 7);
INSERT INTO alarm_rows
  (id, hour, minute, repeat_days, enabled, wake_check, grace_minutes,
   sound_id, kakugo_hostage, kakugo_rate_per_minute, kakugo_cap,
   oversleep_trigger_minutes)
  VALUES ('a2', 7, 0, '', 1, 'longPress', 1, 'bell', 'coin', 500, 1000, 0);
INSERT INTO alarm_rows
  (id, hour, minute, repeat_days, enabled, wake_check, grace_minutes,
   sound_id, kakugo_hostage, kakugo_rate_per_minute, kakugo_cap,
   kakugo_snooze_penalty, oversleep_trigger_minutes)
  VALUES ('a3', 8, 15, '', 1, 'longPress', 1, 'bell', 'coin', 0, 1000, 0, 0);
INSERT INTO alarm_session_rows
  (id, alarm_id, fired_at_ms, dismissed_at_ms, status, loss,
   kakugo_hostage, kakugo_rate_per_minute, kakugo_cap, coins_at_fire,
   grace_minutes)
  VALUES ('s1', 'a1', 1000000, 1420000, 'failed', 700,
          NULL, 100, 2000, 5000, 3);
INSERT INTO wallet_rows (id, coins, tokens) VALUES (0, 4300, 120);
PRAGMA user_version = 7;
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

  test(
    'v4 databases upgrade to v5 with a free, non-resetting snooze',
    () async {
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
      final reread = await container
          .read(alarmRepositoryProvider)
          .getById('a1');
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
    },
  );

  test('v5 databases upgrade to v6 with an empty, writable 連絡帳', () async {
    final container = await testContainer(
      extra: [
        appDatabaseProvider.overrideWith((ref) {
          final db = AppDatabase(
            NativeDatabase.memory(setup: (raw) => raw.execute(_v5)),
          );
          ref.onDispose(db.close);
          return db;
        }),
      ],
    );

    final book = container.read(contactBookRepositoryProvider);
    expect(await book.getAll(), isEmpty, reason: 'the new table starts empty');

    // The v5 contact reads back under the rules it was written under: the one
    // 「message」 doing double duty becomes the custom body, the routes it had
    // an address for are on, and the delay it carried is still five minutes.
    final alarm = await container.read(alarmRepositoryProvider).getById('a1');
    final contact = alarm!.contact!;
    expect(contact.name, '母');
    expect(contact.contactId, isNull, reason: 'the book did not exist yet');
    expect(contact.phone, '090-0000-0000', reason: 'the number is kept for SMS');
    expect(contact.emailEnabled, isFalse, reason: 'no address to mail');
    expect(contact.smsEnabled, isFalse, reason: 'nobody asked for a text');
    expect(contact.messageMode, MessageMode.custom);
    expect(contact.message, '起きて');
    expect(alarm.oversleepTriggerMinutes, 5);

    // Nothing else the upgrade touched moved.
    expect(alarm.snooze, const Snooze(intervalMinutes: 9, maxCount: 4));
    expect(alarm.kakugo!.snoozePenalty, 50);
    final session = await container
        .read(alarmSessionRepositoryProvider)
        .getById('s1');
    expect(session!.loss, 700, reason: 'a settled loss is never recomputed');
    expect(
      await container.read(walletRepositoryProvider).read(),
      const Wallet(coins: 4300, tokens: 120),
    );

    // The upgraded database is writable at the new schema, on both sides of
    // the reference: the book, and an alarm pointing into it.
    await book.save(
      ContactEntry(
        id: 'c1',
        name: '田中太郎',
        reading: 'たなかたろう',
        phone: '090-1111-2222',
        createdAt: DateTime(2026, 8, 27),
      ),
    );
    expect((await book.getAll()).single.name, '田中太郎');

    await container
        .read(alarmRepositoryProvider)
        .save(
          alarm.copyWith(
            contact: contact.copyWith(contactId: 'c1'),
            oversleepTriggerMinutes: 0,
          ),
        );
    final reread = (await container
        .read(alarmRepositoryProvider)
        .getById('a1'))!;
    expect(reread.contact!.contactId, 'c1');
    expect(reread.oversleepTriggerMinutes, 0);

    // And deleting that entry leaves the alarm still knowing who to contact.
    await book.delete('c1');
    expect(await book.getAll(), isEmpty);
    final orphaned = (await container
        .read(alarmRepositoryProvider)
        .getById('a1'))!;
    expect(orphaned.contact!.name, '母');
    expect(orphaned.contact!.phone, '090-0000-0000');
  });

  test(
    'v6 databases upgrade to v7 with the delay kept and no 共有先',
    () async {
      final container = await testContainer(
        extra: [
          appDatabaseProvider.overrideWith((ref) {
            final db = AppDatabase(
              NativeDatabase.memory(setup: (raw) => raw.execute(_v6)),
            );
            ref.onDispose(db.close);
            return db;
          }),
        ],
      );

      // The v6 contact reads back under the rule it was written under: the
      // words the user typed survive, and the retired 電話設定 does not — the
      // phone-call route is gone, so an old blob's phone toggle and its
      // recording are read and discarded; the number is kept for SMS.
      final alarm = await container.read(alarmRepositoryProvider).getById('a1');
      final contact = alarm!.contact!;
      expect(contact.name, '母');
      expect(contact.phone, '090-0000-0000', reason: 'kept for SMS');
      expect(contact.emailEnabled, isFalse);
      expect(contact.smsEnabled, isFalse, reason: 'nobody asked for a text');
      expect(contact.messageMode, MessageMode.custom);
      expect(contact.message, '起きて');
      for (final gone in const [
        'recordingPath',
        'recordingWaveform',
        'phoneMode',
        'phoneEnabled',
      ]) {
        expect(contact.toJson().containsKey(gone), isFalse, reason: gone);
      }

      // The delay moved from inside the blob to a column of its own, and a
      // row that has no column yet is read out of the blob that owned it.
      expect(
        alarm.oversleepTriggerMinutes,
        7,
        reason: 'an alarm set to 猶予後7分 still fires at seven minutes',
      );
      expect(alarm.triggerMinutes, 7);
      expect(
        alarm.share,
        isNull,
        reason: 'a v6 alarm announced itself nowhere',
      );
      expect(alarm.willShare, isFalse);

      // Nothing else the upgrade touched moved.
      expect(alarm.snooze, const Snooze(intervalMinutes: 9, maxCount: 4));
      expect(alarm.soundId, 'siren');
      expect(alarm.graceMinutes, 3);
      expect(alarm.kakugo!.snoozePenalty, 50);
      expect(alarm.kakugo!.snoozeResetsClock, isFalse);
      final session = await container
          .read(alarmSessionRepositoryProvider)
          .getById('s1');
      expect(session!.loss, 700, reason: 'a settled loss is never recomputed');
      expect(session.status, SessionStatus.failed);
      expect(session.graceMinutes, 3);
      expect(
        await container.read(walletRepositoryProvider).read(),
        const Wallet(coins: 4300, tokens: 120),
      );
      expect(
        await container.read(contactBookRepositoryProvider).getAll(),
        isEmpty,
      );

      // The new 共有先 table exists and is writable, and an alarm can point at
      // a row in it and read the whole share back.
      final webhooks = container.read(discordWebhookRepositoryProvider);
      expect(await webhooks.getAll(), isEmpty, reason: 'it starts empty');
      await webhooks.save(
        DiscordWebhook(
          id: 'w1',
          url: 'https://discord.com/api/webhooks/123456789/abcTOKEN',
          displayName: 'みんなのサーバー/#一般',
          createdAt: DateTime(2026, 8, 27),
        ),
      );
      expect((await webhooks.getAll()).single.displayName, 'みんなのサーバー/#一般');

      await container
          .read(alarmRepositoryProvider)
          .save(
            alarm.copyWith(
              share: const OversleepShare(
                webhookIds: {'w1'},
                messageMode: MessageMode.custom,
                message: '起きろ',
              ),
              oversleepTriggerMinutes: 0,
            ),
          );
      final reread = (await container
          .read(alarmRepositoryProvider)
          .getById('a1'))!;
      expect(reread.share!.webhookIds, {'w1'});
      expect(reread.share!.message, '起きろ');
      expect(reread.oversleepTriggerMinutes, 0);
      expect(reread.willShare, isTrue);

      // And deleting the 共有先 leaves the alarm alone: it holds an id, and an
      // id with no row behind it is simply skipped when the list is read.
      await webhooks.delete('w1');
      expect(
        (await container.read(alarmRepositoryProvider).getById('a1'))!
            .share!
            .webhookIds,
        {'w1'},
      );
    },
  );

  test(
    'v7 databases upgrade to v8 with an empty 請求台帳 and their 人質 read back',
    () async {
      final container = await testContainer(
        extra: [
          appDatabaseProvider.overrideWith((ref) {
            final db = AppDatabase(
              NativeDatabase.memory(setup: (raw) => raw.execute(_v7)),
            );
            ref.onDispose(db.close);
            return db;
          }),
        ],
      );

      final alarms = container.read(alarmRepositoryProvider);

      // No 人質 was ever written down: coins were the only thing that could
      // burn when the row was saved, so coins is what it means.
      final a1 = (await alarms.getById('a1'))!;
      expect(a1.kakugo!.hostage, HostageType.coin);
      expect(a1.kakugo!.ratePerMinute, 100);

      // The one that named them says the same thing.
      expect((await alarms.getById('a2'))!.kakugo!.hostage, HostageType.coin);

      // 「0 コイン/分」 was how 連絡だけの覚悟 used to be written down. It reads
      // back as 人質なし rather than being rounded up to the new minimum, so
      // nothing starts burning that never burned before.
      final a3 = (await alarms.getById('a3'))!;
      expect(a3.kakugo!.hostage, HostageType.none);
      expect(a3.kakugo!.ratePerMinute, 0, reason: 'kept exactly as written');

      // A session's frozen pledge reads under the same rule.
      final session = await container
          .read(alarmSessionRepositoryProvider)
          .getById('s1');
      expect(session!.kakugoSnapshot!.hostage, HostageType.coin);
      expect(session.loss, 700, reason: 'a settled loss is never recomputed');

      // Nothing else the upgrade touched moved.
      expect(a1.snooze, const Snooze(intervalMinutes: 9, maxCount: 4));
      expect(a1.soundId, 'siren');
      expect(a1.oversleepTriggerMinutes, 7);
      expect(
        await container.read(walletRepositoryProvider).read(),
        const Wallet(coins: 4300, tokens: 120),
      );

      // The new ledger exists, starts empty, and takes one charge per session.
      final charges = container.read(pendingChargeRepositoryProvider);
      expect(await charges.getAll(), isEmpty, reason: 'it starts empty');

      final charge = PendingCharge(
        sessionId: 's1',
        alarmId: 'a1',
        amount: 700,
        createdAt: DateTime(2026, 8, 29),
      );
      expect(await charges.insertIfAbsent(charge), isTrue);
      expect(
        await charges.insertIfAbsent(charge.copyWithAmountForTest(9999)),
        isFalse,
        reason: 'the session id is the identity: a second write is ignored',
      );
      final stored = (await charges.getAll()).single;
      expect(stored.amount, 700, reason: 'the first amount is the one kept');
      expect(stored.currency, 'jpy');
      expect(stored.status, PendingChargeStatus.pending);

      await charges.mark('s1', PendingChargeStatus.paid);
      expect(
        (await charges.getBySessionId('s1'))!.status,
        PendingChargeStatus.paid,
      );

      // And an alarm can be saved with any 人質 now, 人質なし included.
      await alarms.save(
        a1.copyWith(kakugo: a1.kakugo!.copyWith(hostage: HostageType.none)),
      );
      expect(
        (await alarms.getById('a1'))!.kakugo!.hostage,
        HostageType.none,
        reason: 'a stored none is a none, not a coin',
      );
    },
  );
}

extension on PendingCharge {
  /// A second charge for the same session, differing only in what it is for —
  /// the write the ledger has to ignore.
  PendingCharge copyWithAmountForTest(int amount) => PendingCharge(
    sessionId: sessionId,
    alarmId: alarmId,
    amount: amount,
    createdAt: createdAt,
  );
}
