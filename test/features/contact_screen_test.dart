import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/app/profile_controller.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/main.dart';
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

Future<void> inContactScreen(
  WidgetTester tester,
  Future<void> Function() inside,
) async {
  await scrollTo(tester, find.text('寝坊時連絡先'));
  await tester.tap(find.text('寝坊時連絡先'));
  await tester.pumpAndSettle();
  await inside();
  await tester.pageBack();
  await tester.pumpAndSettle();
}

/// Opens the 連絡帳 from the 連絡先 row and taps [name].
Future<void> pick(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('contactPickRow')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

late FakeVoiceRecorder recorder;
late FakeVoicePlayer player;

/// Two people in the book: one reachable both ways, one by mail only.
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
}

Future<ProviderContainer> openNewAlarm(
  WidgetTester tester, {
  bool micPermitted = true,
  bool withBook = true,
}) async {
  recorder = FakeVoiceRecorder(permitted: micPermitted);
  player = FakeVoicePlayer();
  final container = await testContainer(
    extra: [
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

String statusText(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('contactRecordingStatus')))
    .data!;

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

  testWidgets('the row lives in 覚悟の設定 and starts at なし', (tester) async {
    await openNewAlarm(tester);
    expect(find.text('寝坊時連絡先'), findsNothing, reason: '覚悟 is off');

    await toggle(tester, '覚悟');
    await scrollTo(tester, find.text('寝坊時連絡先'));
    expect(find.text('寝坊時連絡先'), findsOneWidget);
    expect(find.text('なし'), findsOneWidget);

    await toggle(tester, '覚悟');
    expect(find.text('寝坊時連絡先'), findsNothing);
  });

  testWidgets('with nobody picked the two route toggles are dead', (
    tester,
  ) async {
    await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      expect(find.text('寝坊時の連絡設定'), findsOneWidget, reason: 'the island');
      expect(find.text('なし'), findsOneWidget, reason: 'the 連絡先 row');
      for (final label in const ['電話', 'メール']) {
        expect(
          tester
              .widget<SwitchListTile>(
                find.widgetWithText(SwitchListTile, label),
              )
              .onChanged,
          isNull,
          reason: '$label cannot be switched on with nobody to reach',
        );
      }
      expect(find.text('メール設定'), findsNothing);
      expect(find.text('電話設定'), findsNothing);
    });
  });

  testWidgets('picking somebody copies them onto the alarm, routes and all', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await pick(tester, '田中太郎');
      expect(find.text('田中太郎'), findsOneWidget, reason: 'the 連絡先 row');
      expect(find.text('メール設定'), findsOneWidget, reason: 'mail is reachable');
      expect(find.text('電話設定'), findsOneWidget, reason: 'so is the phone');
    });

    await scrollTo(tester, find.text('寝坊時連絡先'));
    expect(find.text('田中太郎'), findsOneWidget, reason: 'the row shows the name');

    final contact = (await save(tester, container)).contact!;
    expect(contact.contactId, 'c1', reason: 'the book entry it came from');
    expect(contact.name, '田中太郎');
    expect(contact.phone, '090-1234-5678');
    expect(contact.email, 'taro@example.com');
    expect(contact.phoneEnabled, isTrue);
    expect(contact.emailEnabled, isTrue);
    expect(contact.mailMode, MailMode.standard, reason: 'the default文面');
    expect(contact.phoneMode, PhoneMode.auto);
    expect(contact.triggerMinutesAfterGrace, defaultContactTriggerMinutes);
  });

  testWidgets('a contact with no number cannot have 電話 switched on', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await pick(tester, '佐藤花子');

      final phone = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, '電話'),
      );
      expect(phone.onChanged, isNull, reason: 'greyed out, not toggleable');
      expect(phone.value, isFalse);
      expect(find.text('この連絡先には電話番号がありません'), findsOneWidget);

      // Tapping it changes nothing at all.
      await tester.tap(find.widgetWithText(SwitchListTile, '電話'));
      await tester.pumpAndSettle();
      expect(find.text('電話設定'), findsNothing);

      expect(find.text('メール設定'), findsOneWidget, reason: 'mail still works');
    });

    final contact = (await save(tester, container)).contact!;
    expect(contact.phoneEnabled, isFalse);
    expect(contact.emailEnabled, isTrue);
    expect(contact.phone, isNull);
  });

  testWidgets('the timing runs 0-60 and 0 is the moment the grace ends', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await pick(tester, '田中太郎');
      expect(find.text('猶予後 3分'), findsOneWidget, reason: 'the default');

      await tester.tap(find.byKey(const ValueKey('contactTriggerRow')));
      await tester.pumpAndSettle();
      expect(find.text('0〜60分'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('sliderNumberInput')),
        '0',
      );
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('猶予後すぐ'), findsOneWidget);
    });

    expect(
      (await save(tester, container)).contact!.triggerMinutesAfterGrace,
      0,
      reason: '0 is a real choice now',
    );
  });

  testWidgets('a timing above 60 is clamped down, not rejected', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await pick(tester, '田中太郎');
      await tester.tap(find.byKey(const ValueKey('contactTriggerRow')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('sliderNumberInput')),
        '999',
      );
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
    });
    expect(
      (await save(tester, container)).contact!.triggerMinutesAfterGrace,
      60,
    );
  });

  testWidgets('カスタムメッセージ shows a box and saves what is written in it', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await pick(tester, '田中太郎');
      expect(
        find.byKey(const ValueKey('contactMailMessage')),
        findsNothing,
        reason: 'デフォルト has nothing to write',
      );

      await tester.tap(find.byKey(const ValueKey('mailModeCustom')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('contactMailMessage')),
        '起きられませんでした。起こしてください。',
      );
      await tester.pumpAndSettle();
    });

    final contact = (await save(tester, container)).contact!;
    expect(contact.mailMode, MailMode.custom);
    expect(contact.mailMessage, '起きられませんでした。起こしてください。');
  });

  testWidgets('カスタム録音 records, and 自動音声 hides the recorder', (tester) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await pick(tester, '田中太郎');
      expect(
        find.byKey(const ValueKey('contactRecordStart')),
        findsNothing,
        reason: '自動音声 has nothing to record',
      );

      await tester.tap(find.byKey(const ValueKey('phoneModeCustom')));
      await tester.pumpAndSettle();
      expect(statusText(tester), '録音なし');

      await tester.tap(find.byKey(const ValueKey('contactRecordStart')));
      await tester.pump();
      // 録音開始 and 停止 are now the same wide button, so the start is gone.
      expect(statusText(tester), startsWith('録音中'));
      expect(find.byKey(const ValueKey('contactRecordStart')), findsNothing);
      expect(recorder.started, hasLength(1));

      await tester.tap(find.byKey(const ValueKey('contactRecordStop')));
      await tester.pumpAndSettle();
      expect(statusText(tester), startsWith('録音あり'));
    });

    final contact = (await save(tester, container)).contact!;
    expect(contact.phoneMode, PhoneMode.custom);
    expect(contact.recordingPath, recorder.started.single);
  });

  testWidgets('削除 plays back then throws the recording away', (tester) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await pick(tester, '田中太郎');
      await tester.tap(find.byKey(const ValueKey('phoneModeCustom')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('contactRecordStart')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('contactRecordStop')));
      await tester.pumpAndSettle();
    });

    await inContactScreen(tester, () async {
      expect(
        statusText(tester),
        startsWith('録音あり'),
        reason: 'read back off the draft',
      );
      await tester.tap(find.byKey(const ValueKey('contactRecordPlay')));
      await tester.pumpAndSettle();
      expect(player.played, [recorder.started.single]);

      // 削除 now asks first: it is the one button here that cannot be undone.
      await tester.tap(find.byKey(const ValueKey('contactRecordDelete')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('contactRecordDeleteConfirm')),
      );
      await tester.pumpAndSettle();
      expect(statusText(tester), '録音なし');
    });

    final after = (await save(tester, container)).contact!;
    expect(after.recordingPath, isNull);
    expect(after.name, '田中太郎', reason: 'only the recording was deleted');
  });

  testWidgets('a refused microphone says so in Japanese and records nothing', (
    tester,
  ) async {
    final container = await openNewAlarm(tester, micPermitted: false);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await pick(tester, '田中太郎');
      await tester.tap(find.byKey(const ValueKey('phoneModeCustom')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('contactRecordStart')));
      await tester.pumpAndSettle();

      expect(recorder.permissionAsked, 1);
      expect(recorder.started, isEmpty);
      expect(statusText(tester), '録音なし');
      expect(find.textContaining('マイクの使用が許可されていない'), findsWidgets);
    });

    expect((await save(tester, container)).contact!.recordingPath, isNull);
  });

  testWidgets('連絡先を外す removes the contact entirely', (tester) async {
    final container = await openNewAlarm(tester);
    await toggle(tester, '覚悟');

    await inContactScreen(tester, () async {
      await pick(tester, '田中太郎');
    });
    await scrollTo(tester, find.text('寝坊時連絡先'));
    expect(find.text('田中太郎'), findsOneWidget);

    await inContactScreen(tester, () async {
      await tester.tap(find.byKey(const ValueKey('contactClear')));
      await tester.pumpAndSettle();
      expect(find.text('なし'), findsOneWidget);
    });

    await scrollTo(tester, find.text('寝坊時連絡先'));
    expect(find.text('なし'), findsOneWidget);
    expect((await save(tester, container)).contact, isNull);
  });

  testWidgets('the previews name the app user, never the contact', (
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
      for (final key in const ['contactMailPreview', 'contactVoicePreview']) {
        final preview = previewText(tester, key);
        expect(
          preview,
          contains(oversleepUserNameFallback),
          reason: '$key with no name set',
        );
        expect(
          preview,
          isNot(contains('田中太郎')),
          reason: '$key must not address the recipient about themselves',
        );
      }

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
      expect(
        previewText(tester, 'contactMailPreview'),
        '例：【Wake or Pay】山田花子 さんは 07:00 のアラームを解除できていません。寝坊しています。',
      );
      expect(
        previewText(tester, 'contactVoicePreview'),
        '読み上げる文：山田花子 さんは 07:00 のアラームを解除できていません。寝坊しています。',
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
