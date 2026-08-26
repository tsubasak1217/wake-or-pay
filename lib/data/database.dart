import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

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
  TextColumn get kakugoHostage => text().nullable()();
  IntColumn get kakugoRatePerMinute => integer().nullable()();
  IntColumn get kakugoCap => integer().nullable()();

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

@DriftDatabase(tables: [AlarmRows, AlarmSessionRows, WalletRows, OjisanRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// On-device database.
  AppDatabase.file() : super(driftDatabase(name: 'wake_or_pay'));

  /// Throwaway database for tests.
  AppDatabase.memory() : super(inMemoryExecutor());

  @override
  int get schemaVersion => 1;
}

/// Kept as a function so tests can build one without touching the filesystem.
QueryExecutor inMemoryExecutor() => NativeDatabase.memory();
