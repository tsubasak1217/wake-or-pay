import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/services/discord_oauth.dart';

import '../helpers.dart';

const _identityUrl = 'https://discord.com/api/users/@me';
const _identityBody =
    '{"id":"123456789012345678","username":"hanako",'
    '"global_name":"花子","avatar":"abc"}';

void main() {
  test('a completed flow returns the identity, and the token is only spent '
      'on /users/@me', () async {
    final http = FakeHttpClient(responses: {_identityUrl: _identityBody});
    final authorizer = FakeOAuthAuthorizer(
      (url) => 'wakeorpay://discord/callback'
          '#access_token=TOK&state=${stateOf(url)}',
    );
    final container = await testContainer(
      extra: [fakeHttpClientOverride(http), fakeOAuthAuthorizerOverride(authorizer)],
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
    final http = FakeHttpClient(responses: {_identityUrl: _identityBody});
    final authorizer = FakeOAuthAuthorizer(
      (url) => 'wakeorpay://discord/callback'
          '#access_token=TOK&state=${stateOf(url)}',
    );
    final container = await testContainer(
      extra: [fakeHttpClientOverride(http), fakeOAuthAuthorizerOverride(authorizer)],
    );
    await container.read(discordOAuthServiceProvider).link();

    final opened = Uri.parse(authorizer.opened.single);
    expect(opened.queryParameters['response_type'], 'token');
    expect(opened.queryParameters['scope'], 'identify');
    expect(opened.queryParameters['prompt'], 'consent');
  });

  test('every flow gets its own state', () async {
    final http = FakeHttpClient(responses: {_identityUrl: _identityBody});
    final authorizer = FakeOAuthAuthorizer(
      (url) => 'wakeorpay://discord/callback'
          '#access_token=TOK&state=${stateOf(url)}',
    );
    final container = await testContainer(
      extra: [fakeHttpClientOverride(http), fakeOAuthAuthorizerOverride(authorizer)],
    );
    final service = container.read(discordOAuthServiceProvider);
    await service.link();
    await service.link();

    expect(stateOf(authorizer.opened[0]), isNot(stateOf(authorizer.opened[1])));
  });

  test('a callback with somebody else’s state never reaches Discord', () async {
    final http = FakeHttpClient(responses: {_identityUrl: _identityBody});
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(http),
        fakeOAuthAuthorizerOverride(
          FakeOAuthAuthorizer(
            (_) => 'wakeorpay://discord/callback'
                '#access_token=TOK&state=not-the-one',
          ),
        ),
      ],
    );

    final result = await container.read(discordOAuthServiceProvider).link();

    expect(result.status, DiscordLinkStatus.stateMismatch);
    expect(result.identity, isNull);
    // The whole point: a token from a callback this app did not start is not
    // used for anything at all.
    expect(http.requested, isEmpty);
  });

  test('closing the browser is a cancel, not an error', () async {
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(FakeHttpClient()),
        fakeOAuthAuthorizerOverride(FakeOAuthAuthorizer.cancelled()),
      ],
    );
    final result = await container.read(discordOAuthServiceProvider).link();
    expect(result.status, DiscordLinkStatus.cancelled);
    expect(result.label, '連携をやめました');
  });

  test('Discord refusing is denied', () async {
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(FakeHttpClient()),
        fakeOAuthAuthorizerOverride(
          FakeOAuthAuthorizer(
            (url) => 'wakeorpay://discord/callback'
                '?error=access_denied&state=${stateOf(url)}',
          ),
        ),
      ],
    );
    expect(
      (await container.read(discordOAuthServiceProvider).link()).status,
      DiscordLinkStatus.denied,
    );
  });

  test('a 401 from /users/@me is a value, not a throw', () async {
    // Nothing registered for the URL, so the fake answers 404.
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(FakeHttpClient()),
        fakeOAuthAuthorizerOverride(
          FakeOAuthAuthorizer(
            (url) => 'wakeorpay://discord/callback'
                '#access_token=TOK&state=${stateOf(url)}',
          ),
        ),
      ],
    );
    expect(
      (await container.read(discordOAuthServiceProvider).link()).status,
      DiscordLinkStatus.identityFailed,
    );
  });

  test('being offline is a value too', () async {
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(FakeHttpClient(throws: true)),
        fakeOAuthAuthorizerOverride(
          FakeOAuthAuthorizer(
            (url) => 'wakeorpay://discord/callback'
                '#access_token=TOK&state=${stateOf(url)}',
          ),
        ),
      ],
    );
    expect(
      (await container.read(discordOAuthServiceProvider).link()).status,
      DiscordLinkStatus.identityFailed,
    );
  });

  test('no access token is ever written to prefs', () async {
    final http = FakeHttpClient(responses: {_identityUrl: _identityBody});
    final container = await testContainer(
      extra: [
        fakeHttpClientOverride(http),
        fakeOAuthAuthorizerOverride(
          FakeOAuthAuthorizer(
            (url) => 'wakeorpay://discord/callback'
                '#access_token=SUPERSECRET&state=${stateOf(url)}',
          ),
        ),
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
  });
}
