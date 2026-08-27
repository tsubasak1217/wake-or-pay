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
}
