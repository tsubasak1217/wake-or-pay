import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/discord_oauth.dart';
import 'package:wake_or_pay/services/discord_exchange.dart';
import 'package:wake_or_pay/services/discord_link_log.dart';
import 'package:wake_or_pay/services/discord_oauth.dart';

import '../helpers.dart';

const _exchangeUrl = '$kDiscordExchangeEndpoint/discord/exchange';
const _identityBody =
    '{"user":{"id":"123456789012345678","username":"hanako",'
    '"global_name":"花子","avatar":"abc"}}';

void main() {
  test('a completed flow returns the identity, exchanged through the '
      '連携サーバー — and the browser-only route is logged', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final http = FakeHttpClient(postStatus: 200, postBody: _identityBody);
    final launcher = FakeDiscordAuthLauncher(
      links,
      replyWith: (url) => 'wakeorpay://discord/callback'
          '?code=CODE&state=${stateOf(url)}',
    );
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(http),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );

    final result = await container.read(discordOAuthServiceProvider).link();

    expect(result.ok, isTrue);
    expect(result.identity!.id, '123456789012345678');
    expect(result.identity!.displayName, '花子');
    // One call, to the 連携サーバー, with the code and mode: identify on it —
    // Discord itself is never contacted directly by the app any more.
    expect(http.requested, [_exchangeUrl]);
    expect(http.posted, hasLength(1));
    expect(http.posted.single.url, _exchangeUrl);
    final sent = jsonDecode(http.posted.single.body) as Map;
    expect(sent['code'], 'CODE');
    expect(sent['mode'], 'identify');
    expect(sent['redirect_uri'], kDiscordRedirectUri);

    // The Discord app registers no authorize handler at all (see
    // UrlLauncherDiscordAuthLauncher), so every flow lands in a browser —
    // and that fact is worth a 連携ログ line even though the status line
    // never mentions it.
    final log = container.read(discordLinkLogProvider);
    expect(
      log.map((e) => e.message),
      contains(kDiscordOpenedInBrowserMessage),
    );
  });

  test('the authorize URL asks for the code grant and identify', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final http = FakeHttpClient(postStatus: 200, postBody: _identityBody);
    final launcher = FakeDiscordAuthLauncher(
      links,
      replyWith: (url) => 'wakeorpay://discord/callback'
          '?code=CODE&state=${stateOf(url)}',
    );
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(http),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );
    await container.read(discordOAuthServiceProvider).link();

    final opened = Uri.parse(launcher.opened.single);
    expect(opened.queryParameters['response_type'], 'code');
    expect(opened.queryParameters['scope'], 'identify');
    expect(opened.queryParameters['prompt'], 'consent');
    expect(opened.queryParameters['redirect_uri'], kDiscordRedirectUri);
  });

  test('every flow gets its own state', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final http = FakeHttpClient(postStatus: 200, postBody: _identityBody);
    final launcher = FakeDiscordAuthLauncher(
      links,
      replyWith: (url) => 'wakeorpay://discord/callback'
          '?code=CODE&state=${stateOf(url)}',
    );
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(http),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );
    final service = container.read(discordOAuthServiceProvider);
    await service.link();
    await service.link();

    expect(
      stateOf(launcher.opened[0]),
      isNot(stateOf(launcher.opened[1])),
    );
  });

  test('a callback with somebody else’s state never reaches the 連携サーバー', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final http = FakeHttpClient(postStatus: 200, postBody: _identityBody);
    final launcher = FakeDiscordAuthLauncher(
      links,
      replyWith: (_) => 'wakeorpay://discord/callback'
          '?code=CODE&state=not-the-one',
    );
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(http),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );

    final result = await container.read(discordOAuthServiceProvider).link();

    expect(result.status, DiscordLinkStatus.stateMismatch);
    expect(result.identity, isNull);
    // The whole point: a code from a callback this app did not start is not
    // spent on anything at all.
    expect(http.posted, isEmpty);
  });

  test('no browser is noApp, and nothing is opened twice', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final launcher = FakeDiscordAuthLauncher.noApp(links);
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(FakeHttpClient()),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );

    final result = await container.read(discordOAuthServiceProvider).link();

    expect(result.status, DiscordLinkStatus.noApp);
    expect(result.label, 'ブラウザが見つかりませんでした');
    expect(launcher.opened, hasLength(1));
  });

  test('link(endpoint: \'\') yields noEndpoint before opening anything', () async {
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
        .read(discordOAuthServiceProvider)
        .link(endpoint: '');

    expect(result.status, DiscordLinkStatus.noEndpoint);
    // No browser was opened, and nothing was posted: the implicit grant is
    // gone, so with no endpoint there is nowhere for a code to be spent.
    expect(launcher.opened, isEmpty);
  });

  test('calling cancel() while waiting ends the flow as cancelled, not an '
      'error', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    // No replyWith: nothing ever answers on its own, so the flow is still in
    // the air when cancel() is called below.
    final launcher = FakeDiscordAuthLauncher.silent(links);
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(FakeHttpClient()),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );
    final service = container.read(discordOAuthServiceProvider);

    final future = service.link();
    // Give the fake launcher's open() a turn to resolve so the flow is
    // sitting at 承認待ち, the state cancel() is meant to interrupt.
    await Future<void>.delayed(const Duration(milliseconds: 1));
    service.cancel();
    final result = await future;

    expect(result.status, DiscordLinkStatus.cancelled);
    expect(result.label, '連携をやめました');
  });

  test('five minutes of silence is a timeout, not a hang', () async {
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
        .read(discordOAuthServiceProvider)
        .link(timeout: const Duration(milliseconds: 10));

    expect(result.status, DiscordLinkStatus.timedOut);
    expect(result.label, kDiscordTimedOutMessage);
  });

  test('Discord refusing is denied', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final launcher = FakeDiscordAuthLauncher(
      links,
      replyWith: (url) => 'wakeorpay://discord/callback'
          '?error=access_denied&state=${stateOf(url)}',
    );
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(FakeHttpClient()),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );
    expect(
      (await container.read(discordOAuthServiceProvider).link()).status,
      DiscordLinkStatus.denied,
    );
  });

  test('a 連携サーバー that refuses the exchange is identityFailed', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final http = FakeHttpClient(postStatus: 500);
    final launcher = FakeDiscordAuthLauncher(
      links,
      replyWith: (url) => 'wakeorpay://discord/callback'
          '?code=CODE&state=${stateOf(url)}',
    );
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(http),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );
    expect(
      (await container.read(discordOAuthServiceProvider).link()).status,
      DiscordLinkStatus.identityFailed,
    );
  });

  test('being offline is a value too', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final launcher = FakeDiscordAuthLauncher(
      links,
      replyWith: (url) => 'wakeorpay://discord/callback'
          '?code=CODE&state=${stateOf(url)}',
    );
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(FakeHttpClient(throws: true)),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );
    expect(
      (await container.read(discordOAuthServiceProvider).link()).status,
      DiscordLinkStatus.identityFailed,
    );
  });

  test('no authorization code is ever written to prefs or to 連携ログ', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final http = FakeHttpClient(postStatus: 200, postBody: _identityBody);
    final launcher = FakeDiscordAuthLauncher(
      links,
      replyWith: (url) => 'wakeorpay://discord/callback'
          '?code=SUPERSECRETCODE&state=${stateOf(url)}',
    );
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(http),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );
    final result = await container.read(discordOAuthServiceProvider).link();
    final repository = container.read(profileRepositoryProvider);
    await repository.update(
      (p) => p.copyWith(
        discordUserId: result.identity!.id,
        discordUsername: result.identity!.displayName,
        discordAvatar: result.identity!.avatar,
      ),
    );

    final prefs = container.read(sharedPreferencesProvider);
    for (final key in prefs.getKeys()) {
      expect('${prefs.get(key)}', isNot(contains('SUPERSECRETCODE')));
      expect(key, isNot(contains('token')));
    }
    expect(repository.read().discordUserId, '123456789012345678');

    // The log is the diagnostic surface a user is told to screenshot and
    // report — it must never be the place a code (or anything else that can
    // be spent) leaks out to.
    final log = container.read(discordLinkLogProvider);
    expect(log, isNotEmpty);
    for (final entry in log) {
      expect(entry.message, isNot(contains('SUPERSECRETCODE')));
    }
  });
}
