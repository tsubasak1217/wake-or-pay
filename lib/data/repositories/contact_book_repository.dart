import '../../domain/models.dart';
import '../database.dart';
import '../mappers.dart';

/// The in-app 連絡帳.
///
/// Ordering is done in Dart rather than in SQL: the sort key is
/// 「よみがな があればそれ、なければ名前」, which is a rule about the model, and
/// SQLite's `ORDER BY` would compare the raw columns instead. The book is a
/// handful of rows, so sorting them here costs nothing.
class ContactBookRepository {
  ContactBookRepository(this._db);

  final AppDatabase _db;

  Future<List<ContactEntry>> getAll() async => sortedContactEntries(
    (await _db.select(_db.contactBookRows).get()).map((r) => r.toModel()),
  );

  Stream<List<ContactEntry>> watchAll() => _db
      .select(_db.contactBookRows)
      .watch()
      .map((rows) => sortedContactEntries(rows.map((r) => r.toModel())));

  Future<ContactEntry?> getById(String id) async => (await (_db.select(
    _db.contactBookRows,
  )..where((c) => c.id.equals(id))).getSingleOrNull())?.toModel();

  Future<void> save(ContactEntry entry) =>
      _db.into(_db.contactBookRows).insertOnConflictUpdate(entry.toCompanion());

  /// Deleting somebody from the book never touches an alarm: the alarm holds a
  /// snapshot of the name and addresses, so it keeps working with what it has.
  Future<void> delete(String id) =>
      (_db.delete(_db.contactBookRows)..where((c) => c.id.equals(id))).go();
}
