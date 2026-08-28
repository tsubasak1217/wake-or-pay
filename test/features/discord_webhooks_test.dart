import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/main.dart';
import 'package:wake_or_pay/services/voice_recorder.dart';

import '../helpers.dart';

/// Discord 共有先設定 — the app-wide list, and the per-alarm ticks on it.
///
/// The two never touch: ＋/編集/削除 write the shared table, the switches write
/// this alarm's [OversleepShare.webhookIds]. Nothing here is allowed to reach
/// the network, because a webhook URL is somebody's live Discord channel.

Finder get editorScrollable => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

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

/// 覚悟の設定 → 寝坊時連絡・共有 → 寝坊の共有 → Discord, and all the way back.
Future<void> inWebhookList(
  WidgetTester tester,
  Future<void> Function() inside,
) async {
  await scrollTo(tester, find.byKey(const ValueKey('contactShareRow')));
  await tester.tap(find.byKey(const ValueKey('contactShareRow')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('shareRow')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('shareDiscordRow')));
  await tester.pumpAndSettle();

  await inside();

  for (var i = 0; i < 3; i++) {
    await tester.pageBack();
    await tester.pumpAndSettle();
  }
}

/// The switch inside a row: the [ValueKey] sits on the gesture wrapper, so the
/// long press and the tap can be two different jobs on the same row.
SwitchListTile switchIn(WidgetTester tester, String id) =>
    tester.widget<SwitchListTile>(
      find.descendant(
        of: find.byKey(ValueKey('webhook-$id')),
        matching: find.byType(SwitchListTile),
      ),
    );

late FakeVoiceRecorder recorder;
late FakeVoicePlayer player;

/// Two 共有先 in the app-wide list, so a test can tell "both render" from
/// "the one I ticked".
Future<void> seedWebhooks(ProviderContainer container) async {
  final repo = container.read(discordWebhookRepositoryProvider);
  await repo.save(
    DiscordWebhook(
      id: 'w1',
      url: 'https://discord.com/api/webhooks/1/aaa',
      displayName: 'みんなのサーバー/#一般',
      createdAt: DateTime(2026, 1, 1),
    ),
  );
  await repo.save(
    DiscordWebhook(
      id: 'w2',
      url: 'https://discord.com/api/webhooks/2/bbb',
      displayName: '寝坊部/#通報',
      createdAt: DateTime(2026, 1, 2),
    ),
  );
}

Future<ProviderContainer> openNewAlarm(
  WidgetTester tester, {
  FakeHttpClient? http,
  bool withWebhooks = true,
}) async {
  recorder = FakeVoiceRecorder();
  player = FakeVoicePlayer();
  final container = await testContainer(
    extra: [
      fakeAlarmServiceOverride(),
      voiceRecorderProvider.overrideWithValue(recorder),
      voicePlayerProvider.overrideWithValue(player),
      contactRecordingPathProvider.overrideWithValue(
        (alarmId) async => '/tmp/wake_or_pay_test/$alarmId-recording.m4a',
      ),
      fakeHttpClientOverride(http ?? FakeHttpClient()),
    ],
  );
  await container
      .read(walletRepositoryProvider)
      .write(const Wallet(coins: 100000));
  if (withWebhooks) await seedWebhooks(container);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const WakeOrPayApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  await toggle(tester, '覚悟');
  return container;
}

Future<Alarm> save(WidgetTester tester, ProviderContainer container) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  return (await container.read(alarmRepositoryProvider).getAll()).single;
}

