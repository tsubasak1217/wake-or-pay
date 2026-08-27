import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/app/router.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/domain/oversleep_contact_rules.dart';
import 'package:wake_or_pay/main.dart';
import 'package:wake_or_pay/services/alarm_service.dart';
import 'package:wake_or_pay/services/speaker.dart';

import '../helpers.dart';

const contact = OversleepContact(
  name: '田中太郎',
  phone: '090-0000-0000',
  phoneEnabled: true,
);

/// The delay lives on the alarm since 改訂4, because one number drives both the
/// personal contact and the group share.
const withContact = Alarm(
  id: 'a1',
  hour: 7,
  minute: 0,
  kakugo: Kakugo(ratePerMinute: 100, cap: 2000),
  contact: contact,
  oversleepTriggerMinutes: 1,
);

/// Every sentence about the notification names the recipient with this one
/// phrase, so the screen and the voice can never disagree about who is told.
final target = oversleepTargetLabel(contactName: contact.name);

/// The opening line is drawn against the alarm's own delay, not the default.
String speech(ContactSpeechCue cue) =>
    contactSpeechText(cue, target, triggerMinutes: 1);

/// The ring screen ticks every second, so pumpAndSettle would never settle.
Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Advances far enough for the one-second ticker to actually fire. Only the
/// test clock moves: the countdown is measured against the real wall clock, so
/// the remaining time a test sets up stays where it was put.
Future<void> tick(WidgetTester tester, {int seconds = 3}) async {
  for (var i = 0; i < seconds; i++) {
    await tester.pump(const Duration(seconds: 1));
    await settle(tester, frames: 5);
  }
}

/// Opens the ring screen on a session that fired [ringingFor] ago, so a
/// countdown measured in minutes can be reached without waiting for one.
Future<({ProviderContainer container, RecordingSpeaker speaker})> openRinging(
  WidgetTester tester, {
  Alarm alarm = withContact,
  required Duration ringingFor,
}) async {
  final speaker = RecordingSpeaker();
  final container = await testContainer(
    extra: [
      fakeAlarmServiceOverride(),
      speakerProvider.overrideWithValue(speaker),
      // Nothing on this screen has a 共有先 on it, but the dispatcher it drives
      // is the one that really posts to Discord now, and no test of it may be
      // one webhook URL away from somebody's live channel.
      fakeDiscordSenderOverride(FakeDiscordWebhookSender()),
    ],
  );
  await container.read(alarmRepositoryProvider).save(alarm);
  await container
      .read(walletRepositoryProvider)
      .write(const Wallet(coins: 5000));
  final session = await container
      .read(sessionServiceProvider)
      .start(alarm: alarm, firedAt: DateTime.now().subtract(ringingFor));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const WakeOrPayApp(),
    ),
  );
  await settle(tester);
  container.read(appRouterProvider).go(AppRoute.ringing(session.id));
  await settle(tester);
  await tick(tester);

  return (container: container, speaker: speaker);
}

String countdownText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('contactCountdown'))).data!;

void main() {
  testWidgets('the ring screen counts down to the contact', (tester) async {
    // grace 1 + trigger 1 = due at 2:00, so 20 seconds in leaves 1:40.
    final r = await openRinging(
      tester,
      ringingFor: const Duration(seconds: 20),
    );

    expect(countdownText(tester), startsWith('あと '));
    expect(countdownText(tester), endsWith('で $targetに連絡が行きます'));
    expect(
      r.speaker.spoken.first,
      speech(ContactSpeechCue.start),
      reason: 'the opening line lands at ring start, not on a later tick',
    );
  });

  testWidgets('an alarm with no contact shows no countdown and says nothing', (
    tester,
  ) async {
    final r = await openRinging(
      tester,
      alarm: const Alarm(
        id: 'a1',
        hour: 7,
        minute: 0,
        kakugo: Kakugo(ratePerMinute: 100, cap: 2000),
      ),
      ringingFor: const Duration(seconds: 20),
    );

    expect(find.byKey(const ValueKey('contactCountdown')), findsNothing);
    expect(r.speaker.spoken, isEmpty);
  });

  testWidgets('a plain alarm never contacts anyone', (tester) async {
    final r = await openRinging(
      tester,
      alarm: const Alarm(
        id: 'a1',
        hour: 7,
        minute: 0,
        contact: contact,
        oversleepTriggerMinutes: 1,
      ),
      ringingFor: const Duration(seconds: 20),
    );

    expect(find.byKey(const ValueKey('contactCountdown')), findsNothing);
    expect(r.speaker.spoken, isEmpty);
  });

  testWidgets('inside 30 seconds it has said the 3, 1 and 30 lines', (
    tester,
  ) async {
    // Due at 2:00; 1:45 in leaves 15 seconds, which is past all three marks.
    final r = await openRinging(
      tester,
      ringingFor: const Duration(seconds: 105),
    );

    expect(r.speaker.spoken, [
      speech(ContactSpeechCue.start),
      speech(ContactSpeechCue.thirtySeconds),
    ], reason: 'only the mark actually reached is spoken, not the ones passed');
  });

  testWidgets('past the trigger it fires once, logs it and says so', (
    tester,
  ) async {
    final r = await openRinging(
      tester,
      ringingFor: const Duration(minutes: 2, seconds: 5),
    );
    // The dispatch is asynchronous; a few more ticks let it land.
    await tick(tester, seconds: 3);

    expect(countdownText(tester), '$targetに連絡が行きました');
    expect(
      r.speaker.spoken,
      contains(speech(ContactSpeechCue.sent)),
    );

    final events = await r.container
        .read(contactEventRepositoryProvider)
        .getRecent();
    expect(events, hasLength(1), reason: 'once per session');
    expect(
      events.single.contactName,
      target,
      reason: 'the log names the recipient with the same phrase the voice did',
    );

    final posted = notifierOf(r.container).posted;
    // メール really goes out since D1, so it is no longer among the routes the
    // notification apologises for. This alarm's contact has 電話 on and
    // nothing else, and that is the one still owed an apology.
    expect(posted.map((p) => p.body), contains('電話は開発中で、記録だけが残ります'));

    // Ticking on does not send a second one.
    await tick(tester, seconds: 3);
    expect(
      await r.container.read(contactEventRepositoryProvider).getRecent(),
      hasLength(1),
    );
  });

  testWidgets('clearing the wake check cancels a contact that had not fired', (
    tester,
  ) async {
    final r = await openRinging(tester, ringingFor: const Duration(seconds: 5));

    await tester.longPress(find.text('解除'));
    await tester.pump(const Duration(seconds: 6));
    await tick(tester, seconds: 3);

    expect(
      await r.container.read(contactEventRepositoryProvider).getRecent(),
      isEmpty,
      reason: 'nobody is told about a morning that ended in time',
    );
  });
}
