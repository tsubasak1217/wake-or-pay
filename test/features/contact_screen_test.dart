import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/app/profile_controller.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/main.dart';
import 'package:wake_or_pay/services/mail_settings.dart';
import 'package:wake_or_pay/services/voice_recorder.dart';

import '../helpers.dart';

/// The editor's own scroll view; the time wheel brings scrollables of its own.
Finder get editorScrollable => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

/// scrollUntilVisible only ever scrolls one way, so anything already above the
/// viewport would be scrolled further away. Start from the top every time.
Future<void> scrollTo(WidgetTester tester, Finder target) async {
  tester.state<ScrollableState>(editorScrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(target, 120, scrollable: editorScrollable);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> toggle(WidgetTester tester, String label) async {
  await scrollTo(tester, find.text(label));
  await tester.tap(find.widgetWithText(SwitchListTile, label));
  await tester.pumpAndSettle();
}

/// Flips a switch row that is already on screen. The sub-screens are short
/// enough at this window size that nothing ever has to be scrolled to, and
/// [scrollTo] would drive the editor's list rather than theirs.
Future<void> flip(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(SwitchListTile, label));
  await tester.pumpAndSettle();
}

/// 覚悟の設定 → 寝坊時連絡・共有, and back out again.
Future<void> inContactShareScreen(
  WidgetTester tester,
  Future<void> Function() inside,
) async {
  await scrollTo(tester, find.byKey(const ValueKey('contactShareRow')));
  await tester.tap(find.byKey(const ValueKey('contactShareRow')));
  await tester.pumpAndSettle();
  await inside();
  await tester.pageBack();
  await tester.pumpAndSettle();
}

/// One level deeper: 寝坊時連絡・共有 → 寝坊時連絡先. The screen this file is
/// about is two pushes from the editor now, not one.
Future<void> inContactScreen(
  WidgetTester tester,
  Future<void> Function() inside,
) => inContactShareScreen(tester, () async {
  await tester.tap(find.byKey(const ValueKey('contactRow')));
  await tester.pumpAndSettle();
  await inside();
  await tester.pageBack();
  await tester.pumpAndSettle();
});

/// Opens the 連絡帳 from the 連絡先 row and taps [name].
Future<void> pick(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('contactPickRow')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

/// The switch behind a route row, so a test can read whether it is greyed —
/// a null `onChanged` is what draws it grey and makes it untappable.
SwitchListTile routeRow(WidgetTester tester, String label) =>
    tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, label));

late FakeVoiceRecorder recorder;
late FakeVoicePlayer player;

/// Three people in the book, one for each shape of address: both, mail only,
/// number only. The last is what tells 電話/SMS apart from メール.
Future<void> seedBook(ProviderContainer container) async {
  final book = container.read(contactBookRepositoryProvider);
  await book.save(
    ContactEntry(
      id: 'c1',
      name: '田中太郎',
      reading: 'たなかたろう',
      phone: '090-1234-5678',
      email: 'taro@example.com',
      createdAt: DateTime(2026, 1, 1),
    ),
  );
  await book.save(
    ContactEntry(
      id: 'c2',
      name: '佐藤花子',
      reading: 'さとうはなこ',
      email: 'hanako@example.com',
      createdAt: DateTime(2026, 1, 2),
    ),
  );
  await book.save(
    ContactEntry(
      id: 'c3',
      name: '鈴木一郎',
      reading: 'すずきいちろう',
      phone: '080-1111-2222',
      createdAt: DateTime(2026, 1, 3),
    ),
  );
}

Future<ProviderContainer> openNewAlarm(
  WidgetTester tester, {
  bool micPermitted = true,
  bool withBook = true,
  bool mailConfigured = false,
  bool routesPermitted = true,
}) async {
  recorder = FakeVoiceRecorder(permitted: micPermitted);
  player = FakeVoicePlayer();
  final container = await testContainer(
    prefs: mailConfigured ? configuredMailPrefs() : const {},
    extra: [
      if (mailConfigured) seededSecretStoreOverride(),
      routePermissionsOverride(granted: routesPermitted),
      fakeAlarmServiceOverride(),
      voiceRecorderProvider.overrideWithValue(recorder),
      voicePlayerProvider.overrideWithValue(player),
      // A fixed name instead of the real one, so the test never reaches
      // path_provider — and never writes anything to the machine.
      contactRecordingPathProvider.overrideWithValue(
        (alarmId) async => '/tmp/wake_or_pay_test/$alarmId-recording.m4a',
      ),
    ],
  );
  await container
      .read(walletRepositoryProvider)
      .write(const Wallet(coins: 100000));
  if (withBook) await seedBook(container);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const WakeOrPayApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  return container;
}

