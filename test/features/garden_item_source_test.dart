import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/garden_catalog.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/features/garden/item_source.dart';

import '../helpers.dart';

void main() {
  test('acquiring spends tokens and adds the item to the shelf', () async {
    final container = await testContainer();
    await container
        .read(walletRepositoryProvider)
        .write(const Wallet(coins: 5000, tokens: 100));

    final ok = await container
        .read(gardenItemSourceProvider)
        .acquire(GardenCatalog.moss);

    expect(ok, isTrue);
    final wallet = await container.read(walletRepositoryProvider).read();
    expect(wallet.tokens, 70);
    expect(wallet.coins, 5000, reason: 'coins buy nothing in the garden');
    expect(
      (await container.read(gardenRepositoryProvider).read()).inventory.countOf(
        'plant_moss',
      ),
      1,
    );
  });

  test('a short balance changes nothing at all', () async {
    final container = await testContainer();
    await container
        .read(walletRepositoryProvider)
        .write(const Wallet(coins: 999999, tokens: 29));

    final ok = await container
        .read(gardenItemSourceProvider)
        .acquire(GardenCatalog.moss);

    expect(ok, isFalse);
    expect((await container.read(walletRepositoryProvider).read()).tokens, 29);
    expect(
      (await container.read(gardenRepositoryProvider).read()).inventory.owned,
      isEmpty,
    );
  });

  test('the source is the only thing the shop offers', () async {
    final container = await testContainer();
    final source = container.read(gardenItemSourceProvider);
    expect(source.offers(), GardenCatalog.purchasable);
    expect(
      source.canAcquire(GardenCatalog.moss, const Wallet(tokens: 30)),
      isTrue,
    );
    expect(
      source.canAcquire(GardenCatalog.moss, const Wallet(coins: 100000)),
      isFalse,
    );
  });
}
