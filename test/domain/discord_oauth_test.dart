import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/discord_oauth.dart';

void main() {
  group('buildDiscordAuthorizeUrl', () {
    test('the implicit grant asks for a token and identify only', () {
      final url = buildDiscordAuthorizeUrl(
        responseType: 'token',
        scopes: kDiscordIdentifyScopes,
        state: 'abc123',
        prompt: 'consent',
      );
      final uri = Uri.parse(url);

      expect(uri.scheme, 'https');
      expect(uri.host, 'discord.com');
      expect(uri.path, '/oauth2/authorize');
      expect(uri.queryParameters['client_id'], kDiscordClientId);
      expect(uri.queryParameters['response_type'], 'token');
      expect(uri.queryParameters['scope'], 'identify');
      expect(uri.queryParameters['redirect_uri'], kDiscordRedirectUri);
      expect(uri.queryParameters['state'], 'abc123');
      expect(uri.queryParameters['prompt'], 'consent');
    });

    test('the redirect URI is percent-encoded in the raw string', () {
      final url = buildDiscordAuthorizeUrl(
        responseType: 'token',
        scopes: kDiscordIdentifyScopes,
        state: 's',
      );
      // A raw `wakeorpay://…` in the query is the single most common reason
      // Discord refuses the authorize request outright.
      expect(url, contains('redirect_uri=wakeorpay%3A%2F%2Fdiscord%2Fcallback'));
      expect(url, isNot(contains('redirect_uri=wakeorpay://')));
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
      expect(
        Uri.parse(url).queryParameters['scope'],
        'webhook.incoming identify',
      );
      expect(url, contains('scope=webhook.incoming%20identify'));
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

    test('reads the token out of the fragment', () {
      final result = parseDiscordCallback(
        'wakeorpay://discord/callback'
        '#access_token=TOK&token_type=Bearer&expires_in=604800'
        '&scope=identify&state=$state',
        expectedState: state,
      );
      expect(result.ok, isTrue);
      expect(result.accessToken, 'TOK');
      expect(result.code, isNull);
    });

    test('reads the code out of the query', () {
      final result = parseDiscordCallback(
        'wakeorpay://discord/callback?code=CODE&state=$state',
        expectedState: state,
      );
      expect(result.ok, isTrue);
      expect(result.code, 'CODE');
      expect(result.accessToken, isNull);
    });

    test('a wrong state is refused even when a token came with it', () {
      final result = parseDiscordCallback(
        'wakeorpay://discord/callback#access_token=TOK&state=somebody-elses',
        expectedState: state,
      );
      expect(result.ok, isFalse);
      expect(result.error, DiscordCallbackError.stateMismatch);
      expect(result.accessToken, isNull);
    });

    test('a missing state is a mismatch, not a pass', () {
      final result = parseDiscordCallback(
        'wakeorpay://discord/callback#access_token=TOK',
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

    test('an error in the fragment is read too', () {
      final result = parseDiscordCallback(
        'wakeorpay://discord/callback#error=access_denied&state=$state',
        expectedState: state,
      );
      expect(result.error, DiscordCallbackError.denied);
    });

    test('a callback with the right state but nothing in it is malformed', () {
      final result = parseDiscordCallback(
        'wakeorpay://discord/callback#state=$state',
        expectedState: state,
      );
      expect(result.error, DiscordCallbackError.malformed);
    });

    test('an empty token is not a token', () {
      final result = parseDiscordCallback(
        'wakeorpay://discord/callback#access_token=&state=$state',
        expectedState: state,
      );
      expect(result.error, DiscordCallbackError.malformed);
    });

    test('a percent-encoded token comes back decoded', () {
      final result = parseDiscordCallback(
        'wakeorpay://discord/callback#access_token=a%2Bb&state=$state',
        expectedState: state,
      );
      expect(result.accessToken, 'a+b');
    });

    test('nonsense is malformed rather than a crash', () {
      expect(
        parseDiscordCallback('::::', expectedState: state).ok,
        isFalse,
      );
      expect(parseDiscordCallback('', expectedState: state).ok, isFalse);
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