void main() {
  setUp(() {
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

  testWidgets('every registered 共有先 is listed, none of them ticked', (
    tester,
  ) async {
    await openNewAlarm(tester);

    await inWebhookList(tester, () async {
      expect(find.widgetWithText(AppBar, 'Discord 共有先設定'), findsOneWidget);
      expect(find.text('みんなのサーバー/#一般'), findsOneWidget);
      expect(find.text('寝坊部/#通報'), findsOneWidget);
      expect(
        switchIn(tester, 'w1').value,
        isFalse,
        reason: 'the list is app-wide; this alarm posts nowhere yet',
      );
      expect(switchIn(tester, 'w2').value, isFalse);
    });
  });

  testWidgets('ticking one puts its id on the alarm and leaves the other', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);

    await inWebhookList(tester, () async {
      await tester.tap(find.byKey(const ValueKey('webhook-w2')));
      await tester.pumpAndSettle();
      expect(switchIn(tester, 'w2').value, isTrue);
      expect(switchIn(tester, 'w1').value, isFalse);
    });

    final alarm = await save(tester, container);
    expect(alarm.share!.webhookIds, {'w2'});
    expect(
      await container.read(discordWebhookRepositoryProvider).getAll(),
      hasLength(2),
      reason: 'a tick is per alarm and never touches the shared list',
    );
  });

  testWidgets('unticking the last one takes the share off the alarm', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);

    await inWebhookList(tester, () async {
      await tester.tap(find.byKey(const ValueKey('webhook-w1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('webhook-w1')));
      await tester.pumpAndSettle();
      expect(switchIn(tester, 'w1').value, isFalse);
    });

    expect(
      (await save(tester, container)).share,
      isNull,
      reason: 'a share with nowhere to post would read back as 設定済み',
    );
  });

  // The three tests that used to live here — a bad URL refused at
  // webhookUrlField, a good URL prefilling 表示名 from a GET, and a failed
  // lookup still saving with a hand-typed name — all exercised
  // 「Webhook URL を手動で登録」 (webhookAdd / webhookUrlField / webhookNameField /
  // webhookSave), which is gone with `DiscordWebhookForm` (段階F). There is
  // now exactly one way to register a 共有先: 「チャンネルを連携」, covered end to
  // end in test/services/discord_channel_linker_test.dart and, for the "no
  // 連携サーバー built in" case, in test/features/discord_channel_link_test.dart.

  testWidgets('テスト送信 posts one line to that 共有先 and says so', (tester) async {
    final http = FakeHttpClient();
    await openNewAlarm(tester, http: http);

    await inWebhookList(tester, () async {
      expect(
        find.textContaining('長押しすると テスト送信'),
        findsOneWidget,
        reason: 'a gesture nobody is told about is a feature nobody has',
      );

      await tester.longPress(find.byKey(const ValueKey('webhook-w2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('webhookTestSend')));
      await tester.pumpAndSettle();

      expect(http.posted, hasLength(1));
      expect(
        http.posted.single.url,
        'https://discord.com/api/webhooks/2/bbb',
        reason: 'the row that was long-pressed, not the first one',
      );
      expect(http.posted.single.content, 'Wake or Pay のテスト送信です');
      expect(
        http.posted.single.filenames,
        isEmpty,
        reason: 'a URL check attaches nothing',
      );
      expect(find.text('テスト送信しました'), findsOneWidget);
    });
  });

  testWidgets('a テスト送信 that fails says which failure it was', (tester) async {
    // 404: the webhook was deleted in Discord — the exact case this feature
    // exists to catch before 6am does.
    final http = FakeHttpClient(postStatus: 404);
    await openNewAlarm(tester, http: http);

    await inWebhookList(tester, () async {
      await tester.longPress(find.byKey(const ValueKey('webhook-w1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('webhookTestSend')));
      await tester.pumpAndSettle();

      expect(find.text('失敗（HTTP 404）'), findsOneWidget);
      expect(find.text('テスト送信しました'), findsNothing);
    });
  });

  testWidgets('名前を変更 renames the 共有先 and the list shows the new name', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);

    await inWebhookList(tester, () async {
      await tester.longPress(find.byKey(const ValueKey('webhook-w1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('webhookRename')));
      await tester.pumpAndSettle();

      // Pre-filled with the current name.
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('webhookRenameField')),
      );
      expect(field.controller!.text, 'みんなのサーバー/#一般');

      await tester.enterText(
        find.byKey(const ValueKey('webhookRenameField')),
        'みんなのサーバー/#報告',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('webhookRenameSave')));
      await tester.pumpAndSettle();

      // The renamed row is in the list; the other one is untouched.
      expect(find.text('みんなのサーバー/#報告'), findsOneWidget);
      expect(find.text('みんなのサーバー/#一般'), findsNothing);
      expect(find.text('寝坊部/#通報'), findsOneWidget);
    });

    final saved = await container.read(discordWebhookRepositoryProvider).getAll();
    expect(
      saved.firstWhere((w) => w.id == 'w1').displayName,
      'みんなのサーバー/#報告',
    );
    expect(saved, hasLength(2), reason: 'a rename edits the row, never adds one');
  });

  testWidgets('an empty 名前を変更 is rejected — 保存 stays disabled', (
    tester,
  ) async {
    final container = await openNewAlarm(tester);

    await inWebhookList(tester, () async {
      await tester.longPress(find.byKey(const ValueKey('webhook-w1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('webhookRename')));
      await tester.pumpAndSettle();

      // 保存 is enabled while the pre-filled name stands.
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('webhookRenameSave')),
            )
            .onPressed,
        isNotNull,
      );

      // Clear it: a nameless row could not be picked out of the list, so 保存
      // greys out and there is no way to commit the empty name.
      await tester.enterText(
        find.byKey(const ValueKey('webhookRenameField')),
        '   ',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('webhookRenameSave')),
            )
            .onPressed,
        isNull,
        reason: 'an empty name is rejected',
      );
    });

    // Nothing was written: the name is still the seed value.
    final saved = await container.read(discordWebhookRepositoryProvider).getAll();
    expect(
      saved.firstWhere((w) => w.id == 'w1').displayName,
      'みんなのサーバー/#一般',
    );
  });

  testWidgets(
    'a 204 delete removes the row and DELETEs the remote webhook',
    (tester) async {
      // Discord answers a webhook delete with 204: both the remote webhook and
      // the local row go.
      final http = FakeHttpClient(deleteStatus: 204);
      final container = await openNewAlarm(tester, http: http);

      await inWebhookList(tester, () async {
        await tester.longPress(find.byKey(const ValueKey('webhook-w1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('削除'));
        await tester.pumpAndSettle();

        // The confirm dialog now says both are removed.
        expect(find.text('みんなのサーバー/#一般 を削除しますか？'), findsOneWidget);
        expect(
          find.text('Discord 上の Webhook も削除され、この連携先には投稿できなくなります。'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('webhookDeleteConfirm')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('webhook-w1')), findsNothing);
        expect(find.byKey(const ValueKey('webhook-w2')), findsOneWidget);
        expect(find.text('削除しました'), findsOneWidget);
      });

      expect(
        http.deleted.single,
        'https://discord.com/api/webhooks/1/aaa',
        reason: 'the DELETE went out against the long-pressed row, bare URL',
      );
      expect(
        (await container.read(discordWebhookRepositoryProvider).getAll()).single
            .id,
        'w2',
      );
    },
  );

  testWidgets(
    'a network error offers 一覧から消す (local only) — which removes the row',
    (tester) async {
      // The DELETE never reaches Discord. The row must still be removable, but
      // only after the user is told the remote webhook may survive.
      final http = FakeHttpClient(throws: true);
      final container = await openNewAlarm(tester, http: http);

      await inWebhookList(tester, () async {
        await tester.longPress(find.byKey(const ValueKey('webhook-w1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('削除'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('webhookDeleteConfirm')));
        await tester.pumpAndSettle();

        // The second dialog: the remote delete failed, so it asks.
        expect(
          find.textContaining('Discord 上の Webhook を削除できませんでした（通信エラー）'),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('webhookDeleteLocalOnly')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('webhook-w1')), findsNothing);
        expect(find.byKey(const ValueKey('webhook-w2')), findsOneWidget);
        expect(find.text('一覧から消しました'), findsOneWidget);
      });

      expect(
        (await container.read(discordWebhookRepositoryProvider).getAll()).single
            .id,
        'w2',
      );
    },
  );

  testWidgets(
    'a network error with 中止 keeps everything — remote and local',
    (tester) async {
      final http = FakeHttpClient(throws: true);
      final container = await openNewAlarm(tester, http: http);

      await inWebhookList(tester, () async {
        await tester.longPress(find.byKey(const ValueKey('webhook-w1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('削除'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('webhookDeleteConfirm')));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Discord 上の Webhook を削除できませんでした（通信エラー）'),
          findsOneWidget,
        );

        await tester.tap(find.text('中止'));
        await tester.pumpAndSettle();

        // Nothing was removed: both rows are still there.
        expect(find.byKey(const ValueKey('webhook-w1')), findsOneWidget);
        expect(find.byKey(const ValueKey('webhook-w2')), findsOneWidget);
      });

      expect(
        await container.read(discordWebhookRepositoryProvider).getAll(),
        hasLength(2),
        reason: '中止 keeps the list untouched when Discord is unreachable',
      );
    },
  );
}
