import 'package:drift/drift.dart';

import '../../domain/models.dart';
import '../database.dart';
import '../mappers.dart';

/// The local 請求台帳: what the registered card owes, and nothing that talks to
/// a network.
///
/// Phase 1 charges nothing. This is the record Phase 3 will sync — see
/// `docs/BILLING_API.md` — so the one property that matters here is that a ring
/// can never be written twice: [insertIfAbsent] does nothing when the session
/// already has a charge, which is what makes settling twice safe.
class PendingChargeRepository {
  PendingChargeRepository(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$PendingChargeRowsTable, PendingChargeRow>
  get _ordered =>
      _db.select(_db.pendingChargeRows)
        ..orderBy([(c) => OrderingTerm(expression: c.createdAtMs)]);

  Future<List<PendingCharge>> getAll() async =>
      (await _ordered.get()).map((r) => r.toModel()).toList();

  Stream<List<PendingCharge>> watchAll() =>
      _ordered.watch().map((rows) => rows.map((r) => r.toModel()).toList());

  Future<PendingCharge?> getBySessionId(String sessionId) async =>
      (await (_db.select(_db.pendingChargeRows)
                ..where((c) => c.sessionId.equals(sessionId)))
              .getSingleOrNull())
          ?.toModel();

  /// Writes [charge] unless its session already has one. Answers whether it
  /// wrote.
  ///
  /// `DO NOTHING`, not an upsert: a second settle of the same ring must leave
  /// the first amount exactly as it was rather than overwrite it with whatever
  /// the recovery pass recomputed.
  Future<bool> insertIfAbsent(PendingCharge charge) async {
    // `insertReturningOrNull` answers null exactly when the row was ignored,
    // which is the fact the caller needs — `insert` answers a rowid either way.
    final written = await _db
        .into(_db.pendingChargeRows)
        .insertReturningOrNull(
          charge.toCompanion(),
          mode: InsertMode.insertOrIgnore,
        );
    return written != null;
  }

  /// Every charge whose session id starts with [prefix] — the開発用 sample
  /// data's way back out. See [AlarmSessionRepository.deleteWithIdPrefix].
  Future<void> deleteWithSessionIdPrefix(String prefix) =>
      (_db.delete(_db.pendingChargeRows)
            ..where((c) => c.sessionId.like('$prefix%')))
          .go();

  /// Moves one charge to [status]. Phase 3's half of the ledger; nothing calls
  /// it yet.
  Future<void> mark(String sessionId, PendingChargeStatus status) =>
      (_db.update(_db.pendingChargeRows)
            ..where((c) => c.sessionId.equals(sessionId)))
          .write(PendingChargeRowsCompanion(status: Value(status.name)));
}
