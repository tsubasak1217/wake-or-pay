import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/app/usage_controller.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/data/repositories/usage_repository.dart';
import 'package:wake_or_pay/domain/models.dart';

import '../helpers.dart';

void main() {
  group('usageDayKey', () {
    test('is the local calendar day, zero padded', () {
      expect(usageDayKey(DateTime(2026, 8, 29, 23, 59)), '2026-08-29');
      expect(usageDayKey(DateTime(2026, 8, 30, 0, 1)), '2026-08-30');
      expect(usageDayKey(DateTime(2026, 12, 1)), '2026-12-01');
    });
  });

  group('UsageRepository', () {
    test('a first launch has nothing on record', () async {
      final repo = (await testContainer()).read(usageRepositoryProvider);
      expect(repo.read(), const UsageStats());
      expect(repo.read().firstOpenedAt, isNull);
    });

    test('the first open sets 開始日, and no later one moves it', () async {
      final repo = (await testContainer()).read(usageRepositoryProvider);

      final first = await repo.recordOpen(DateTime(2026, 8, 29, 9));
      expect(first.firstOpenedAt, DateTime(2026, 8, 29, 9));

      final later = await repo.recordOpen(DateTime(2026, 9, 30, 9));
      expect(later.firstOpenedAt, DateTime(2026, 8, 29, 9));
      expect(repo.read().firstOpenedAt, DateTime(2026, 8, 29, 9));
    });

    test('two opens on the same day are one login day', () async {
      final repo = (await testContainer()).read(usageRepositoryProvider);

      await repo.recordOpen(DateTime(2026, 8, 29, 7));
      expect(repo.read().loginDays, 1);

      await repo.recordOpen(DateTime(2026, 8, 29, 23, 59));
      expect(repo.read().loginDays, 1, reason: 'same calendar day');
      expect(repo.read().lastLoginDay, '2026-08-29');
    });

    test('the next day is a second login day', () async {
      final repo = (await testContainer()).read(usageRepositoryProvider);

      await repo.recordOpen(DateTime(2026, 8, 29, 23, 59));
      await repo.recordOpen(DateTime(2026, 8, 30, 0, 1));

      expect(repo.read().loginDays, 2);
      expect(repo.read().lastLoginDay, '2026-08-30');
    });

    test('a corrupt 開始日 reads as never opened rather than throwing', () async {
      final repo = (await testContainer(
        prefs: {UsageRepository.firstOpenedAtKey: 'not a date'},
      )).read(usageRepositoryProvider);

      expect(repo.read().firstOpenedAt, isNull);
      // …and the next open fills it in properly.
      final after = await repo.recordOpen(DateTime(2026, 8, 29));
      expect(after.firstOpenedAt, DateTime(2026, 8, 29));
    });
  });

  group('UsageTracker', () {
    test('merely reading it records nothing', () async {
      // The count belongs to the launch, not to whoever looks at it first: an
      // app opened straight into a ringing alarm never paints the profile, and
      // that morning is still a day the app was opened.
      final container = await testContainer();

      expect(container.read(usageProvider), const UsageStats());
      expect(container.read(usageProvider).loginDays, 0);
      expect(container.read(usageRepositoryProvider).read().loginDays, 0);
    });

    test('recordOpen writes through, and defaults to the injected clock',
        () async {
      final container = await testContainer();

      await container.read(usageProvider.notifier).recordOpen();

      expect(container.read(usageProvider).loginDays, 1);
      expect(container.read(usageProvider).firstOpenedAt, testNow);
      expect(
        container.read(usageRepositoryProvider).read().loginDays,
        1,
        reason: 'the next launch has to find it',
      );
    });

    test('a second start on the same day is still one login day', () async {
      final container = await testContainer();
      final tracker = container.read(usageProvider.notifier);

      await tracker.recordOpen(testNow);
      await tracker.recordOpen(testNow.add(const Duration(hours: 3)));
      expect(container.read(usageProvider).loginDays, 1);

      await tracker.recordOpen(testNow.add(const Duration(days: 1)));
      expect(container.read(usageProvider).loginDays, 2);
      expect(
        container.read(usageProvider).firstOpenedAt,
        testNow,
        reason: '開始日 is written once',
      );
    });
  });
}
