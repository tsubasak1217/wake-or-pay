import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/domain/oversleep_contact_rules.dart';
import 'package:wake_or_pay/features/ringing/ringing_controller.dart';
import 'package:wake_or_pay/services/alarm_service.dart';
import 'package:wake_or_pay/services/background_dispatch.dart';
import 'package:wake_or_pay/services/oversleep_notifier.dart';
import 'package:wake_or_pay/services/phone_caller.dart';

import '../helpers.dart';

const contact = OversleepContact(
  name: '田中太郎',
  phone: '090-0000-0000',
  phoneEnabled: true,
  smsEnabled: true,
);

const pledged = Alarm(
  id: 'a1',
  hour: 7,
  minute: 0,
  kakugo: Kakugo(ratePerMinute: 100, cap: 2000),
  contact: contact,
  oversleepTriggerMinutes: 3,
);

final firedAt = DateTime(2026, 8, 27, 7);
DateTime at({int minutes = 0}) => firedAt.add(Duration(minutes: minutes));

Future<({ProviderContainer container, AlarmSession session})> ringing({
  Alarm alarm = pledged,
  RecordingExactAlarmScheduler? scheduler,
}) async {
  final container = await testContainer(
    prefs: {'profile.userName': '山田花子'},
    extra: [
      fakeAlarmServiceOverride(),
      if (scheduler != null)
        exactAlarmSchedulerProvider.overrideWithValue(scheduler),
    ],
  );
  await container.read(alarmRepositoryProvider).save(alarm);
  await container.read(walletRepositoryProvider).write(const Wallet(coins: 500));
  final session = await container
      .read(sessionServiceProvider)
      .start(alarm: alarm, firedAt: firedAt);
  return (container: container, session: session);
}

