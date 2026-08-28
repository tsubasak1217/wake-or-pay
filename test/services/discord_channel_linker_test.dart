import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/discord_oauth.dart';
import 'package:wake_or_pay/services/discord_exchange.dart';
import 'package:wake_or_pay/services/discord_oauth.dart';

import '../helpers.dart';

/// [DiscordChannelLinker] end to end — the counterpart to
/// discord_oauth_service_test.dart, for 「チャンネルを連携」 rather than
/// 「Discord で連携」.
///
/// Every one of these passes `endpoint:` explicitly rather than relying on
/// this build's own [kDiscordExchangeEndpoint] (see discord_exchange.dart),
/// which may be empty on a fork with 「チャンネルを連携」 disabled — the widget
/// itself, which calls `.link()` with no argument, is what exercises that
/// constant, covered in discord_channel_link_test.dart. Here the exchange is
/// supplied by hand so the test passes regardless of which build it runs
/// against.
const _endpoint = 'https://example.com';
const _exchangeUrl = '$_endpoint/discord/exchange';

const _grantBody =
    '{"webhook":{"id":"999","url":"https://discord.com/api/webhooks/999/TOK",'
    '"channel_id":"222","guild_id":"111","name":"Wake or Pay"},'
    '"guild_name":"みんなのサーバー","channel_name":null}';

void main() {
  test('a completed code grant is exchanged with the same redirect URI that '
      'went out', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final http = FakeHttpClient(postStatus: 200, postBody: _grantBody);
    final launcher = FakeDiscordAuthLauncher(
      links,
      replyWith: (url) => 'wakeorpay://discord/callback'
          '?code=THE_CODE&state=${stateOf(url)}',
    );
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(http),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );

    final result = await container
        .read(discordChannelLinkerProvider)
        .link(endpoint: _endpoint);

    expect(result.ok, isTrue);
    expect(result.grant!.id, '999');
    expect(result.grant!.displayName, 'みんなのサーバー');

    final post = http.posted.single;
    expect(post.url, _exchangeUrl);
    final sent = jsonDecode(post.body) as Map;
    expect(sent['code'], 'THE_CODE');
    // The same https redirect that went out with the authorize request —
    // Discord checks the two match, and the code-carrying wakeorpay:// bounce
    // it actually arrived on is never what gets sent back.
    expect(sent['redirect_uri'], kDiscordRedirectUri);
  });

  test('the authorize URL asks for the code grant and webhook.incoming, with '
      'no forced consent prompt', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final http = FakeHttpClient(postStatus: 200, postBody: _grantBody);
    final launcher = FakeDiscordAuthLauncher(
      links,
      replyWith: (url) => 'wakeorpay://discord/callback'
          '?code=C&state=${stateOf(url)}',
    );
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(http),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );
    await container.read(discordChannelLinkerProvider).link(endpoint: _endpoint);

    final opened = Uri.parse(launcher.opened.single);
    expect(opened.queryParameters['response_type'], 'code');
    expect(opened.queryParameters['scope'], 'webhook.incoming identify');
    // Picking a channel is the consent screen; forcing another one on top of
    // it is not asked for.
    expect(opened.queryParameters.containsKey('prompt'), isFalse);
  });

  test('an endpoint that is not https (e.g. empty) refuses before opening '
      'anything', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final launcher = FakeDiscordAuthLauncher(links);
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(FakeHttpClient()),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );

    final result = await container
        .read(discordChannelLinkerProvider)
        .link(endpoint: '');

    expect(result.status, DiscordChannelLinkStatus.noEndpoint);
    expect(launcher.opened, isEmpty);
  });

  test('with no endpoint argument, this build’s own kDiscordExchangeEndpoint '
      'is used', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    // noApp rather than a full success: this only has to prove the endpoint
    // check was passed (reaching the launcher at all), not that this
    // fork's own deployed Worker answers — that would need a real network
    // call, which no test here may make.
    final launcher = FakeDiscordAuthLauncher.noApp(links);
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(FakeHttpClient()),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );

    final result = await container.read(discordChannelLinkerProvider).link();

    // Robust to which build this runs against: an empty
    // kDiscordExchangeEndpoint (a legitimate fork with 「チャンネルを連携」
    // disabled) refuses at the endpoint check, while a real one reaches the
    // launcher and stops at noApp instead.
    expect(
      result.status,
      kDiscordExchangeEndpoint.isEmpty
          ? DiscordChannelLinkStatus.noEndpoint
          : DiscordChannelLinkStatus.noApp,
    );
  });

  test('no Discord app or browser is noApp', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final launcher = FakeDiscordAuthLauncher.noApp(links);
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(FakeHttpClient()),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );

    final result = await container
        .read(discordChannelLinkerProvider)
        .link(endpoint: _endpoint);

    expect(result.status, DiscordChannelLinkStatus.noApp);
  });

  test('cancel() while waiting ends the flow as cancelled', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final launcher = FakeDiscordAuthLauncher.silent(links);
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(FakeHttpClient()),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );
    final linker = container.read(discordChannelLinkerProvider);

    final future = linker.link(endpoint: _endpoint);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    linker.cancel();

    expect((await future).status, DiscordChannelLinkStatus.cancelled);
  });

  test('a timeout with no callback', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final launcher = FakeDiscordAuthLauncher.silent(links);
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(FakeHttpClient()),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );

    final result = await container
        .read(discordChannelLinkerProvider)
        .link(endpoint: _endpoint, timeout: const Duration(milliseconds: 10));

    expect(result.status, DiscordChannelLinkStatus.timedOut);
  });

  test('a wrong state never reaches the 連携サーバー', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final http = FakeHttpClient(postStatus: 200, postBody: _grantBody);
    final launcher = FakeDiscordAuthLauncher(
      links,
      replyWith: (_) => 'wakeorpay://discord/callback'
          '?code=C&state=not-the-one',
    );
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(http),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );

    final result = await container
        .read(discordChannelLinkerProvider)
        .link(endpoint: _endpoint);

    expect(result.status, DiscordChannelLinkStatus.stateMismatch);
    expect(http.posted, isEmpty);
  });

  test('denied at the picker never reaches the 連携サーバー', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final http = FakeHttpClient(postStatus: 200, postBody: _grantBody);
    final launcher = FakeDiscordAuthLauncher(
      links,
      replyWith: (url) => 'wakeorpay://discord/callback'
          '?error=access_denied&state=${stateOf(url)}',
    );
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(http),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );

    final result = await container
        .read(discordChannelLinkerProvider)
        .link(endpoint: _endpoint);

    expect(result.status, DiscordChannelLinkStatus.denied);
    expect(http.posted, isEmpty);
  });

  test('a 連携サーバー that refuses is exchangeFailed', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final http = FakeHttpClient(postStatus: 500);
    final launcher = FakeDiscordAuthLauncher(
      links,
      replyWith: (url) => 'wakeorpay://discord/callback'
          '?code=C&state=${stateOf(url)}',
    );
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(http),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );

    final result = await container
        .read(discordChannelLinkerProvider)
        .link(endpoint: _endpoint);

    expect(result.status, DiscordChannelLinkStatus.exchangeFailed);
    expect(http.posted, hasLength(1));
  });
}
