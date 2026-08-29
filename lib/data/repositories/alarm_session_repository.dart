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

  /// The open session of one particular alarm, newest first.
  ///
  /// [getRinging] answers "what is ringing right now", which is the wrong
  /// question once a second alarm can be snoozed in the background: the newest
  /// ringing session may belong to somebody else entirely, and a re-ring that
  /// matched against it would open a second session for the same morning.
  Future<AlarmSession?> getRingingForAlarm(String alarmId) async {
    final row =
        await (_db.select(_db.alarmSessionRows)
              ..where(
                (s) =>
                    s.status.equals(SessionStatus.ringing.name) &
                    s.alarmId.equals(alarmId),
              )
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

  /// Every session there has ever been, newest first — **no limit**.
  ///
  /// 「これまでの歩み」 is a lifetime total, and reading it off [watchRecent] would
  /// quietly stop counting at the hundredth ring: the numbers would go down as
  /// the user kept using the app, which is the one thing a lifetime total must
  /// never do.
  Stream<List<AlarmSession>> watchAll() =>
      (_db.select(_db.alarmSessionRows)..orderBy([
            (s) => OrderingTerm(
              expression: s.firedAtMs,
              mode: OrderingMode.desc,
            ),
          ]))
          .watch()
          .map((rows) => rows.map((r) => r.toModel()).toList());

  Future<void> delete(String id) =>
      (_db.delete(_db.alarmSessionRows)..where((s) => s.id.equals(id))).go();
}
