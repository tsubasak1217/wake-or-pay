import 'package:drift/drift.dart';

import '../../domain/models.dart';
import '../database.dart';
import '../mappers.dart';

/// The log of oversleep contacts. Append only — nothing here is ever edited,
/// because it is a record of something that happened.
class ContactEventRepository {
  ContactEventRepository(this._db);

  final AppDatabase _db;

  Future<void> save(ContactEvent event) => _db
      .into(_db.contactEventRows)
      .insertOnConflictUpdate(event.toCompanion());

  /// Writes [event] **only if its id is not already there**, and says whether
  /// it did. Spec 11.7's once-per-session guard.
  ///
  /// The ringing screen and the background isolate reach the same trigger at
  /// the same instant, from two processes, against the same file. Reading and
  /// then writing would let both of them read "nothing yet"; this is one
  /// transaction, and sqlite serialises those across isolates on its own.
  ///
  /// A false is not an error — it is the other path having got there first,
  /// and the caller's whole job is then to do nothing at all.
  Future<bool> claim(ContactEvent event) => _db.transaction(() async {
    final existing = await (_db.select(
      _db.contactEventRows,
    )..where((e) => e.id.equals(event.id))).getSingleOrNull();
    if (existing != null) return false;
    await _db.into(_db.contactEventRows).insert(event.toCompanion());
    return true;
  });

  /// Newest first.
  Future<List<ContactEvent>> getRecent({int limit = 100}) async =>
      (await (_db.select(_db.contactEventRows)
                ..orderBy([
                  (e) => OrderingTerm(
                    expression: e.firedAtMs,
                    mode: OrderingMode.desc,
                  ),
                ])
                ..limit(limit))
              .get())
          .map((r) => r.toModel())
          .toList();

  Stream<List<ContactEvent>> watchRecent({int limit = 100}) =>
      (_db.select(_db.contactEventRows)
            ..orderBy([
              (e) => OrderingTerm(
                expression: e.firedAtMs,
                mode: OrderingMode.desc,
              ),
            ])
            ..limit(limit))
          .watch()
          .map((rows) => rows.map((r) => r.toModel()).toList());

  /// Live rows for one session. The ringing screen reads this so it can say
  /// 「田中太郎 に電話をかけました」 the moment the call really goes out.
  Stream<List<ContactEvent>> watchForSession(String sessionId) =>
      (_db.select(_db.contactEventRows)
            ..where((e) => e.sessionId.equals(sessionId)))
          .watch()
          .map((rows) => rows.map((r) => r.toModel()).toList());

  Future<List<ContactEvent>> forSession(String sessionId) async =>
      (await (_db.select(
            _db.contactEventRows,
          )..where((e) => e.sessionId.equals(sessionId))).get())
          .map((r) => r.toModel())
          .toList();
}
