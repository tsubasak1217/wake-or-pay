import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/data/repositories/alarm_session_repository.dart';
import 'package:wake_or_pay/data/repositories/ojisan_repository.dart';
import 'package:wake_or_pay/data/repositories/wallet_repository.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/services/alarm_service.dart';
import 'package:wake_or_pay/domain/wake_check.dart';
import 'package:wake_or_pay/services/session_service.dart';

import '../helpers.dart';

typedef Fixture = ({
  SessionService service,
  WalletRepository wallet,
  OjisanRepository ojisan,
  AlarmSessionRepository sessions,
});

void main() {
  const kakugo = Kakugo(ratePerMinute: 100, cap: 2000);
  const alarm = Alarm(id: 'a1', hour: 7, minute: 0, kakugo: kakugo);
  final firedAt = DateTime(2026, 8, 27, 7);

  Future<Fixture> setUpService({int coins = 5000}) async {
    final container = await testContainer();
    final wallet = container.read(walletRepositoryProvider);
    await wallet.write(Wallet(coins: coins));
    return (
      service: container.read(sessionServiceProvider),
      wallet: wallet,
      ojisan: container.read(ojisanRepositoryProvider),
      sessions: container.read(alarmSessionRepositoryProvider),
    );
  }

  test('a random alarm draws its check once, at fire time', () async {
    final container = await testContainer();
    await container.read(walletRepositoryProvider).write(const Wallet());
    final sessions = container.read(alarmSessionRepositoryProvider);
    // A fixed seed, so the draw is checked rather than guessed at.
    final service = SessionService(
      sessions,
      container.read(walletRepositoryProvider),
      container.read(ojisanRepositoryProvider),
      random: Random(42),
    );

    const randomAlarm = Alarm(
      id: 'a1',
      hour: 7,
      minute: 0,
      wakeCheck: WakeCheckType.random,
    );
    final session = await service.start(alarm: randomAlarm, firedAt: firedAt);

    expect(session.wakeCheckResolved, isNotNull);
    expect(randomWakeCheckPool, contains(session.wakeCheckResolved));
    expect(
      (await sessions.getById(session.id))!.wakeCheckResolved,
      session.wakeCheckResolved,
      reason: 'a relaunch mid-ring finds the same check waiting',
    );
  });

  test('a chosen check is not a draw and is not written down', () async {
    final s = await setUpService();
    final session = await s.service.start(alarm: alarm, firedAt: firedAt);
    expect(session.wakeCheckResolved, isNull);
    expect((await s.sessions.getById(session.id))!.wakeCheckResolved, isNull);
  });

  test('start freezes the pledge and the balance', () async {
    final s = await setUpService(coins: 1234);
    final session = await s.service.start(alarm: alarm, firedAt: firedAt);

    expect(session.status, SessionStatus.ringing);
    expect(session.kakugoSnapshot, kakugo);
    expect(session.coinsAtFire, 1234);
    expect(await s.sessions.getById(session.id), session);
  });

  test(
    'spending coins after the ring does not change what is at stake',
    () async {
      final s = await setUpService(coins: 1000);
      final session = await s.service.start(alarm: alarm, firedAt: firedAt);
      await s.wallet.write(const Wallet(coins: 50));

      final settled = await s.service.dismiss(
        session,
        firedAt.add(const Duration(minutes: 5)),
      );
      expect(settled.loss, 500);
    },
  );

  test(
    'a dismissal inside the first minute pays tokens, not the ojisan',
    () async {
      final s = await setUpService();
      final session = await s.service.start(alarm: alarm, firedAt: firedAt);

      final settled = await s.service.dismiss(
        session,
        firedAt.add(const Duration(seconds: 59)),
      );

      expect(settled.status, SessionStatus.success);
      expect(settled.loss, 0);
      expect(await s.wallet.read(), const Wallet(coins: 5000, tokens: 20));
      expect(await s.ojisan.read(), const OjisanState());
    },
  );

  test('a late dismissal burns coins and feeds the ojisan', () async {
    final s = await setUpService();
    final session = await s.service.start(alarm: alarm, firedAt: firedAt);

    final settled = await s.service.dismiss(
      session,
      firedAt.add(const Duration(minutes: 7)),
    );

    expect(settled.status, SessionStatus.failed);
    expect(settled.loss, 700);
    expect(await s.wallet.read(), const Wallet(coins: 4300));
    expect(
      await s.ojisan.read(),
      const OjisanState(totalOversleeps: 1, totalEarned: 700),
    );
  });

  test('an empty wallet still counts as an oversleep for the ojisan', () async {
    final s = await setUpService(coins: 0);
    final session = await s.service.start(alarm: alarm, firedAt: firedAt);

    final settled = await s.service.dismiss(
      session,
      firedAt.add(const Duration(minutes: 5)),
    );

    expect(settled.status, SessionStatus.failed);
    expect(settled.loss, 0);
    expect((await s.wallet.read()).coins, 0);
    expect(
      await s.ojisan.read(),
      const OjisanState(totalOversleeps: 1, totalEarned: 0),
    );
  });

  test('a plain alarm failure does not grow the ojisan', () async {
    final s = await setUpService();
    const plain = Alarm(id: 'a2', hour: 7, minute: 0);
    final session = await s.service.start(alarm: plain, firedAt: firedAt);

    final settled = await s.service.dismiss(
      session,
      firedAt.add(const Duration(minutes: 30)),
    );

    expect(settled.status, SessionStatus.failed);
    expect(await s.ojisan.read(), const OjisanState());
    // Recorded in the history all the same.
    expect((await s.sessions.getRecent()).single.status, SessionStatus.failed);
    // A failure pays no tokens.
    expect((await s.wallet.read()).tokens, 0);
  });

  test('a plain alarm cleared in time still pays the base tokens', () async {
    final s = await setUpService();
    const plain = Alarm(id: 'a2', hour: 7, minute: 0);
    final session = await s.service.start(alarm: plain, firedAt: firedAt);

    final settled = await s.service.dismiss(
      session,
      firedAt.add(const Duration(seconds: 59)),
    );

    expect(settled.status, SessionStatus.success);
    expect((await s.wallet.read()).tokens, 10);
  });

  test('settling twice charges once', () async {
    final s = await setUpService();
    final session = await s.service.start(alarm: alarm, firedAt: firedAt);
    final at = firedAt.add(const Duration(minutes: 7));

    await s.service.dismiss(session, at);
    final again = await s.service.dismiss(session, at);

    expect(again.loss, 700);
    expect((await s.wallet.read()).coins, 4300);
    expect((await s.ojisan.read()).totalOversleeps, 1);
  });

  group('recoverPending', () {
    test('nothing pending', () async {
      final s = await setUpService();
      final outcome = await s.service.recoverPending(firedAt);
      expect(outcome.isEmpty, isTrue);
    });

    test('inside the hour: resume, charge nothing yet', () async {
      final s = await setUpService();
      final session = await s.service.start(alarm: alarm, firedAt: firedAt);

      final outcome = await s.service.recoverPending(
        firedAt.add(const Duration(minutes: 59, seconds: 59)),
      );

      expect(outcome.resumed!.id, session.id);
      expect(outcome.settled, isEmpty);
      expect((await s.wallet.read()).coins, 5000);
    });

    test('past the hour: written off as failed at the deadline', () async {
      final s = await setUpService();
      await s.service.start(alarm: alarm, firedAt: firedAt);

      final outcome = await s.service.recoverPending(
        firedAt.add(const Duration(hours: 9)),
      );

      expect(outcome.resumed, isNull);
      expect(outcome.settled, hasLength(1));
      expect(outcome.settled.first.status, SessionStatus.failed);
      expect(outcome.settled.first.loss, 2000); // capped
      expect(
        outcome.settled.first.dismissedAt,
        firedAt.add(const Duration(minutes: 60)),
      );
      expect((await s.wallet.read()).coins, 3000);
      expect((await s.ojisan.read()).totalOversleeps, 1);
    });

    test('a stale session is settled while the live one resumes', () async {
      final s = await setUpService();
      final stale = await s.service.start(alarm: alarm, firedAt: firedAt);
      final live = await s.service.start(
        alarm: alarm,
        firedAt: firedAt.add(const Duration(hours: 3)),
      );

      final outcome = await s.service.recoverPending(
        firedAt.add(const Duration(hours: 3, minutes: 5)),
      );

      expect(outcome.resumed!.id, live.id);
      expect(outcome.settled.map((x) => x.id), [stale.id]);
      expect((await s.ojisan.read()).totalOversleeps, 1);
    });

    test('recovery does not re-charge an already settled session', () async {
      final s = await setUpService();
      await s.service.start(alarm: alarm, firedAt: firedAt);
      await s.service.recoverPending(firedAt.add(const Duration(hours: 9)));
      await s.service.recoverPending(firedAt.add(const Duration(hours: 9)));

      expect((await s.wallet.read()).coins, 3000);
      expect((await s.ojisan.read()).totalOversleeps, 1);
    });
  });
}
