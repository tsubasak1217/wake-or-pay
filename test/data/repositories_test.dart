import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/app/theme.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';

import '../helpers.dart';

void main() {
  const kakugo = Kakugo(ratePerMinute: 100, cap: 2000);

  group('ContactBookRepository', () {
    ContactEntry entry(
      String id,
      String name, {
      String? reading,
      int day = 1,
    }) => ContactEntry(
      id: id,
      name: name,
      reading: reading,
      phone: '090-0000-0000',
      createdAt: DateTime(2026, 1, day),
    );

    test('save, read back in よみがな order, update and delete', () async {
      final repo = (await testContainer()).read(contactBookRepositoryProvider);

      await repo.save(entry('c1', '田中太郎', reading: 'たなかたろう'));
      await repo.save(entry('c2', '佐藤花子', reading: 'さとうはなこ', day: 2));
      expect((await repo.getAll()).map((e) => e.id), ['c2', 'c1']);
      expect((await repo.getById('c1'))!.name, '田中太郎');

      await repo.save(
        (await repo.getById('c1'))!.copyWith(name: '田中', clearReading: true),
      );
      final updated = await repo.getById('c1');
      expect(updated!.name, '田中');
      expect(updated.reading, isNull);
      expect(await repo.getAll(), hasLength(2));

      await repo.delete('c1');
      expect(await repo.getById('c1'), isNull);
      expect((await repo.getAll()).single.id, 'c2');
    });

    test('an entry with no よみがな sorts by its name', () async {
      final repo = (await testContainer()).read(contactBookRepositoryProvider);
      await repo.save(entry('c1', 'あ'));
      await repo.save(entry('c2', 'い', reading: 'あああ'));
      expect((await repo.getAll()).map((e) => e.id), [
        'c1',
        'c2',
      ], reason: '「あ」 before 「あああ」');
    });
  });

  group('AlarmRepository', () {
    test('save, read back, update and delete', () async {
      final repo = (await testContainer()).read(alarmRepositoryProvider);

      const alarm = Alarm(
        id: 'a1',
        hour: 7,
        minute: 5,
        repeatDays: {1, 3, 5},
        wakeCheck: WakeCheckType.math,
        kakugo: kakugo,
      );
      await repo.save(alarm);

      expect(await repo.getById('a1'), alarm);
      expect(await repo.getAll(), [alarm]);

      await repo.save(alarm.copyWith(hour: 6, clearKakugo: true));
      final updated = await repo.getById('a1');
      expect(updated!.hour, 6);
      expect(updated.kakugo, isNull);
      expect(await repo.getAll(), hasLength(1));

      await repo.delete('a1');
      expect(await repo.getById('a1'), isNull);
      expect(await repo.getAll(), isEmpty);
    });

    test('the grace window round trips and defaults to one minute', () async {
      final repo = (await testContainer()).read(alarmRepositoryProvider);
      await repo.save(const Alarm(id: 'plain', hour: 7, minute: 0));
      expect((await repo.getById('plain'))!.graceMinutes, 1);

      await repo.save(
        const Alarm(id: 'slow', hour: 7, minute: 0, graceMinutes: 5),
      );
      expect((await repo.getById('slow'))!.graceMinutes, 5);
    });

    test('every wake check, ノーマル included, round trips by name', () async {
      final repo = (await testContainer()).read(alarmRepositoryProvider);
      for (final type in WakeCheckType.values) {
        await repo.save(
          Alarm(id: type.name, hour: 7, minute: 0, wakeCheck: type),
        );
        expect(
          (await repo.getById(type.name))!.wakeCheck,
          type,
          reason: type.name,
        );
      }
    });

    test('a one-shot alarm round trips with no repeat days', () async {
      final repo = (await testContainer()).read(alarmRepositoryProvider);
      const alarm = Alarm(id: 'a1', hour: 23, minute: 59);
      await repo.save(alarm);
      expect((await repo.getById('a1'))!.repeatDays, isEmpty);
    });

    test('listed in time order', () async {
      final repo = (await testContainer()).read(alarmRepositoryProvider);
      await repo.save(const Alarm(id: 'late', hour: 9, minute: 0));
      await repo.save(const Alarm(id: 'early', hour: 6, minute: 30));
      await repo.save(const Alarm(id: 'mid', hour: 6, minute: 45));

      expect((await repo.getAll()).map((a) => a.id), ['early', 'mid', 'late']);
    });

    test('setEnabled toggles without rewriting the rest', () async {
      final repo = (await testContainer()).read(alarmRepositoryProvider);
      await repo.save(
        const Alarm(id: 'a1', hour: 7, minute: 0, kakugo: kakugo),
      );
      await repo.setEnabled('a1', false);
      final a = await repo.getById('a1');
      expect(a!.enabled, isFalse);
      expect(a.kakugo, kakugo);
    });

    test('watchAll emits on change', () async {
      final repo = (await testContainer()).read(alarmRepositoryProvider);
      expect(await repo.watchAll().first, isEmpty);

      final done = expectLater(repo.watchAll(), emitsThrough(hasLength(1)));
      await repo.save(const Alarm(id: 'a1', hour: 7, minute: 0));
      await done;
    });
  });

  group('AlarmSessionRepository', () {
    final firedAt = DateTime(2026, 8, 27, 7, 0, 30);

    test('save and read back with the kakugo snapshot intact', () async {
      final repo = (await testContainer()).read(alarmSessionRepositoryProvider);
      final session = AlarmSession(
        id: 's1',
        alarmId: 'a1',
        firedAt: firedAt,
        kakugoSnapshot: kakugo,
        coinsAtFire: 1200,
        graceMinutes: 3,
      );
      await repo.save(session);

      final back = await repo.getById('s1');
      expect(back, session);
      expect(back!.firedAt, firedAt, reason: 'seconds must survive');
      expect(back.graceMinutes, 3);
    });

    test('getRinging finds the newest ringing session only', () async {
      final repo = (await testContainer()).read(alarmSessionRepositoryProvider);
      await repo.save(
        AlarmSession(
          id: 'old',
          alarmId: 'a1',
          firedAt: firedAt.subtract(const Duration(days: 1)),
          status: SessionStatus.failed,
          loss: 500,
        ),
      );
      expect(await repo.getRinging(), isNull);

      await repo.save(
        AlarmSession(id: 'stale', alarmId: 'a1', firedAt: firedAt),
      );
      await repo.save(
        AlarmSession(
          id: 'live',
          alarmId: 'a1',
          firedAt: firedAt.add(const Duration(hours: 2)),
        ),
      );

      expect((await repo.getRinging())!.id, 'live');
      expect((await repo.getRingingAll()).map((s) => s.id), ['stale', 'live']);
    });

    test('history is newest first and honours the limit', () async {
      final repo = (await testContainer()).read(alarmSessionRepositoryProvider);
      for (var i = 0; i < 5; i++) {
        await repo.save(
          AlarmSession(
            id: 's$i',
            alarmId: 'a1',
            firedAt: firedAt.add(Duration(days: i)),
            status: SessionStatus.success,
          ),
        );
      }
      expect((await repo.getRecent()).map((s) => s.id), [
        's4',
        's3',
        's2',
        's1',
        's0',
      ]);
      expect((await repo.getRecent(limit: 2)).map((s) => s.id), ['s4', 's3']);
    });

    test('saving the same id settles the existing session', () async {
      final repo = (await testContainer()).read(alarmSessionRepositoryProvider);
      final session = AlarmSession(id: 's1', alarmId: 'a1', firedAt: firedAt);
      await repo.save(session);
      await repo.save(
        session.copyWith(
          status: SessionStatus.failed,
          loss: 700,
          dismissedAt: firedAt.add(const Duration(minutes: 7)),
        ),
      );

      expect(await repo.getRecent(), hasLength(1));
      final back = await repo.getById('s1');
      expect(back!.status, SessionStatus.failed);
      expect(back.loss, 700);
      expect(await repo.getRinging(), isNull);
    });

    test('delete removes it', () async {
      final repo = (await testContainer()).read(alarmSessionRepositoryProvider);
      await repo.save(AlarmSession(id: 's1', alarmId: 'a1', firedAt: firedAt));
      await repo.delete('s1');
      expect(await repo.getById('s1'), isNull);
    });
  });

  group('WalletRepository', () {
    test('an untouched wallet reads as empty', () async {
      final repo = (await testContainer()).read(walletRepositoryProvider);
      expect(await repo.read(), const Wallet());
    });

    test('write then read', () async {
      final repo = (await testContainer()).read(walletRepositoryProvider);
      await repo.write(const Wallet(coins: 1000, tokens: 20));
      expect(await repo.read(), const Wallet(coins: 1000, tokens: 20));
    });

    test('update applies to the stored value and returns it', () async {
      final repo = (await testContainer()).read(walletRepositoryProvider);
      await repo.write(const Wallet(coins: 1000, tokens: 20));

      final next = await repo.update(
        (w) => w.copyWith(coins: w.coins - 300, tokens: w.tokens + 10),
      );
      expect(next, const Wallet(coins: 700, tokens: 30));
      expect(await repo.read(), next);
    });

    test('watch emits the current value and then updates', () async {
      final repo = (await testContainer()).read(walletRepositoryProvider);
      expect(await repo.watch().first, const Wallet());

      final done = expectLater(
        repo.watch(),
        emitsThrough(const Wallet(coins: 500)),
      );
      await repo.write(const Wallet(coins: 500));
      await done;
    });
  });

  group('OjisanRepository', () {
    test('starts empty, accumulates', () async {
      final repo = (await testContainer()).read(ojisanRepositoryProvider);
      expect(await repo.read(), const OjisanState());

      await repo.update(
        (o) => o.copyWith(
          totalOversleeps: o.totalOversleeps + 1,
          totalEarned: o.totalEarned + 700,
        ),
      );
      await repo.update(
        (o) => o.copyWith(
          totalOversleeps: o.totalOversleeps + 1,
          totalEarned: o.totalEarned + 300,
        ),
      );

      expect(
        await repo.read(),
        const OjisanState(totalOversleeps: 2, totalEarned: 1000),
      );
    });
  });

  group('SettingsRepository', () {
    test('defaults on first launch', () async {
      final repo = (await testContainer()).read(settingsRepositoryProvider);
      final s = repo.read();
      expect(s.themeId, AppThemes.defaultThemeId);
      expect(s.unlockedThemeIds, {AppThemes.defaultThemeId});
    });

    test('reads what was stored, default theme always unlocked', () async {
      final repo = (await testContainer(
        prefs: {
          'settings.themeId': AppThemes.sunrise.id,
          'settings.unlockedThemeIds': [AppThemes.sunrise.id],
        },
      )).read(settingsRepositoryProvider);

      final s = repo.read();
      expect(s.themeId, AppThemes.sunrise.id);
      expect(s.unlockedThemeIds, {
        AppThemes.defaultThemeId,
        AppThemes.sunrise.id,
      });
    });

    test('write then read back', () async {
      final repo = (await testContainer()).read(settingsRepositoryProvider);
      await repo.write(
        Settings(
          themeId: AppThemes.forest.id,
          unlockedThemeIds: {AppThemes.defaultThemeId, AppThemes.forest.id},
        ),
      );
      expect(repo.read().themeId, AppThemes.forest.id);
      expect(repo.read().unlockedThemeIds, contains(AppThemes.forest.id));
    });
  });
}
