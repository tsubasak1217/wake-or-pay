import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../domain/models.dart' show defaultSoundId;

part 'database.g.dart';

/// Timestamps are stored as epoch milliseconds so nothing is rounded away
/// between a ring and its recovery.
class AlarmRows extends Table {
  TextColumn get id => text()();
  IntColumn get hour => integer()();
  IntColumn get minute => integer()();

  /// Comma separated weekdays, 1-7. Empty string = one shot.
  TextColumn get repeatDays => text().withDefault(const Constant(''))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get wakeCheck => text()();

  /// Minutes of slack before the burn starts, 1-5. Alarms written before this
  /// column existed keep the old behaviour, which is exactly 1.
  IntColumn get graceMinutes => integer().withDefault(const Constant(1))();

  /// Both null = this alarm cannot be snoozed. Rows written before v4 read
  /// that way, which is the rule they were saved under.
  IntColumn get snoozeIntervalMinutes => integer().nullable()();
  IntColumn get snoozeMaxCount => integer().nullable()();

  /// A sound library id, or `file:<path>`. Alarms written before v4 rang with
  /// the one bundled sound, which is `bell`.
  TextColumn get soundId =>
      text().withDefault(const Constant(defaultSoundId))();
  TextColumn get kakugoHostage => text().nullable()();
  IntColumn get kakugoRatePerMinute => integer().nullable()();
  IntColumn get kakugoCap => integer().nullable()();

  /// Stage B of the v2 alarm spec: the coin cost of one snooze, and whether
  /// snoozing restarts the clock. Added in the v4 migration, together with
  /// [oversleepContact], so that stage needs no migration of its own. Nothing
  /// reads them yet.
  IntColumn get kakugoSnoozePenalty => integer().nullable()();
  BoolColumn get kakugoSnoozeResetsClock => boolean().nullable()();

  /// Stage B: the whole OversleepContact as one JSON blob, because it is only
  /// ever read and written whole.
  TextColumn get oversleepContact => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class AlarmSessionRows extends Table {
  TextColumn get id => text()();
  TextColumn get alarmId => text()();
  IntColumn get firedAtMs => integer()();
  IntColumn get dismissedAtMs => integer().nullable()();
  TextColumn get status => text()();
  IntColumn get loss => integer().withDefault(const Constant(0))();
  TextColumn get kakugoHostage => text().nullable()();
  IntColumn get kakugoRatePerMinute => integer().nullable()();
  IntColumn get kakugoCap => integer().nullable()();
  IntColumn get coinsAtFire => integer().withDefault(const Constant(0))();

  /// The grace window frozen at fire time, alongside the pledge and balance.
  IntColumn get graceMinutes => integer().withDefault(const Constant(1))();

  /// The wake check drawn for this ring, set only when the alarm asked for a
  /// random one. Stored so a relaunch mid-ring cannot re-roll it.
  TextColumn get wakeCheckResolved => text().nullable()();

  /// Stage B: the times the user pressed snooze (JSON list of epoch millis)
  /// and the start of the current ring. Added in v4 so stage B needs no
  /// migration; nothing reads them yet.
  TextColumn get snoozes => text().nullable()();
  IntColumn get currentRingAtMs => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Stage B: one record of the app deciding to contact someone about an
/// overslept alarm. Created empty in v4 and not written yet.
class ContactEventRows extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  IntColumn get firedAtMs => integer()();
  TextColumn get contactName => text()();
  TextColumn get channel => text()();
  TextColumn get detail => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Single-row tables. `id` is always 0.
class WalletRows extends Table {
  IntColumn get id => integer()();
  IntColumn get coins => integer().withDefault(const Constant(0))();
  IntColumn get tokens => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class OjisanRows extends Table {
  IntColumn get id => integer()();
  IntColumn get totalOversleeps => integer().withDefault(const Constant(0))();
  IntColumn get totalEarned => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One placed garden item. Grid coordinates have their origin at the bottom
/// left of the terrarium floor.
class GardenPlacementRows extends Table {
  TextColumn get id => text()();

  /// Catalogue id. Definitions live in code, so nothing here has to migrate
  /// when an item is renamed or repriced.
  TextColumn get itemId => text()();
  IntColumn get x => integer()();
  IntColumn get y => integer()();
  IntColumn get placedAtMs => integer()();

  /// Cached growth stage. Recomputed from session history on every read; kept
  /// here only so the garden can paint before history arrives.
  IntColumn get growthStage => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Owned but unplaced items, one row per catalogue id.
class GardenInventoryRows extends Table {
  TextColumn get itemId => text()();
  IntColumn get count => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {itemId};
}

@DriftDatabase(
  tables: [
    AlarmRows,
    AlarmSessionRows,
    WalletRows,
    OjisanRows,
    GardenPlacementRows,
    GardenInventoryRows,
    ContactEventRows,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// On-device database.
  AppDatabase.file() : super(driftDatabase(name: 'wake_or_pay'));

  /// Throwaway database for tests.
  AppDatabase.memory() : super(inMemoryExecutor());

  @override
  int get schemaVersion => 4;

  /// v1 → v2 adds the per alarm grace window. Both columns default to 1, which
  /// is the rule every existing row was written under, so no stored session's
  /// loss changes under the upgrade.
  ///
  /// v2 → v3 adds the two garden tables. They start empty; the first grant is
  /// handed out by [GardenRepository], not by the migration, so an upgrading
  /// install gets the same free items a fresh one does.
  ///
  /// v3 → v4 is the alarm v2 spec's one schema change, done in a single pass so
  /// that stage B of that spec needs no migration of its own. Everything added
  /// is nullable or defaulted to the rule the existing rows were written under:
  /// no snooze, the one bundled sound, no drawn wake check. No stored session's
  /// loss or outcome changes.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(alarmRows, alarmRows.graceMinutes);
        await m.addColumn(alarmSessionRows, alarmSessionRows.graceMinutes);
      }
      if (from < 3) {
        await m.createTable(gardenPlacementRows);
        await m.createTable(gardenInventoryRows);
      }
      if (from < 4) {
        await m.addColumn(alarmRows, alarmRows.snoozeIntervalMinutes);
        await m.addColumn(alarmRows, alarmRows.snoozeMaxCount);
        await m.addColumn(alarmRows, alarmRows.soundId);
        await m.addColumn(alarmRows, alarmRows.kakugoSnoozePenalty);
        await m.addColumn(alarmRows, alarmRows.kakugoSnoozeResetsClock);
        await m.addColumn(alarmRows, alarmRows.oversleepContact);
        await m.addColumn(alarmSessionRows, alarmSessionRows.wakeCheckResolved);
        await m.addColumn(alarmSessionRows, alarmSessionRows.snoozes);
        await m.addColumn(alarmSessionRows, alarmSessionRows.currentRingAtMs);
        await m.createTable(contactEventRows);
      }
    },
  );
}

/// Kept as a function so tests can build one without touching the filesystem.
QueryExecutor inMemoryExecutor() => NativeDatabase.memory();
