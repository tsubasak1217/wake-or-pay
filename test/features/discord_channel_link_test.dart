import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/features/alarms/discord_webhooks_screen.dart';
import 'package:wake_or_pay/services/discord_exchange.dart';

import '../helpers.dart';

const _endpoint = 'https://wake-or-pay-discord.example.workers.dev';
const _exchangeUrl = '$_endpoint/discord/exchange';

const _grantBody =
    '{"webhook":{"id":"999","url":"https://discord.com/api/webhooks/999/TOK",'
    '"channel_id":"222","guild_id":"111","name":"Wake or Pay"},'
    '"guild_name":"みんなのサーバー","channel_name":null}';

/// The 共有先 screen on its own, with whatever fakes the test needs.
Future<ProviderContainer> pumpScreen(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  List<Override> extra = const [],
  Set<String> initial = const {},
}) async {
  final container = await testContainer(prefs: prefs, extra: extra);
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
  testWidgets('both ways in are named, and the ＋ is gone', (tester) async {
    await pumpScreen(tester);

    expect(find.text('チャンネルを連携（Discord で選ぶ）'), findsOneWidget);
    expect(find.text('Webhook URL を手動で登録'), findsOneWidget);
    // The old ＋ hid the only way in behind an icon, and behind five steps in
    // another app.
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('連携 registers the webhook and ticks it on for this alarm', (
    tester,
  ) async {
    final http = FakeHttpClient(postStatus: 200, postBody: _grantBody);
    final authorizer = FakeOAuthAuthorizer(
      (url) => 'wakeorpay://discord/callback?code=THE_CODE&state=${stateOf(url)}',
    );
    final container = await pumpScreen(
      tester,
      prefs: {kDiscordExchangeEndpointPrefsKey: _endpoint},
      extra: [
        fakeHttpClientOverride(http),
        fakeOAuthAuthorizerOverride(authorizer),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('webhookLinkChannel')));
    await tester.pumpAndSettle();

    // The authorize URL asked for the channel picker, not a bare identity.
    final opened = Uri.parse(authorizer.opened.single);
    expect(opened.queryParameters['response_type'], 'code');
    expect(opened.queryParameters['scope'], 'webhook.incoming identify');

    // The code went to the 連携サーバー, with the same redirect that went out.
    final post = http.posted.single;
    expect(post.url, _exchangeUrl);
    final sent = jsonDecode(post.body) as Map;
    expect(sent['code'], 'THE_CODE');
    expect(sent['redirect_uri'], 'wakeorpay://discord/callback');

    final saved = await container.read(discordWebhookRepositoryProvider).getAll();
    expect(saved.single.id, '999');
    expect(saved.single.url, 'https://discord.com/api/webhooks/999/TOK');
    // channel_name needs a scope this app does not ask for, so the server
    // name alone is the label.
    expect(saved.single.displayName, 'みんなのサーバー');

    await tester.pumpAndSettle();
    // Somebody who just picked a channel meant to post there.
    final tile = tester.widget<SwitchListTile>(
      find.descendant(
        of: find.byKey(const ValueKey('webhook-999')),
        matching: find.byType(SwitchListTile),
      ),
    );
    expect(tile.value, isTrue);
    expect(find.text('共有先を追加しました'), findsWidgets);
  });

  testWidgets('with no 連携サーバー the button explains what is missing', (
    tester,
  ) async {
    final http = FakeHttpClient(postStatus: 200, postBody: _grantBody);
    final authorizer = FakeOAuthAuthorizer(
      (url) => 'wakeorpay://discord/callback?code=C&state=${stateOf(url)}',
    );
    final container = await pumpScreen(
      tester,
      extra: [
        fakeHttpClientOverride(http),
        fakeOAuthAuthorizerOverride(authorizer),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('webhookLinkChannel')));
    await tester.pumpAndSettle();

    // No browser is opened at all: there is nowhere for the code to go.
    expect(authorizer.opened, isEmpty);
    expect(http.posted, isEmpty);
    expect(
      await container.read(discordWebhookRepositoryProvider).getAll(),
      isEmpty,
    );
    expect(find.textContaining('連携サーバー'), findsWidgets);
  });

  testWidgets('a wrong state never reaches the 連携サーバー', (tester) async {
    final http = FakeHttpClient(postStatus: 200, postBody: _grantBody);
    final container = await pumpScreen(
      tester,
      prefs: {kDiscordExchangeEndpointPrefsKey: _endpoint},
      extra: [
        fakeHttpClientOverride(http),
        fakeOAuthAuthorizerOverride(
          FakeOAuthAuthorizer(
            (_) => 'wakeorpay://discord/callback?code=C&state=not-the-one',
          ),
        ),
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
    final http = FakeHttpClient(postStatus: 500);
    final container = await pumpScreen(
      tester,
      prefs: {kDiscordExchangeEndpointPrefsKey: _endpoint},
      extra: [
        fakeHttpClientOverride(http),
        fakeOAuthAuthorizerOverride(
          FakeOAuthAuthorizer(
            (url) =>
                'wakeorpay://discord/callback?code=C&state=${stateOf(url)}',
          ),
        ),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('webhookLinkChannel')));
    await tester.pumpAndSettle();

    expect(http.posted, hasLength(1));
    expect(
      await container.read(discordWebhookRepositoryProvider).getAll(),
      isEmpty,
    );
    expect(find.text('チャンネルを連携できませんでした'), findsWidgets);
  });

  testWidgets('cancelling in the browser changes nothing', (tester) async {
    final container = await pumpScreen(
      tester,
      prefs: {kDiscordExchangeEndpointPrefsKey: _endpoint},
      extra: [
        fakeHttpClientOverride(FakeHttpClient()),
        fakeOAuthAuthorizerOverride(FakeOAuthAuthorizer.cancelled()),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('webhookLinkChannel')));
    await tester.pumpAndSettle();

    expect(
      await container.read(discordWebhookRepositoryProvider).getAll(),
      isEmpty,
    );
    expect(find.text('連携をやめました'), findsWidgets);
  });

  testWidgets('the manual dialog is still there behind its own button', (
    tester,
  ) async {
    final container = await pumpScreen(
      tester,
      extra: [fakeHttpClientOverride(FakeHttpClient())],
    );

    await tester.tap(find.byKey(const ValueKey('webhookAdd')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('webhookUrlField')),
      'https://discord.com/api/webhooks/1/abc',
    );
    await tester.enterText(
      find.byKey(const ValueKey('webhookNameField')),
      '手で入れた部屋',
    );
    await tester.tap(find.byKey(const ValueKey('webhookSave')));
    await tester.pumpAndSettle();

    final saved = await container.read(discordWebhookRepositoryProvider).getAll();
    expect(saved.single.displayName, '手で入れた部屋');
  });

  group('the 連携サーバーURL setting', () {
    test('an empty override falls back to the build-time constant', () async {
      final container = await testContainer();
      expect(
        container.read(discordExchangeEndpointProvider),
        kDiscordExchangeEndpoint,
      );
    });

    test('what was pasted wins, and clearing it puts the default back',
        () async {
      final container = await testContainer();
      final controller = container.read(
        discordExchangeEndpointProvider.notifier,
      );

      await controller.set('  $_endpoint/  ');
      expect(container.read(discordExchangeEndpointProvider), '$_endpoint/');

      await controller.set('');
      expect(
        container.read(discordExchangeEndpointProvider),
        kDiscordExchangeEndpoint,
      );
      expect(
        container
            .read(sharedPreferencesProvider)
            .containsKey(kDiscordExchangeEndpointPrefsKey),
        isFalse,
      );
    });

    test('a pasted URL survives a restart', () async {
      final container = await testContainer(
        prefs: {kDiscordExchangeEndpointPrefsKey: _endpoint},
      );
      expect(container.read(discordExchangeEndpointProvider), _endpoint);
    });
  });
}
