import 'package:drift/drift.dart';

import '../../domain/models.dart';
import '../database.dart';

/// Single-row store. Reads of a wallet that was never written return the empty
/// wallet rather than null, so callers never special-case first launch.
class WalletRepository {
  WalletRepository(this._db);

  static const _rowId = 0;

  final AppDatabase _db;

  Future<Wallet> read() async {
    final row = await (_db.select(
      _db.walletRows,
    )..where((w) => w.id.equals(_rowId))).getSingleOrNull();
    return row == null
        ? const Wallet()
        : Wallet(coins: row.coins, tokens: row.tokens);
  }

  Stream<Wallet> watch() =>
      (_db.select(
        _db.walletRows,
      )..where((w) => w.id.equals(_rowId))).watchSingleOrNull().map(
        (row) => row == null
            ? const Wallet()
            : Wallet(coins: row.coins, tokens: row.tokens),
      );

  Future<void> write(Wallet wallet) => _db
      .into(_db.walletRows)
      .insertOnConflictUpdate(
        WalletRowsCompanion(
          id: const Value(_rowId),
          coins: Value(wallet.coins),
          tokens: Value(wallet.tokens),
        ),
      );

  /// Read-modify-write in one transaction, so a burn and a reward cannot
  /// clobber each other.
  Future<Wallet> update(Wallet Function(Wallet current) change) =>
      _db.transaction(() async {
        final next = change(await read());
        await write(next);
        return next;
      });
}