void main() {
  group('backgroundAlarmId', () {
    test('is stable, positive, and fits the plugin’s 32 bits', () {
      const id = 'session-1787814000000-a1';
      expect(backgroundAlarmId(id), backgroundAlarmId(id));
      expect(backgroundAlarmId(id), greaterThan(0));
      expect(backgroundAlarmId(id).bitLength, lessThan(32));
    });

    test('two sessions do not collide', () {
      expect(
        backgroundAlarmId('session-1-a1'),
        isNot(backgroundAlarmId('session-1-a2')),
      );
      expect(
        backgroundAlarmId('session-1-a1'),
        isNot(backgroundAlarmId('session-2-a1')),
      );
    });

    test('never zero, so a log entry cannot read as "no id"', () {
      expect(backgroundAlarmId(''), isNonZero);
    });
  });

  group('OversleepBackgroundScheduler', () {
    test('books the trigger at exactly the contact time', () async {
      final scheduler = RecordingExactAlarmScheduler();
      final r = await ringing(scheduler: scheduler);

      await r.container
          .read(oversleepBackgroundSchedulerProvider)
          .sync(alarm: pledged, session: r.session);

      final booked = scheduler.booked.single;
      expect(
        booked.at,
        contactTriggerAt(r.session, pledged),
        reason: 'the same clock the countdown and the loss are billed on: '
            'grace, then the delay',
      );
      expect(booked.at, at(minutes: 1 + 3));
      expect(booked.id, backgroundAlarmId(r.session.id));
      expect(booked.params[oversleepSessionIdParam], r.session.id);
    });

    test('an alarm that tells nobody books nothing and cancels', () async {
      const silent = Alarm(id: 'a1', hour: 7, minute: 0);
      final scheduler = RecordingExactAlarmScheduler();
      final r = await ringing(alarm: silent, scheduler: scheduler);

      await r.container
          .read(oversleepBackgroundSchedulerProvider)
          .sync(alarm: silent, session: r.session);

      expect(scheduler.booked, isEmpty);
      expect(scheduler.cancelled, [backgroundAlarmId(r.session.id)]);
    });

    test('a settled session books nothing either', () async {
      final scheduler = RecordingExactAlarmScheduler();
      final r = await ringing(scheduler: scheduler);
      final settled = await r.container
          .read(sessionServiceProvider)
          .dismiss(r.session, at(minutes: 1));

      await r.container
          .read(oversleepBackgroundSchedulerProvider)
          .sync(alarm: pledged, session: settled);

      expect(scheduler.booked, isEmpty);
      expect(scheduler.cancelled, [backgroundAlarmId(settled.id)]);
    });
  });

  group('the trigger follows the ring', () {
    test('a snooze moves the booking with the clock', () async {
      const snoozing = Alarm(
        id: 'a1',
        hour: 7,
        minute: 0,
        // 「次に鳴る時刻を起点にし直す」: the clock — and with it the trigger —
        // moves when the alarm comes back.
        kakugo: Kakugo(
          ratePerMinute: 100,
          cap: 2000,
          snoozeResetsClock: true,
        ),
        contact: contact,
        oversleepTriggerMinutes: 3,
        snooze: Snooze(intervalMinutes: 5, maxCount: 3),
      );
      final scheduler = RecordingExactAlarmScheduler();
      final r = await ringing(alarm: snoozing, scheduler: scheduler);

      final snoozed = await r.container
          .read(alarmServiceProvider)
          .snooze(r.session.id, now: at(minutes: 1));

      expect(snoozed, isNotNull);
      expect(
        scheduler.booked.single.at,
        contactTriggerAt(snoozed!, snoozing),
        reason: 'under 起点リセット the trigger moves with the re-ring',
      );
      expect(scheduler.booked.single.at, isNot(at(minutes: 4)));
    });

    test('dismissing cancels it', () async {
      final scheduler = RecordingExactAlarmScheduler();
      final r = await ringing(scheduler: scheduler);

      await r.container
          .read(ringingControllerProvider)
          .dismiss(r.session.id, now: at(minutes: 1));

      expect(scheduler.cancelled, contains(backgroundAlarmId(r.session.id)));
    });
  });

  group('runBackgroundDispatch', () {
    test('sends when the session is still ringing and due', () async {
      final r = await ringing();

      final event = await runBackgroundDispatch(
        r.container,
        r.session.id,
        at(minutes: 4),
      );

      expect(event, isNotNull);
      expect(smsSenderOf(r.container).sent, hasLength(1));
    });

    test('does nothing before the trigger', () async {
      final r = await ringing();

      expect(
        await runBackgroundDispatch(r.container, r.session.id, at(minutes: 3)),
        isNull,
      );
      expect(smsSenderOf(r.container).sent, isEmpty);
    });

    test('does nothing for a session that was dismissed', () async {
      final r = await ringing();
      await r.container
          .read(sessionServiceProvider)
          .dismiss(r.session, at(minutes: 1));

      expect(
        await runBackgroundDispatch(r.container, r.session.id, at(minutes: 4)),
        isNull,
      );
      expect(smsSenderOf(r.container).sent, isEmpty);
    });

    test('does nothing for a session id that is not there', () async {
      final r = await ringing();

      expect(
        await runBackgroundDispatch(r.container, 'nope', at(minutes: 4)),
        isNull,
      );
    });

    test('does nothing when the alarm behind it has been deleted', () async {
      final r = await ringing();
      await r.container.read(alarmRepositoryProvider).delete(pledged.id);

      expect(
        await runBackgroundDispatch(r.container, r.session.id, at(minutes: 4)),
        isNull,
      );
    });
  });

  group('once per session, whichever path gets there first', () {
    test('the ring screen and the background isolate send one round', () async {
      final r = await ringing();
      final dispatcher = r.container.read(contactDispatcherProvider);

      // The ring screen fires first…
      final first = await dispatcher.fireIfDue(
        alarm: pledged,
        session: r.session,
        now: at(minutes: 4),
      );
      // …and the trigger goes off a moment later, as it always will.
      final second = await runBackgroundDispatch(
        r.container,
        r.session.id,
        at(minutes: 4),
      );

      expect(first, isNotNull);
      expect(second, isNull, reason: 'the second one finds the session claimed');
      expect(smsSenderOf(r.container).sent, hasLength(1));
      expect(phoneCallerOf(r.container).called, hasLength(1));
    });

    test('and the other way round', () async {
      final r = await ringing();

      final first = await runBackgroundDispatch(
        r.container,
        r.session.id,
        at(minutes: 4),
      );
      final second = await r.container
          .read(contactDispatcherProvider)
          .fireIfDue(alarm: pledged, session: r.session, now: at(minutes: 4));

      expect(first, isNotNull);
      expect(second, isNull);
      expect(smsSenderOf(r.container).sent, hasLength(1));
    });

    test('the claim is one row, and the id has no clock in it', () async {
      final r = await ringing();
      await runBackgroundDispatch(r.container, r.session.id, at(minutes: 4));

      final rows = await r.container
          .read(contactEventRepositoryProvider)
          .forSession(r.session.id);
      expect(
        rows.map((e) => e.id),
        contains(contactSummaryRowId(r.session.id)),
        reason: 'two ids a millisecond apart would let both paths win',
      );
    });
  });

  group('the background isolate cannot place a call', () {
    test('the call is skipped and the log says so', () async {
      final container = await testContainer(
        extra: [
          fakeAlarmServiceOverride(),
          phoneCallerProvider.overrideWithValue(const UnavailablePhoneCaller()),
        ],
      );
      await container.read(alarmRepositoryProvider).save(pledged);
      await container
          .read(walletRepositoryProvider)
          .write(const Wallet(coins: 500));
      final session = await container
          .read(sessionServiceProvider)
          .start(alarm: pledged, firedAt: firedAt);

      await runBackgroundDispatch(container, session.id, at(minutes: 4));

      final row = (await container
              .read(contactEventRepositoryProvider)
              .forSession(session.id))
          .firstWhere(
            (e) => e.id.endsWith(contactRouteRowSuffix(ContactChannel.phone)),
          );
      expect(row.detail, contains(UnavailablePhoneCaller.backgroundReason));
      expect(
        smsSenderOf(container).sent,
        hasLength(1),
        reason: 'the SMS still goes out — only the call needs an Activity',
      );
    });
  });
}
