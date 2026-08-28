import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/discord_oauth.dart';

void main() {
  group('buildDiscordAuthorizeUrl', () {
    test('the code grant asks for identify only', () {
      // The implicit grant (response_type=token) is gone: both flows in this
      // app now ask for `code`, because `identify` moved onto the same
      // authorization-code exchange as `webhook.incoming`.
      final url = buildDiscordAuthorizeUrl(
        responseType: 'code',
        scopes: kDiscordIdentifyScopes,
        state: 'abc123',
        prompt: 'consent',
      );
      final uri = Uri.parse(url);

      expect(uri.scheme, 'https');
      expect(uri.host, 'discord.com');
      expect(uri.path, '/oauth2/authorize');
      expect(uri.queryParameters['client_id'], kDiscordClientId);
      expect(uri.queryParameters['response_type'], 'code');
      expect(uri.queryParameters['scope'], 'identify');
      expect(uri.queryParameters['redirect_uri'], kDiscordRedirectUri);
      expect(uri.queryParameters['state'], 'abc123');
      expect(uri.queryParameters['prompt'], 'consent');
    });

    test('the redirect URI is percent-encoded in the raw string', () {
      final url = buildDiscordAuthorizeUrl(
        responseType: 'code',
        scopes: kDiscordIdentifyScopes,
        state: 's',
      );
      // A raw `https://…` in the query is still a query-inside-a-query, and
      // an unencoded one is a URL Discord's own parser has misread before.
      expect(
        url,
        contains(
          'redirect_uri=https%3A%2F%2Fwake-or-pay-discord.wakeorpay.'
          'workers.dev%2Fdiscord%2Fcallback',
        ),
      );
      expect(url, isNot(contains('redirect_uri=https://')));
    });

    test('prompt is left out entirely when not asked for', () {
      final url = buildDiscordAuthorizeUrl(
        responseType: 'code',
        scopes: kDiscordWebhookScopes,
        state: 's',
      );
      expect(Uri.parse(url).queryParameters.containsKey('prompt'), isFalse);
    });

    test('multiple scopes are space separated', () {
      final url = buildDiscordAuthorizeUrl(
        responseType: 'code',
        scopes: kDiscordWebhookScopes,
        state: 's',
      );
      // The webhook flow now also asks for `guilds`: without it the Worker's
      // `GET /users/@me/guilds` is 401 and the server name never resolves.
      expect(
        Uri.parse(url).queryParameters['scope'],
        'webhook.incoming identify guilds',
      );
      // Spaces are `%20` here, not `+` — this builder uses Uri.encodeComponent
      // on purpose so Discord's scope parser splits on the space.
      expect(url, contains('scope=webhook.incoming%20identify%20guilds'));
    });

    test('the webhook flow asks for guilds, the identify flow does not', () {
      final webhookScope = Uri.parse(
        buildDiscordAuthorizeUrl(
          responseType: 'code',
          scopes: kDiscordWebhookScopes,
          state: 's',
        ),
      ).queryParameters['scope']!.split(' ');
      final identifyScope = Uri.parse(
        buildDiscordAuthorizeUrl(
          responseType: 'code',
          scopes: kDiscordIdentifyScopes,
          state: 's',
        ),
      ).queryParameters['scope']!.split(' ');

      // `guilds` is what lets the Worker name the server for 「チャンネルを連携」.
      expect(webhookScope, contains('guilds'));
      // 「Discord で連携」 only reads /users/@me, so it must not ask for guilds.
      expect(identifyScope, isNot(contains('guilds')));
    });
  });

  group('randomOAuthState', () {
    test('is URL safe and long enough to be unguessable', () {
      final state = randomOAuthState();
      expect(state.length, greaterThanOrEqualTo(20));
      expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(state), isTrue);
    });

    test('two calls do not agree', () {
      expect(randomOAuthState(), isNot(randomOAuthState()));
    });

    test('survives a seeded generator, for the test that needs one', () {
      expect(randomOAuthState(Random(1)), randomOAuthState(Random(1)));
    });
  });

  group('parseDiscordCallback', () {
    const state = 'st4te';
    const httpsBase =
        'https://wake-or-pay-discord.wakeorpay.workers.dev/discord/callback';

    test('reads the code out of the query', () {
      final result = parseDiscordCallback(
        'wakeorpay://discord/callback?code=CODE&state=$state',
        expectedState: state,
      );
      expect(result.ok, isTrue);
      expect(result.code, 'CODE');
    });

    test('the https App Link form parses identically to the wakeorpay '
        'form', () {
      // Both are the same answer — the verified https link Android routes
      // straight to the app, and the wakeorpay:// bounce the Worker's landing
      // page performs when it was not verified.
      final result = parseDiscordCallback(
        '$httpsBase?code=CODE&state=$state',
        expectedState: state,
      );
      expect(result.ok, isTrue);
      expect(result.code, 'CODE');
      expect(
        result,
        parseDiscordCallback(
          'wakeorpay://discord/callback?code=CODE&state=$state',
          expectedState: state,
        ),
      );
    });

    test('a fragment is no longer read', () {
      // This used to be the implicit grant's #access_token=…. The grant is
      // gone and so is any reason to look at the fragment — a server (the
      // Worker) never even receives one, so honouring it here would be a
      // check that cannot fire on the https redirect but silently would on
      // the wakeorpay:// bounce.
      final result = parseDiscordCallback(
        'wakeorpay://discord/callback?state=$state'
        '#access_token=TOK&state=$state',
        expectedState: state,
      );
      expect(result.error, DiscordCallbackError.malformed);
    });

    test('a wrong state is refused even when a code came with it', () {
      final result = parseDiscordCallback(
        'wakeorpay://discord/callback?code=CODE&state=somebody-elses',
        expectedState: state,
      );
      expect(result.ok, isFalse);
      expect(result.error, DiscordCallbackError.stateMismatch);
    });

    test('a missing state is a mismatch, not a pass', () {
      final result = parseDiscordCallback(
        'wakeorpay://discord/callback?code=CODE',
        expectedState: state,
      );
      expect(result.error, DiscordCallbackError.stateMismatch);
    });

    test('the user pressing キャンセル comes back as denied', () {
      final result = parseDiscordCallback(
        'wakeorpay://discord/callback'
        '?error=access_denied&error_description=The+user+denied&state=$state',
        expectedState: state,
      );
      expect(result.error, DiscordCallbackError.denied);
    });

    test('a callback with the right state but nothing in it is malformed', () {
      final result = parseDiscordCallback(
        'wakeorpay://discord/callback?state=$state',
        expectedState: state,
      );
      expect(result.error, DiscordCallbackError.malformed);
    });

    test('an empty code is not a code', () {
      final result = parseDiscordCallback(
        'wakeorpay://discord/callback?code=&state=$state',
        expectedState: state,
      );
      expect(result.error, DiscordCallbackError.malformed);
    });

    test('a percent-encoded code comes back decoded', () {
      final result = parseDiscordCallback(
        'wakeorpay://discord/callback?code=a%2Bb&state=$state',
        expectedState: state,
      );
      expect(result.code, 'a+b');
    });

    test('nonsense is malformed rather than a crash', () {
      expect(
        parseDiscordCallback('::::', expectedState: state).ok,
        isFalse,
      );
      expect(parseDiscordCallback('', expectedState: state).ok, isFalse);
    });
  });

  group('isDiscordCallbackUri', () {
    test('accepts the wakeorpay bounce', () {
      expect(
        isDiscordCallbackUri(Uri.parse('wakeorpay://discord/callback?code=C')),
        isTrue,
      );
    });

    test('accepts the https App Link form', () {
      expect(
        isDiscordCallbackUri(
          Uri.parse(
            'https://wake-or-pay-discord.wakeorpay.workers.dev'
            '/discord/callback?code=C',
          ),
        ),
        isTrue,
      );
    });

    test('accepts the second App Link path the landing page navigates to', () {
      // 段階H. Chromium will not hand the app a verified App Link it reached
      // as the end of a redirect chain — which is exactly how Discord
      // delivers /discord/callback. The landing page therefore starts a fresh
      // top-level navigation to this path, and it has to be routed the same.
      expect(
        isDiscordCallbackUri(
          Uri.parse(
            'https://wake-or-pay-discord.wakeorpay.workers.dev'
            '/discord/callback/return?code=C&state=S',
          ),
        ),
        isTrue,
      );
    });

    test('rejects an unrelated https host or path', () {
      // Only the exact host and path count: MainActivity's autoVerify filter
      // has no others, and a stray https intent that happened to reach the
      // app is not an answer to anything this app asked for.
      expect(
        isDiscordCallbackUri(Uri.parse('https://discord.com/discord/callback')),
        isFalse,
      );
      expect(
        isDiscordCallbackUri(
          Uri.parse(
            'https://wake-or-pay-discord.wakeorpay.workers.dev/other/path',
          ),
        ),
        isFalse,
      );
    });
  });

  group('parseDiscordIdentity', () {
    test('takes the four fields it shows', () {
      final identity = parseDiscordIdentity(
        '{"id":"123456789012345678","username":"hanako",'
        '"global_name":"花子","avatar":"abcdef","discriminator":"0"}',
      );
      expect(identity!.id, '123456789012345678');
      expect(identity.username, 'hanako');
      expect(identity.globalName, '花子');
      expect(identity.avatar, 'abcdef');
      // global_name wins: it is what Discord shows the user everywhere else.
      expect(identity.displayName, '花子');
    });

    test('falls back to username when there is no global_name', () {
      final identity = parseDiscordIdentity(
        '{"id":"1","username":"hanako","global_name":null}',
      );
      expect(identity!.displayName, 'hanako');
    });

    test('a body with no id is not a user', () {
      expect(parseDiscordIdentity('{"message":"401: Unauthorized"}'), isNull);
      expect(parseDiscordIdentity('{"id":""}'), isNull);
    });

    test('HTML from a captive portal is null, not a throw', () {
      expect(parseDiscordIdentity('<html>hi</html>'), isNull);
      expect(parseDiscordIdentity('[]'), isNull);
      expect(parseDiscordIdentity(''), isNull);
    });
  });
}
