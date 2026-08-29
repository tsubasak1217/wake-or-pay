import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/data/repositories/options_repository.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/services/options.dart';

import '../helpers.dart';

Future<OptionsRepository> repository([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues({...prefs});
  return OptionsRepository(await SharedPreferences.getInstance());
}

void main() {
  group('OptionsRepository', () {
    test('an empty store reads as the out-of-the-box ceiling', () async {
      expect((await repository()).read().capCeiling, maxKakugoCap);
      expect(const Options().capCeiling, maxKakugoCap);
    });

    test('what is written is what is read back', () async {
      final repo = await repository();
      await repo.write(const Options(capCeiling: 100000));
      expect(repo.read().capCeiling, 100000);

      // And off a second instance over the same store: the next launch has to
      // find the same answer.
      final reread = OptionsRepository(await SharedPreferences.getInstance());
      expect(reread.read().capCeiling, 100000);
    });

    test('any stored number reads back as itself — it is free input', () async {
      final repo = await repository({OptionsRepository.capCeilingKey: 12345});
      expect(repo.read().capCeiling, 12345);

      final round = await repository({
        OptionsRepository.capCeilingKey: 100000,
      });
      expect(round.read().capCeiling, 100000);
    });

    test('a stored value outside the bounds reads clamped', () async {
      final huge = await repository({
        OptionsRepository.capCeilingKey: 5000000,
      });
      expect(huge.read().capCeiling, absoluteMaxKakugoCap);

      final zero = await repository({OptionsRepository.capCeilingKey: 0});
      expect(zero.read().capCeiling, 1);
    });
  });

  test('the provider reads the store and writes through it', () async {
    final container = await testContainer();

    expect(container.read(capCeilingProvider), maxKakugoCap);

    await container.read(optionsProvider.notifier).setCapCeiling(30000);
    expect(container.read(capCeilingProvider), 30000);
    expect(
      OptionsRepository(container.read(sharedPreferencesProvider))
          .read()
          .capCeiling,
      30000,
    );
  });
}
