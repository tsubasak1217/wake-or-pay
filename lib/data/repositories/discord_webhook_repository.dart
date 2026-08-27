import 'package:drift/drift.dart';

import '../../domain/models.dart';
import '../database.dart';
import '../mappers.dart';

/// The app-wide Discord 共有先 list.
///
/// Ordered by when it was registered rather than by name: the list is short,
/// and a list that reorders itself when somebody renames a row is harder to
/// find things in than one that never moves.
///
/// Deleting a 共有先 never touches an alarm. An alarm holds ids, and an id with
/// no row behind it is skipped when the list is read — the same no-foreign-key
/// rule the 連絡帳 follows, for the same reason.
class DiscordWebhookRepository {
  DiscordWebhookRepository(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$DiscordWebhookRowsTable, DiscordWebhookRow>
  get _ordered =>
      _db.select(_db.discordWebhookRows)
        ..orderBy([(w) => OrderingTerm(expression: w.createdAtMs)]);

  Future<List<DiscordWebhook>> getAll() async =>
      (await _ordered.get()).map((r) => r.toModel()).toList();

  Stream<List<DiscordWebhook>> watchAll() =>
      _ordered.watch().map((rows) => rows.map((r) => r.toModel()).toList());

  Future<DiscordWebhook?> getById(String id) async => (await (_db.select(
    _db.discordWebhookRows,
  )..where((w) => w.id.equals(id))).getSingleOrNull())?.toModel();

  Future<void> save(DiscordWebhook webhook) => _db
      .into(_db.discordWebhookRows)
      .insertOnConflictUpdate(webhook.toCompanion());

  Future<void> delete(String id) =>
      (_db.delete(_db.discordWebhookRows)..where((w) => w.id.equals(id))).go();
}
