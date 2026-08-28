import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/discord_oauth.dart';
import 'package:wake_or_pay/features/alarms/discord_webhooks_screen.dart';
import 'package:wake_or_pay/services/discord_exchange.dart';

import '../helpers.dart';

/// 「チャンネルを連携」 on the 共有先設定 screen — the widget's own wiring, not the
/// [DiscordChannelLinker] logic behind it (that lives in
/// test/services/discord_channel_linker_test.dart, which passes `endpoint:`
/// explicitly and so does not depend on this build's own constant).
///
/// The widget always calls `.link()` with **no** `endpoint` argument, so it
/// can only ever act on [kDiscordExchangeEndpoint] as this build set it —
/// there is no prefs row to override it with any more (段階F removed
/// 連携サーバーURL entirely). Everything below branches on whether that constant
/// is empty (a legitimate fork with 「チャンネルを連携」 disabled) or a real
/// deployed Worker, so this file passes either way a build is configured.
const _exchangeUrl = '$kDiscordExchangeEndpoint/discord/exchange';

const _grantBody =
    '{"webhook":{"id":"999","url":"https://discord.com/api/webhooks/999/TOK",'
    '"channel_id":"222","guild_id":"111","name":"Wake or Pay"},'
    '"guild_name":"みんなのサーバー","channel_name":null}';

Future<ProviderContainer> pumpScreen(
  WidgetTester tester, {
  List<Override> extra = const [],
  Set<String> initial = const {},
}) async {
  final container = await testContainer(extra: extra);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: DiscordWebhooksSubScreen(initial: initial, onCommit: (_) {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('チャンネルを連携 is the only way in — the manual button is gone', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('チャンネルを連携（Discord で選ぶ）'), findsOneWidget);
    expect(find.text('Webhook URL を手動で登録'), findsNothing);
    expect(find.byKey(const ValueKey('webhookAdd')), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  if (kDiscordExchangeEndpoint.isEmpty) {
    testWidgets(
      'with no 連携サーバー built in, the button explains what is missing and '
      'touches nothing',
      (tester) async {
        final http = FakeHttpClient();
        final container = await pumpScreen(
          tester,
          extra: [fakeHttpClientOverride(http)],
        );

        await tester.tap(find.byKey(const ValueKey('webhookLinkChannel')));
        await tester.pumpAndSettle();

        // No browser or Discord app is opened at all: there is nowhere for a
        // code to go, so nothing is worth asking Discord for.
        expect(http.requested, isEmpty);
        expect(http.posted, isEmpty);
        expect(
          await container.read(discordWebhookRepositoryProvider).getAll(),
          isEmpty,
        );
        expect(find.textContaining('連携サーバーが設定されていないビルドです'), findsWidgets);
      },
    );
    return;
  }

  // This build has a real kDiscordExchangeEndpoint baked in, so the button
  // can actually complete a flow — exercised over the same fakes as the
  // service-level tests, through the real widget this time.
  testWidgets('連携 registers the webhook and ticks it on for this alarm', (
    tester,
  ) async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final http = FakeHttpClient(postStatus: 200, postBody: _grantBody);
    final launcher = FakeDiscordAuthLauncher(
      links,
      replyWith: (url) => 'wakeorpay://discord/callback'
          '?code=THE_CODE&state=${stateOf(url)}',
    );
    final container = await pumpScreen(
      tester,
      extra: [
        fakeHttpClientOverride(http),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('webhookLinkChannel')));
    await tester.pumpAndSettle();

    // The authorize URL asked for the channel picker, not a bare identity.
    final opened = Uri.parse(launcher.opened.single);
    expect(opened.queryParameters['response_type'], 'code');
    expect(opened.queryParameters['scope'], 'webhook.incoming identify guilds');

    // The code went to the 連携サーバー, with the same redirect that went out.
    final post = http.posted.single;
    expect(post.url, _exchangeUrl);
    final sent = jsonDecode(post.body) as Map;
    expect(sent['code'], 'THE_CODE');
    expect(sent['redirect_uri'], kDiscordRedirectUri);

    final saved = await container.read(discordWebhookRepositoryProvider).getAll();
    expect(saved.single.id, '999');
    expect(saved.single.url, 'https://discord.com/api/webhooks/999/TOK');
    // channel_name needs a scope this app does not ask for, so the server
    // name alone is the label.
    expect(saved.single.displayName, 'みんなのサーバー');

    // Somebody who just picked a channel meant to post there.
    final tile = tester.widget<SwitchListTile>(
      find.descendant(
        of: find.byKey(const ValueKey('webhook-999')),
        matching: find.byType(SwitchListTile),
      ),
    );
    expect(tile.value, isTrue);
    // The status line names which 共有先 — 「共有先を追加しました：みんなのサーバー」 — not
    // the bare label alone.
    expect(find.textContaining('共有先を追加しました'), findsWidgets);
  });

  testWidgets('a wrong state never reaches the 連携サーバー', (tester) async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final http = FakeHttpClient(postStatus: 200, postBody: _grantBody);
    final launcher = FakeDiscordAuthLauncher(
      links,
      replyWith: (_) => 'wakeorpay://discord/callback'
          '?code=C&state=not-the-one',
    );
    final container = await pumpScreen(
      tester,
      extra: [
        fakeHttpClientOverride(http),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('webhookLinkChannel')));
    await tester.pumpAndSettle();

    expect(http.posted, isEmpty);
    expect(
      await container.read(discordWebhookRepositoryProvider).getAll(),
      isEmpty,
    );
    expect(find.text('確認に失敗しました。アプリからもう一度お試しください'), findsWidgets);
  });

  testWidgets('a 連携サーバー that refuses saves nothing and says so', (
    tester,
  ) async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final http = FakeHttpClient(postStatus: 500);
    final launcher = FakeDiscordAuthLauncher(
      links,
      replyWith: (url) => 'wakeorpay://discord/callback'
          '?code=C&state=${stateOf(url)}',
    );
    final container = await pumpScreen(
      tester,
      extra: [
        fakeHttpClientOverride(http),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('webhookLinkChannel')));
    await tester.pumpAndSettle();

    expect(http.posted, hasLength(1));
    expect(
      await container.read(discordWebhookRepositoryProvider).getAll(),
      isEmpty,
    );
    expect(find.text('チャンネルを連携できませんでした（連携サーバーの応答なし）'), findsWidgets);
  });

  testWidgets('no Discord app or browser says so', (tester) async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final launcher = FakeDiscordAuthLauncher.noApp(links);
    final container = await pumpScreen(
      tester,
      extra: [
        fakeHttpClientOverride(FakeHttpClient()),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('webhookLinkChannel')));
    await tester.pumpAndSettle();

    expect(
      await container.read(discordWebhookRepositoryProvider).getAll(),
      isEmpty,
    );
    expect(find.text('ブラウザが見つかりませんでした'), findsWidgets);
  });

  testWidgets('やめる leaves nothing saved', (tester) async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    // No replyWith: the flow sits in 承認待ち until the test cancels it.
    final launcher = FakeDiscordAuthLauncher(links);
    final container = await pumpScreen(
      tester,
      extra: [
        fakeHttpClientOverride(FakeHttpClient()),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('webhookLinkChannel')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('discordFlowCancel')));
    await tester.pumpAndSettle();

    expect(
      await container.read(discordWebhookRepositoryProvider).getAll(),
      isEmpty,
    );
    expect(find.text('連携をやめました'), findsWidgets);
  });
}
