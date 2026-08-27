import 'package:drift/drift.dart';

import '../../domain/models.dart';
import '../database.dart';
import '../mappers.dart';

class AlarmRepository {
  AlarmRepository(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$AlarmRowsTable, AlarmRow> get _ordered =>
      _db.select(_db.alarmRows)..orderBy([
        (a) => OrderingTerm(expression: a.hour),
        (a) => OrderingTerm(expression: a.minute),
        (a) => OrderingTerm(expression: a.id),
      ]);

  Future<List<Alarm>> getAll() async =>
      (await _ordered.get()).map((r) => r.toModel()).toList();

  Stream<List<Alarm>> watchAll() =>
      _ordered.watch().map((rows) => rows.map((r) => r.toModel()).toList());

  Future<Alarm?> getById(String id) async {
    final row = await (_db.select(
      _db.alarmRows,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    return row?.toModel();
  }

  /// Live view of one alarm. Emits again on every write to it, so a screen
  /// holding this can never be looking at a pre-edit copy.
  Stream<Alarm?> watchById(String id) =>
      (_db.select(_db.alarmRows)..where((a) => a.id.equals(id)))
          .watchSingleOrNull()
          .map((r) => r?.toModel());

  /// Insert or replace.
  Future<void> save(Alarm alarm) =>
      _db.into(_db.alarmRows).insertOnConflictUpdate(alarm.toCompanion());

  Future<void> delete(String id) =>
      (_db.delete(_db.alarmRows)..where((a) => a.id.equals(id))).go();

  Future<void> setEnabled(String id, bool enabled) =>
      (_db.update(_db.alarmRows)..where((a) => a.id.equals(id))).write(
        AlarmRowsCompanion(enabled: Value(enabled)),
      );
}