Future<Alarm> save(WidgetTester tester, ProviderContainer container) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  return (await container.read(alarmRepositoryProvider).getAll()).single;
}

String previewText(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  setUp(() {
    // Tall enough that every field of the contact screen is built and hit
    // testable at once; the sub-screen's list is long.
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1000, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  testWidgets('the screen is two pushes down and starts at なし', (tester) async {
    await openNewAlarm(tester);
    expect(find.text('寝坊時連絡・共有'), findsNothing, reason: '覚悟 is off');

    await toggle(tester, '覚悟');
    await inContactScreen(tester, () async {
      expect(
        find.widgetWithText(AppBar, '寝坊時の連絡設定'),
        findsOneWidget,
        reason: 'the 連絡先 row of 寝坊時連絡・共有 opens this screen',
      );
      expect(find.text('なし'), findsOneWidget, reason: 'the 連絡先 row');
    });

    await toggle(tester, '覚悟');
    expect(find.text('寝坊時連絡・共有'), findsNothing);
  });

  testWidgets('with nobody picked every route toggle is dead', (tester) async {
    await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      expect(
        find.text('寝坊時の連絡設定'),
        findsNWidgets(2),
        reason: 'the app bar and the island',
      );
      expect(find.text('なし'), findsOneWidget, reason: 'the 連絡先 row');
      for (final label in const ['電話', 'メール', 'SMS']) {
        expect(
          routeRow(tester, label).onChanged,
          isNull,
          reason: '$label cannot be switched on with nobody to reach',
        );
      }
      expect(
        find.byKey(const ValueKey('messageIsland')),
        findsNothing,
        reason: 'no written route is on, so there is no body to write',
      );
    });
  });

  testWidgets('LINE is listed and can never be pressed', (tester) async {
    await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      // Dead before anybody is picked…
      expect(find.byKey(const ValueKey('contactLineRow')), findsOneWidget);
      expect(routeRow(tester, 'LINE').onChanged, isNull);
      expect(routeRow(tester, 'LINE').value, isFalse);
      expect(find.text('まだ実装しない'), findsOneWidget);

      // …and dead afterwards too: it is not modelled anywhere.
      await pick(tester, '田中太郎');
      expect(routeRow(tester, 'LINE').onChanged, isNull);
      expect(routeRow(tester, 'LINE').value, isFalse);
    });
  });

  testWidgets('a number with no address leaves 電話 and SMS live, メール greyed', (
    tester,
  ) async {
    await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await pick(tester, '鈴木一郎');

      expect(routeRow(tester, '電話').onChanged, isNotNull);
      expect(routeRow(tester, '電話').value, isTrue, reason: 'the loudest route');
      expect(
        routeRow(tester, 'SMS').onChanged,
        isNotNull,
        reason: 'the same number a call would ring',
      );
      expect(
        routeRow(tester, 'SMS').value,
        isFalse,
        reason: 'a text message is a separate decision, and silent at 4am',
      );

      expect(routeRow(tester, 'メール').onChanged, isNull);
      expect(find.text('この連絡先にはメールアドレスがありません'), findsOneWidget);
    });
  });

  testWidgets('メール stays greyed with an address but no SMTP account', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);
    expect(
      container.read(mailSendingConfiguredProvider),
      isFalse,
      reason: 'nothing has been entered in メール送信設定',
    );
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await pick(tester, '田中太郎');

      final mail = routeRow(tester, 'メール');
      expect(mail.onChanged, isNull, reason: 'greyed out, not toggleable');
      expect(mail.value, isFalse, reason: 'nothing could be sent, so it is off');
      expect(
        find.text(mailSendingUnconfiguredNote),
        findsOneWidget,
        reason: 'the row says why it cannot be pressed, not just that it is',
      );
      expect(
        find.text('この連絡先にはメールアドレスがありません'),
        findsNothing,
        reason: 'the address is fine; the app is what is missing',
      );

      // Tapping it changes nothing at all.
      await flip(tester, 'メール');
      expect(routeRow(tester, 'メール').value, isFalse);
      expect(find.byKey(const ValueKey('messageIsland')), findsNothing);

      // But the way out of the situation is right there, not described.
      expect(find.byKey(const ValueKey('contactMailSetupRow')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('contactMailSetupRow')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mailFromField')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    });
  });

  testWidgets('a refused CALL_PHONE leaves 電話 off, even on picking', (
    tester,
  ) async {
    final container = await openNewAlarm(tester, routesPermitted: false);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await pick(tester, '田中太郎');
      expect(
        routeRow(tester, '電話').value,
        isFalse,
        reason: 'picking somebody normally switches 電話 on, but not without '
            'the permission behind it',
      );

      await flip(tester, '電話');
      expect(routeRow(tester, '電話').value, isFalse);
      expect(find.textContaining('電話の発信が許可されていない'), findsOneWidget);
    });

    final saved = await save(tester, container);
    expect(saved.contact!.phoneEnabled, isFalse);
  });

  testWidgets('SMS asks for SEND_SMS, and a refusal leaves it off', (
    tester,
  ) async {
    final container = await openNewAlarm(tester, routesPermitted: false);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await pick(tester, '田中太郎');
      expect(routeRow(tester, 'SMS').value, isFalse);

      await flip(tester, 'SMS');
      expect(
        routeRow(tester, 'SMS').value,
        isFalse,
        reason: 'a route that would silently fail at 7am must not be stored on',
      );
      expect(find.textContaining('SMS の送信が許可されていない'), findsOneWidget);
    });

    final saved = await save(tester, container);
    expect(saved.contact!.smsEnabled, isFalse);
  });

  testWidgets('SMS goes on once the permission is granted', (tester) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await pick(tester, '田中太郎');
      await flip(tester, 'SMS');
      expect(routeRow(tester, 'SMS').value, isTrue);
    });

    final saved = await save(tester, container);
    expect(saved.contact!.smsEnabled, isTrue);
    expect(saved.contact!.willSms, isTrue);
  });

  testWidgets('with メール送信設定 done the toggle comes alive', (tester) async {
    final container = await openNewAlarm(tester, mailConfigured: true);
    expect(container.read(mailSendingConfiguredProvider), isTrue);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await pick(tester, '田中太郎');

      final mail = routeRow(tester, 'メール');
      expect(mail.onChanged, isNotNull, reason: 'there is an account now');
      expect(
        mail.value,
        isTrue,
        reason: 'picking somebody switches on every route they can be reached '
            'on, and メール is now one of them',
      );
      expect(find.text(mailSendingUnconfiguredNote), findsNothing);
      expect(find.byKey(const ValueKey('contactMailSetupRow')), findsNothing);
      // The written-message island appears for メール on its own now.
      expect(find.byKey(const ValueKey('messageIsland')), findsOneWidget);
    });

    final saved = await save(tester, container);
    expect(saved.contact!.emailEnabled, isTrue);
    expect(saved.contact!.willEmail, isTrue);
  });

  testWidgets('picking somebody copies them onto the alarm, routes and all', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await pick(tester, '田中太郎');
      expect(find.text('田中太郎'), findsOneWidget, reason: 'the 連絡先 row');
      expect(routeRow(tester, '電話').value, isTrue, reason: 'phone is reachable');
    });

    await scrollTo(tester, find.byKey(const ValueKey('contactShareRow')));
    expect(find.text('設定済み'), findsOneWidget, reason: 'the 覚悟 row reads back');

    final contact = (await save(tester, container)).contact!;
    expect(contact.contactId, 'c1', reason: 'the book entry it came from');
    expect(contact.name, '田中太郎');
    expect(contact.phone, '090-1234-5678');
    expect(contact.email, 'taro@example.com');
    expect(contact.phoneEnabled, isTrue);
    expect(contact.smsEnabled, isFalse);
    expect(contact.messageMode, MessageMode.standard, reason: 'the default文面');
  });

  testWidgets('a contact with no number cannot have 電話 or SMS switched on', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await pick(tester, '佐藤花子');

      for (final label in const ['電話', 'SMS']) {
        final row = routeRow(tester, label);
        expect(row.onChanged, isNull, reason: '$label: greyed, not toggleable');
        expect(row.value, isFalse);
      }
      expect(find.text('この連絡先には電話番号がありません'), findsNWidgets(2));

      // Tapping either changes nothing at all.
      await flip(tester, '電話');
      await flip(tester, 'SMS');
      expect(
        find.byKey(const ValueKey('messageIsland')),
        findsNothing,
        reason: 'no route can be on, so no message can go out',
      );
    });

    final contact = (await save(tester, container)).contact!;
    expect(contact.phoneEnabled, isFalse);
    expect(contact.smsEnabled, isFalse);
    expect(contact.phone, isNull);
  });

  testWidgets('the メール・SMS設定 island comes and goes with SMS', (tester) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await pick(tester, '田中太郎');
      expect(find.byKey(const ValueKey('messageIsland')), findsNothing);

      await flip(tester, 'SMS');
      expect(
        find.byKey(const ValueKey('messageIsland')),
        findsOneWidget,
        reason: 'a route is on, so there is a body to write',
      );
      expect(find.text('メール・SMS設定'), findsOneWidget);
      expect(find.byKey(const ValueKey('messageModeStandard')), findsOneWidget);

      await flip(tester, 'SMS');
      expect(
        find.byKey(const ValueKey('messageIsland')),
        findsNothing,
        reason: 'nothing is written any more',
      );
    });

    expect((await save(tester, container)).contact!.smsEnabled, isFalse);
  });

  testWidgets('カスタムメッセージ shows a box and saves what is written in it', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await pick(tester, '田中太郎');
      await flip(tester, 'SMS');
      expect(
        find.byKey(const ValueKey('contactMessage')),
        findsNothing,
        reason: 'デフォルト has nothing to write',
      );

      await tester.tap(find.byKey(const ValueKey('messageModeCustom')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('contactMessage')),
        '起きられませんでした。起こしてください。',
      );
      await tester.pumpAndSettle();
    });

    final contact = (await save(tester, container)).contact!;
    expect(contact.smsEnabled, isTrue);
    expect(contact.messageMode, MessageMode.custom);
    expect(contact.message, '起きられませんでした。起こしてください。');
  });

  testWidgets('連絡先を外す removes the contact entirely', (tester) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await pick(tester, '田中太郎');
    });
    await scrollTo(tester, find.byKey(const ValueKey('contactShareRow')));
    expect(find.text('設定済み'), findsOneWidget);

    await inContactScreen(tester, () async {
      expect(find.text('田中太郎'), findsOneWidget, reason: 'read back off the draft');
      await tester.tap(find.byKey(const ValueKey('contactClear')));
      await tester.pumpAndSettle();
      expect(find.text('なし'), findsOneWidget);
    });

    await scrollTo(tester, find.byKey(const ValueKey('contactShareRow')));
    expect(find.text('なし'), findsOneWidget);
    expect((await save(tester, container)).contact, isNull);
  });

  testWidgets('the preview names the app user, never the contact', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      expect(find.text('あなたの名前'), findsOneWidget);
      expect(find.text('未設定'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('contactUserNameWarning')),
        findsOneWidget,
        reason: 'an unset name changes what goes out, so it is said out loud',
      );

      await pick(tester, '田中太郎');
      await flip(tester, 'SMS');
      final preview = previewText(tester, 'contactMessagePreview');
      expect(
        preview,
        contains(oversleepUserNameFallback),
        reason: 'the preview with no name set',
      );
      expect(
        preview,
        isNot(contains('田中太郎')),
        reason: 'it must not address the recipient about themselves',
      );

      // The row is a pointer now: it opens the profile, and the name is set
      // there.
      await tester.tap(find.byKey(const ValueKey('contactUserNameRow')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profileOverlay')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('profileUserNameRow')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('userNameField')),
        ' 山田花子 ',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profileOverlayClose')));
      await tester.pumpAndSettle();

      expect(
        container.read(profileProvider).userName,
        '山田花子',
        reason: 'stored trimmed',
      );
      expect(find.text('未設定'), findsNothing);
      expect(
        find.byKey(const ValueKey('contactUserNameWarning')),
        findsNothing,
      );
      // The SMS default, with no 【Wake or Pay】 subject tag: in this stage the
      // island can only ever have appeared because SMS was switched on —
      // メール cannot be — so the tagged mail body is a sentence that could
      // never be sent, and previewing it would be the screen lying about what
      // it is about to do.
      expect(
        previewText(tester, 'contactMessagePreview'),
        '例：山田花子 さんは 07:00 のアラームを解除できていません。寝坊しています。',
      );
    });
  });

  testWidgets('設定 no longer carries the name', (tester) async {
    final container = await openNewAlarm(tester);
    // Out of the new-alarm editor and over to 設定, which is on the wallet tab.
    await save(tester, container);
    await tester.tap(find.text('ウォレット'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('設定・テーマ'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '設定'), findsOneWidget);
    expect(find.byKey(const ValueKey('settingsUserNameRow')), findsNothing);
    expect(find.text('あなたの名前'), findsNothing);
  });
}
