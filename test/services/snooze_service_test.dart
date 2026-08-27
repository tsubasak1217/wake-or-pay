import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/loss_calculator.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/services/alarm_service.dart';

import '../helpers.dart';

void main() {
  const kakugo = Kakugo(ratePerMinute: 100, cap: 10000, snoozePenalty: 50);
  const snoozable = Alarm(
    id: 'a1',
    hour: 7,
    minute: 0,
    repeatDays: {1, 2, 3, 4, 5},
    snooze: Snooze(intervalMinutes: 5, maxCount: 2),
    kakugo: kakugo,
  );
  const unsnoozable = Alarm(id: 'a2', hour: 7, minute: 0, kakugo: kakugo);

  final firedAt = DateTime(2026, 8, 27, 7);
  DateTime at({int minutes = 0}) => firedAt.add(Duration(minutes: minutes));

  Future<({FakeAlarmService service, ProviderContainer container, String id})>
  ringing(Alarm alarm) async {
    final container = await testContainer(extra: [fakeAlarmServiceOverride()]);
    await container.read(alarmRepositoryProvider).save(alarm);
    await container
        .read(walletRepositoryProvider)
        .write(const Wallet(coins: 5000));
    final session = await container
        .read(sessionServiceProvider)
        .start(alarm: alarm, firedAt: firedAt);
    return (
      service: container.read(alarmServiceProvider) as FakeAlarmService,
      container: container,
      id: session.id,
    );
  }

  Future<AlarmSession?> stored(ProviderContainer c, String id) =>
      c.read(alarmSessionRepositoryProvider).getById(id);

  group('snooze', () {
    test('records the press, moves the ring and posts the notice', () async {
      final r = await ringing(snoozable);

      final snoozed = await r.service.snooze(r.id, now: at(minutes: 2));

      expect(snoozed!.snoozes, [at(minutes: 2)]);
      expect(snoozed.currentRingAt, at(minutes: 7));
      expect(snoozed.status, SessionStatus.ringing, reason: 'same morning');

      final reread = await stored(r.container, r.id);
      expect(reread!.snoozes, [at(minutes: 2)]);
      expect(reread.currentRingAt, at(minutes: 7));

      expect(r.service.cancelled, ['a1'], reason: 'this ring is silenced');
      expect(r.service.rearmed, [(alarmId: 'a1', ringAt: at(minutes: 7))]);

      final posted = notifierOf(r.container).posted.single;
      expect(posted.title, 'スヌーズ中');
      expect(posted.body, '7:07 に再鳴動');
    });

    test('the penalty is on the screen the moment it is pressed', () async {
      final r = await ringing(snoozable);
      final snoozed = await r.service.snooze(r.id, now: at(minutes: 2));

      // 2 minutes billed (grace 1) plus one press, still counting from firedAt
      // because this pledge did not opt into the reset clock.
      expect(lossAt(at(minutes: 2), snoozed!), 250);
    });

    test('an alarm that cannot be snoozed refuses', () async {
      final r = await ringing(unsnoozable);

      expect(await r.service.snooze(r.id, now: at(minutes: 2)), isNull);
      expect((await stored(r.container, r.id))!.snoozes, isEmpty);
      expect(r.service.rearmed, isEmpty);
      expect(notifierOf(r.container).posted, isEmpty);
    });

    test('the last press is the last: maxCount is a hard stop', () async {
      final r = await ringing(snoozable);

      expect(await r.service.snooze(r.id, now: at(minutes: 2)), isNotNull);
      expect(await r.service.snooze(r.id, now: at(minutes: 8)), isNotNull);
      expect(
        await r.service.snooze(r.id, now: at(minutes: 14)),
        isNull,
        reason: 'maxCount 2',
      );

      final reread = await stored(r.container, r.id);
      expect(reread!.snoozes, hasLength(2));
      expect(reread.currentRingAt, at(minutes: 13));
    });

    test('a settled session cannot be snoozed after the fact', () async {
      final r = await ringing(snoozable);
      final session = (await stored(r.container, r.id))!;
      await r.container
          .read(sessionServiceProvider)
          .dismiss(session, at(minutes: 3));

      expect(await r.service.snooze(r.id, now: at(minutes: 4)), isNull);
    });

    test('an unknown session is a no-op, not a crash', () async {
      final r = await ringing(snoozable);
      expect(await r.service.snooze('nope'), isNull);
    });
  });

  group('the re-ring', () {
    test('the reschedule pass leaves a snoozed alarm armed', () async {
      final r = await ringing(snoozable);
      await r.service.snooze(r.id, now: at(minutes: 2));
      r.service.scheduled.clear();

      await r.service.rescheduleAll(from: at(minutes: 3));

      expect(
        r.service.scheduled,
        isEmpty,
        reason: 'Alarm.set would have moved the 7:07 re-ring to tomorrow',
      );

      // Once it has rung again the alarm is back in the pass.
      await r.service.rescheduleAll(from: at(minutes: 8));
      expect(r.service.scheduled, ['a1']);
    });

    test('recovery leaves a snoozed session silent and re-arms it', () async {
      final r = await ringing(snoozable);
      await r.service.snooze(r.id, now: at(minutes: 2));
      r.service.rearmed.clear();
      notifierOf(r.container).posted.clear();

      final outcome = await r.container
          .read(sessionServiceProvider)
          .recoverPending(at(minutes: 4));

      expect(outcome.resumed, isNull, reason: 'nothing to put on screen');
      expect(outcome.settled, isEmpty);
      expect(outcome.snoozing.single.id, r.id);

      await r.service.resumePendingSession(now: at(minutes: 4));
      expect(r.service.rearmed, [(alarmId: 'a1', ringAt: at(minutes: 7))]);
      expect(notifierOf(r.container).posted.single.body, '7:07 に再鳴動');
      expect((await stored(r.container, r.id))!.isRinging, isTrue);
    });

    test('past the re-ring, recovery puts it back on screen', () async {
      final r = await ringing(snoozable);
      await r.service.snooze(r.id, now: at(minutes: 2));

      final outcome = await r.container
          .read(sessionServiceProvider)
          .recoverPending(at(minutes: 9));

      expect(outcome.resumed!.id, r.id);
      expect(outcome.snoozing, isEmpty);
    });

    test('the 60 minute valve is not pushed out by snoozing', () async {
      final r = await ringing(snoozable);
      await r.service.snooze(r.id, now: at(minutes: 58));

      final outcome = await r.container
          .read(sessionServiceProvider)
          .recoverPending(at(minutes: 61));

      expect(outcome.snoozing, isEmpty, reason: 'written off, not waiting');
      expect(outcome.settled.single.status, SessionStatus.failed);
      expect(outcome.settled.single.dismissedAt, at(minutes: 60));
    });
  });

  test(
    'a second alarm ringing does not steal the snoozed one\'s session',
    () async {
      final r = await ringing(snoozable);
      await r.service.snooze(r.id, now: at(minutes: 2));

      // Another alarm fires later, while the first is still snoozing. Its
      // session is the newest ringing one from then on.
      const other = Alarm(id: 'b1', hour: 8, minute: 0, kakugo: kakugo);
      await r.container.read(alarmRepositoryProvider).save(other);
      await r.container
          .read(sessionServiceProvider)
          .start(alarm: other, firedAt: at(minutes: 60));

      // The snoozed alarm's own open session is still findable, and it is not
      // the other alarm's.
      final sessions = r.container.read(alarmSessionRepositoryProvider);
      final mine = await sessions.getRingingForAlarm('a1');
      expect(mine!.id, r.id);
      expect((await sessions.getRinging())!.alarmId, 'b1');
    },
  );

  group('dismissing a snoozed session', () {
    test('is failed, costs the presses, and clears the notice', () async {
      final r = await ringing(snoozable);
      await r.service.snooze(r.id, now: at(minutes: 2));

      final session = (await stored(r.container, r.id))!;
      final settled = await r.container
          .read(sessionServiceProvider)
          .dismiss(session, at(minutes: 7));

      expect(settled.status, SessionStatus.failed);
      expect(settled.loss, 750, reason: '7 billed minutes plus one press');

      await r.service.stopRinging(snoozable);
      expect(notifierOf(r.container).cancelled, isNotEmpty);
      expect(
        await r.container.read(walletRepositoryProvider).read(),
        const Wallet(coins: 5000 - 750),
      );
    });

    test('a plain snoozed alarm is failed but costs nothing', () async {
      const plain = Alarm(
        id: 'a3',
        hour: 7,
        minute: 0,
        snooze: Snooze(intervalMinutes: 5, maxCount: 3),
      );
      final r = await ringing(plain);
      await r.service.snooze(r.id, now: at(minutes: 0));

      final settled = await r.container
          .read(sessionServiceProvider)
          .dismiss((await stored(r.container, r.id))!, at(minutes: 5));

      expect(settled.status, SessionStatus.failed);
      expect(settled.loss, 0);
      // Spec 4: a snoozed plain alarm breaks the streak but earns the ojisan
      // nothing, so it is not one of his oversleeps.
      expect(
        (await r.container.read(ojisanRepositoryProvider).read())
            .totalOversleeps,
        0,
      );
    });
  });
}
