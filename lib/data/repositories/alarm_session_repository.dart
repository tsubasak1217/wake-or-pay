import 'package:drift/drift.dart';

import '../../domain/models.dart';
import '../database.dart';
import '../mappers.dart';

class AlarmSessionRepository {
  AlarmSessionRepository(this._db);

  final AppDatabase _db;

  Future<void> save(AlarmSession session) => _db
      .into(_db.alarmSessionRows)
      .insertOnConflictUpdate(session.toCompanion());

  Future<AlarmSession?> getById(String id) async {
    final row = await (_db.select(
      _db.alarmSessionRows,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    return row?.toModel();
  }

  /// The session currently ringing, if any. Newest first, so a stale one left
  /// behind by an older crash never shadows the live ring.
  Future<AlarmSession?> getRinging() async {
    final row =
        await (_db.select(_db.alarmSessionRows)
              ..where((s) => s.status.equals(SessionStatus.ringing.name))
              ..orderBy([
                (s) => OrderingTerm(
                  expression: s.firedAtMs,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .getSingleOrNull();
    return row?.toModel();
  }

  Future<List<AlarmSession>> getRingingAll() async =>
      (await (_db.select(
            _db.alarmSessionRows,
          )..where((s) => s.status.equals(SessionStatus.ringing.name))).get())
          .map((r) => r.toModel())
          .toList();

  /// Every session the database still calls ringing, live. Includes the ones
  /// that are snoozed and silent — the alarm list needs those to show
  /// 「スヌーズ中 7:05」.
  Stream<List<AlarmSession>> watchRinging() =>
      (_db.select(_db.alarmSessionRows)
            ..where((s) => s.status.equals(SessionStatus.ringing.name)))
          .watch()
          .map((rows) => rows.map((r) => r.toModel()).toList());

  /// History, newest first.
  Future<List<AlarmSession>> getRecent({int limit = 100}) async =>
      (await (_db.select(_db.alarmSessionRows)
                ..orderBy([
                  (s) => OrderingTerm(
                    expression: s.firedAtMs,
                    mode: OrderingMode.desc,
                  ),
                ])
                ..limit(limit))
              .get())
          .map((r) => r.toModel())
          .toList();

  Stream<List<AlarmSession>> watchRecent({int limit = 100}) =>
      (_db.select(_db.alarmSessionRows)
            ..orderBy([
              (s) => OrderingTerm(
                expression: s.firedAtMs,
                mode: OrderingMode.desc,
              ),
            ])
            ..limit(limit))
          .watch()
          .map((rows) => rows.map((r) => r.toModel()).toList());

  Future<void> delete(String id) =>
      (_db.delete(_db.alarmSessionRows)..where((s) => s.id.equals(id))).go();
}
