import 'package:drift/drift.dart';

import '../../domain/models.dart';
import '../database.dart';

class OjisanRepository {
  OjisanRepository(this._db);

  static const _rowId = 0;

  final AppDatabase _db;

  OjisanState _toModel(OjisanRow? row) => row == null
      ? const OjisanState()
      : OjisanState(
          totalOversleeps: row.totalOversleeps,
          totalEarned: row.totalEarned,
        );

  Future<OjisanState> read() async => _toModel(
    await (_db.select(
      _db.ojisanRows,
    )..where((o) => o.id.equals(_rowId))).getSingleOrNull(),
  );

  Stream<OjisanState> watch() => (_db.select(
    _db.ojisanRows,
  )..where((o) => o.id.equals(_rowId))).watchSingleOrNull().map(_toModel);

  Future<void> write(OjisanState state) => _db
      .into(_db.ojisanRows)
      .insertOnConflictUpdate(
        OjisanRowsCompanion(
          id: const Value(_rowId),
          totalOversleeps: Value(state.totalOversleeps),
          totalEarned: Value(state.totalEarned),
        ),
      );

  Future<OjisanState> update(
    OjisanState Function(OjisanState current) change,
  ) => _db.transaction(() async {
    final next = change(await read());
    await write(next);
    return next;
  });
}
