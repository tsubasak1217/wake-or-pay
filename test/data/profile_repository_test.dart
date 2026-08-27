import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/domain/profile_catalog.dart';

import '../helpers.dart';

void main() {
  group('ProfileRepository', () {
    test('defaults on a first launch: no name, everything owned', () async {
      final repo = (await testContainer()).read(profileRepositoryProvider);
      final p = repo.read();

      expect(p.userName, '');
      expect(p.discordUserId, '');
      expect(p.xp, 0);
      expect(p.iconId, ProfileCatalog.defaultIconId);
      expect(p.plateBackgroundId, ProfileCatalog.defaultPlateBackgroundId);
      expect(p.frameId, ProfileCatalog.defaultFrameId);
      expect(p.ownedIconIds, ProfileCatalog.allIconIds);
      expect(p.ownedPlateBackgroundIds, ProfileCatalog.allPlateBackgroundIds);
      expect(p.ownedFrameIds, ProfileCatalog.allFrameIds);
    });

    test('an install that only ever had settings.userName keeps it', () async {
      final container = await testContainer(
        prefs: {'settings.userName': '山田花子'},
      );
      final repo = container.read(profileRepositoryProvider);

      expect(repo.read().userName, '山田花子');

      await repo.update((p) => p.copyWith(userName: '田中太郎'));
      expect(repo.read().userName, '田中太郎', reason: 'the new key wins');
      expect(
        container.read(sharedPreferencesProvider).getString('settings.userName'),
        '山田花子',
        reason: 'the old key is left for a downgrade to find',
      );
    });

    test('an empty new name wins over the legacy one', () async {
      // Clearing the name has to stick: falling back to the old key here would
      // resurrect a name the user just deleted.
      final repo = (await testContainer(
        prefs: {'settings.userName': '山田花子'},
      )).read(profileRepositoryProvider);

      await repo.update((p) => p.copyWith(userName: ''));
      expect(repo.read().userName, '');
    });

    test('everything survives a round trip', () async {
      final repo = (await testContainer()).read(profileRepositoryProvider);
      final written = await repo.update(
        (p) => p.copyWith(
          userName: '山田花子',
          discordUserId: '123456789',
          xp: 1234,
          iconId: 'sun',
          plateBackgroundId: 'plate_dawn',
          frameId: 'frame_thick',
          ownedIconIds: {'sun'},
        ),
      );

      expect(repo.read(), written);
      expect(repo.read().ownedIconIds, {'sun'});
      expect(repo.read().xp, 1234);
    });

    test('a Discord ID is stored digits only', () async {
      final repo = (await testContainer()).read(profileRepositoryProvider);
      final p = await repo.update((p) => p.copyWith(discordUserId: '<@123>'));

      expect(p.discordUserId, '123');
      expect(repo.read().discordUserId, '123');
    });

    test('an unknown cosmetic id survives the read and falls back', () async {
      // A row written by a future version, opened by this one.
      final repo = (await testContainer(
        prefs: {'profile.iconId': 'from_the_future'},
      )).read(profileRepositoryProvider);

      expect(repo.read().iconId, 'from_the_future');
      expect(
        ProfileCatalog.iconById(repo.read().iconId).id,
        ProfileCatalog.defaultIconId,
      );
    });
  });

  group('normalizeDiscordUserId', () {
    test('keeps only digits', () {
      expect(normalizeDiscordUserId(''), '');
      expect(normalizeDiscordUserId('   '), '');
      expect(normalizeDiscordUserId('<@123>'), '123');
      expect(normalizeDiscordUserId('<@!123456789012345678>'), '123456789012345678');
      expect(normalizeDiscordUserId('123'), '123');
      expect(normalizeDiscordUserId('abc'), '');
      expect(normalizeDiscordUserId('1 2-3'), '123');
    });
  });
}
