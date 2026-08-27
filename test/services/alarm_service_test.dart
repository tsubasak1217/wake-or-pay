import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/services/alarm_service.dart';
import 'package:wake_or_pay/services/phone_caller.dart';

import '../helpers.dart';

void main() {
  const kakugo = Kakugo(ratePerMinute: 100, cap: 2000);
  const oneShot = Alarm(id: 'a1', hour: 7, minute: 0, kakugo: kakugo);
  const repeating = Alarm(
    id: 'a2',
    hour: 7,
    minute: 0,
    repeatDays: {1, 2, 3, 4, 5},
    kakugo: kakugo,
  );

  final firedAt = DateTime(2026, 8, 27, 7);
  final wellPastTheValve = firedAt.add(const Duration(hours: 2));

  Future<({FakeAlarmService service, ProviderContainer container})> setUpWith(
    Alarm alarm,
  ) async {
    final container = await testContainer(extra: [fakeAlarmServiceOverride()]);
    await container.read(alarmRepositoryProvider).save(alarm);
    await container
        .read(walletRepositoryProvider)
        .write(const Wallet(coins: 5000));
    await container
        .read(sessionServiceProvider)
        .start(alarm: alarm, firedAt: firedAt);
    return (
      service: container.read(alarmServiceProvider) as FakeAlarmService,
      container: container,
    );
  }

  Future<Alarm?> storedAlarm(ProviderContainer c, String id) =>
      c.read(alarmRepositoryProvider).getById(id);

  test('an expired one-shot session switches its alarm off', () async {
    final s = await setUpWith(oneShot);

    await s.service.resumePendingSession(now: wellPastTheValve);

    expect((await storedAlarm(s.container, oneShot.id))!.enabled, isFalse);
    expect(s.service.cancelled, contains(oneShot.id));
    expect(
      s.service.scheduled,
      isNot(contains(oneShot.id)),
      reason: 'a spent one-shot must not be armed for tomorrow',
    );
  });

  test(
    'an expired repeating session leaves its alarm on and re-armed',
    () async {
      final s = await setUpWith(repeating);

      await s.service.resumePendingSession(now: wellPastTheValve);

      expect((await storedAlarm(s.container, repeating.id))!.enabled, isTrue);
      expect(s.service.cancelled, contains(repeating.id));
      expect(s.service.scheduled, contains(repeating.id));
    },
  );

  test('a session still inside the hour leaves its alarm untouched', () async {
    final s = await setUpWith(oneShot);

    await s.service.resumePendingSession(
      now: firedAt.add(const Duration(minutes: 59, seconds: 59)),
    );

    expect((await storedAlarm(s.container, oneShot.id))!.enabled, isTrue);
    expect(s.service.cancelled, isEmpty);
    expect(s.service.scheduled, isEmpty);
  });

  test(
    'a live ring survives an older session of the same alarm expiring',
    () async {
      final container = await testContainer(
        extra: [fakeAlarmServiceOverride()],
      );
      await container.read(alarmRepositoryProvider).save(oneShot);
      await container
          .read(walletRepositoryProvider)
          .write(const Wallet(coins: 5000));
      final sessions = container.read(sessionServiceProvider);
      await sessions.start(alarm: oneShot, firedAt: firedAt);
      await sessions.start(
        alarm: oneShot,
        firedAt: firedAt.add(const Duration(hours: 3)),
      );

      final service = container.read(alarmServiceProvider) as FakeAlarmService;
      await service.resumePendingSession(
        now: firedAt.add(const Duration(hours: 3, minutes: 5)),
      );

      expect(service.cancelled, isEmpty, reason: 'the live ring must not stop');
      expect(service.scheduled, isEmpty);
      expect(
        (await container.read(alarmRepositoryProvider).getById(oneShot.id))!
            .enabled,
        isTrue,
      );
    },
  );

  test('nothing pending changes nothing', () async {
    final container = await testContainer(extra: [fakeAlarmServiceOverride()]);
    await container.read(alarmRepositoryProvider).save(oneShot);

    final service = container.read(alarmServiceProvider) as FakeAlarmService;
    await service.resumePendingSession(now: wellPastTheValve);

    expect(service.cancelled, isEmpty);
    expect(service.scheduled, isEmpty);
    expect(
      (await container.read(alarmRepositoryProvider).getById(oneShot.id))!
          .enabled,
      isTrue,
    );
  });

  test('dismissing follows the same rule as recovery', () async {
    final container = await testContainer(extra: [fakeAlarmServiceOverride()]);
    await container.read(alarmRepositoryProvider).save(oneShot);
    await container.read(alarmRepositoryProvider).save(repeating);
    final service = container.read(alarmServiceProvider) as FakeAlarmService;

    await service.stopRinging(oneShot);
    await service.stopRinging(repeating);

    final alarms = container.read(alarmRepositoryProvider);
    expect((await alarms.getById(oneShot.id))!.enabled, isFalse);
    expect((await alarms.getById(repeating.id))!.enabled, isTrue);
    expect(service.scheduled, [repeating.id]);
  });

  group('an oversleep call silences the ring while it lasts', () {
    /// A ring in progress, with a phone caller whose state the test drives.
    ///
    /// The `alarm` plugin has no pause — its API is `set` / `stop` — so
    /// [AlarmService.watchCalls] stops the platform alarm and sets the same
    /// one again when the call ends.
    Future<
      ({
        FakeAlarmService service,
        RecordingPhoneCaller phone,
        ProviderContainer container,
        AlarmSession session,
      })
    >
    ringingWithCall({bool openSession = true}) async {
      final phone = RecordingPhoneCaller();
      final container = await testContainer(
        extra: [
          fakeAlarmServiceOverride(),
          recordingPhoneCallerOverride(phone),
        ],
      );
      await container.read(alarmRepositoryProvider).save(oneShot);
      await container
          .read(walletRepositoryProvider)
          .write(const Wallet(coins: 5000));
      final session = await container
          .read(sessionServiceProvider)
          .start(alarm: oneShot, firedAt: firedAt);
      final service = container.read(alarmServiceProvider) as FakeAlarmService;
      service.watchCalls();
      return (
        service: service,
        phone: phone,
        container: container,
        session: session,
      );
    }

    test('off while the call is up, and back on when it ends', () async {
      final r = await ringingWithCall();

      r.phone.emitInCall(true);
      await pumpEventQueue();
      expect(
        r.service.cancelled,
        [oneShot.id],
        reason: 'the contact’s voice cannot be heard over the alarm',
      );
      expect(r.service.rearmed, isEmpty);

      r.phone.emitInCall(false);
      await pumpEventQueue();
      expect(
        r.service.rearmed.single.alarmId,
        oneShot.id,
        reason: 'the morning is not over just because the call was',
      );
    });

    test('a ring cleared during the call is not started again', () async {
      final r = await ringingWithCall();

      r.phone.emitInCall(true);
      await pumpEventQueue();
      expect(r.service.cancelled, [oneShot.id]);

      // Getting up during the call is the outcome this feature exists to
      // cause. Settling the session must end the morning, not restart it.
      await r.container
          .read(sessionServiceProvider)
          .dismiss(r.session, firedAt.add(const Duration(minutes: 2)));

      r.phone.emitInCall(false);
      await pumpEventQueue();
      expect(r.service.rearmed, isEmpty);
    });

    test('a call with nothing ringing touches nothing', () async {
      final phone = RecordingPhoneCaller();
      final container = await testContainer(
        extra: [
          fakeAlarmServiceOverride(),
          recordingPhoneCallerOverride(phone),
        ],
      );
      await container.read(alarmRepositoryProvider).save(oneShot);
      final service = container.read(alarmServiceProvider) as FakeAlarmService;
      service.watchCalls();

      phone.emitInCall(true);
      await pumpEventQueue();
      phone.emitInCall(false);
      await pumpEventQueue();

      expect(service.cancelled, isEmpty);
      expect(service.rearmed, isEmpty);
    });
  });
}
