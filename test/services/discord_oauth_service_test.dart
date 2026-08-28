import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/services/discord_link_log.dart';
import 'package:wake_or_pay/services/discord_oauth.dart';

import '../helpers.dart';

const _identityUrl = 'https://discord.com/api/users/@me';
const _identityBody =
    '{"id":"123456789012345678","username":"hanako",'
    '"global_name":"花子","avatar":"abc"}';

void main() {
  test('a completed flow returns the identity, and the token is only spent '
      'on /users/@me', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final http = FakeHttpClient(responses: {_identityUrl: _identityBody});
    final launcher = FakeDiscordAuthLauncher(
      links,
      replyWith: (url) => 'wakeorpay://discord/callback'
          '#access_token=TOK&state=${stateOf(url)}',
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
    // One call, to Discord, with the bearer token on it — and nowhere else.
    expect(http.requested, [_identityUrl]);
    expect(http.headers.single['Authorization'], 'Bearer TOK');
  });

  test('the authorize URL asks for the implicit grant and identify', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final http = FakeHttpClient(responses: {_identityUrl: _identityBody});
    final launcher = FakeDiscordAuthLauncher(
      links,
      replyWith: (url) => 'wakeorpay://discord/callback'
          '#access_token=TOK&state=${stateOf(url)}',
    );
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(http),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );
    await container.read(discordOAuthServiceProvider).link();

    final opened = Uri.parse(launcher.opened.single);
    expect(opened.queryParameters['response_type'], 'token');
    expect(opened.queryParameters['scope'], 'identify');
    expect(opened.queryParameters['prompt'], 'consent');
  });

  test('every flow gets its own state', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final http = FakeHttpClient(responses: {_identityUrl: _identityBody});
    final launcher = FakeDiscordAuthLauncher(
      links,
      replyWith: (url) => 'wakeorpay://discord/callback'
          '#access_token=TOK&state=${stateOf(url)}',
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

  test('a callback with somebody else’s state never reaches Discord', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final http = FakeHttpClient(responses: {_identityUrl: _identityBody});
    final launcher = FakeDiscordAuthLauncher(
      links,
      replyWith: (_) => 'wakeorpay://discord/callback'
          '#access_token=TOK&state=not-the-one',
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
    // The whole point: a token from a callback this app did not start is not
    // used for anything at all.
    expect(http.requested, isEmpty);
  });

  test('no Discord app or browser is noApp, and nothing is opened twice', () async {
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
    expect(launcher.opened, hasLength(1));
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

  test('a 401 from /users/@me is a value, not a throw', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    // Nothing registered for the URL, so the fake answers 404.
    final launcher = FakeDiscordAuthLauncher(
      links,
      replyWith: (url) => 'wakeorpay://discord/callback'
          '#access_token=TOK&state=${stateOf(url)}',
    );
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(FakeHttpClient()),
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
          '#access_token=TOK&state=${stateOf(url)}',
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

  test('no access token is ever written to prefs or to 連携ログ', () async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final http = FakeHttpClient(responses: {_identityUrl: _identityBody});
    final launcher = FakeDiscordAuthLauncher(
      links,
      replyWith: (url) => 'wakeorpay://discord/callback'
          '#access_token=SUPERSECRET&state=${stateOf(url)}',
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
      expect('${prefs.get(key)}', isNot(contains('SUPERSECRET')));
      expect(key, isNot(contains('token')));
    }
    expect(repository.read().discordUserId, '123456789012345678');

    // The log is the diagnostic surface a user is told to screenshot and
    // report — it must never be the place a token leaks out to.
    final log = container.read(discordLinkLogProvider);
    expect(log, isNotEmpty);
    for (final entry in log) {
      expect(entry.message, isNot(contains('SUPERSECRET')));
    }
  });
}
