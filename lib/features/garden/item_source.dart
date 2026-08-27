import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/garden.dart';
import '../../domain/garden_catalog.dart';
import '../../domain/models.dart';

/// The one seam through which items enter the garden.
///
/// The seed shop behind it is a placeholder: acquisition is meant to become a
/// game later. Everything else — the shelf, the grid, the garden screen — only
/// ever reads the inventory, so replacing this class is the whole change.
/// Whatever replaces it must keep the two rules it enforces:
/// coins never buy anything, and nothing is unlocked by watching or paying.
abstract class GardenItemSource {
  /// What the shop offers right now.
  List<GardenItemDef> offers();

  /// Whether [def] can be taken with the current balance.
  bool canAcquire(GardenItemDef def, Wallet wallet);

  /// Takes one copy of [def]. Returns false and changes nothing when it cannot
  /// be afforded.
  Future<bool> acquire(GardenItemDef def);
}

/// Placeholder source: the whole catalogue, priced in reward tokens.
class SeedShopItemSource implements GardenItemSource {
  SeedShopItemSource(this._ref);

  final Ref _ref;

  @override
  List<GardenItemDef> offers() => GardenCatalog.purchasable;

  @override
  bool canAcquire(GardenItemDef def, Wallet wallet) =>
      exchange(const GardenInventory(), wallet, def) != null;

  @override
  Future<bool> acquire(GardenItemDef def) async {
    final garden = _ref.read(gardenRepositoryProvider);
    final wallets = _ref.read(walletRepositoryProvider);

    // Priced from the wallet as it is inside the transaction, not from the
    // copy the screen was rendered with, so a reward landing mid-tap cannot be
    // clobbered and a stale balance cannot buy on credit.
    var charged = false;
    await wallets.update((w) {
      final result = exchange(const GardenInventory(), w, def);
      if (result == null) return w;
      charged = true;
      return result.wallet;
    });
    if (!charged) return false;

    // Tokens first: a crash between the two leaves the player poorer by the
    // price but never with a free item, which is the safer half to lose.
    await garden.update((s) => s.copyWith(inventory: s.inventory.add(def.id)));
    return true;
  }
}

final gardenItemSourceProvider = Provider<GardenItemSource>(
  (ref) => SeedShopItemSource(ref),
);
