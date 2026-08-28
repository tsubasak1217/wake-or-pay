import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../domain/discord_oauth.dart';
import 'discord_exchange.dart';
import 'discord_sender.dart';

/// Opens an authorize URL and waits for the browser to come back on
/// `wakeorpay://`.
///
/// An interface for one reason: **no test in this app may open a browser.**
/// Everything above this line — the state check, the `/users/@me` call, what
/// the profile ends up holding — is then exercised by handing in a fake that
/// answers with a callback URL string.
abstract class OAuthAuthorizer {
  /// The full callback URL, or null when the user backed out.
  ///
  /// Never throws: a cancelled login is the most ordinary outcome there is,
  /// and the caller has nothing to say about it.
  Future<String?> authorize({
    required String url,
    required String callbackUrlScheme,
  });
}

/// The real one, over `flutter_web_auth_2`.
///
/// Chosen over `url_launcher` + a deep link into MainActivity because the
/// custom-scheme return is the part that actually breaks: the plugin owns a
/// `CallbackActivity` that the browser hands the intent to, and it keeps the
/// **fragment** — which for the implicit grant is where the entire answer is.
/// A deep link into a `singleTop` MainActivity has to survive the activity
/// already being alive, the browser deciding to keep the tab, and Android 12's
/// intent rules, for no gain.
class WebAuthOAuthAuthorizer implements OAuthAuthorizer {
  const WebAuthOAuthAuthorizer();

  @override
  Future<String?> authorize({
    required String url,
    required String callbackUrlScheme,
  }) async {
    try {
      return await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: callbackUrlScheme,
      );
    } on Object {
      // The plugin throws for a cancel, for a missing browser, and for a
      // second flow started while one is open. None of those is worth a
      // different sentence than 「連携をやめました」.
      return null;
    }
  }
}

final oauthAuthorizerProvider = Provider<OAuthAuthorizer>(
  (ref) => const WebAuthOAuthAuthorizer(),
);

/// How long `/users/@me` is allowed to take. The user is watching a spinner
/// on a button they just pressed.
const discordIdentityTimeout = Duration(seconds: 10);

/// Why 「Discord で連携」 ended the way it did.
enum DiscordLinkStatus {
  ok,

  /// The user closed the browser or pressed キャンセル on Discord's page.
  cancelled,

  /// The `state` did not come back intact. Loud on purpose — this is the one
  /// failure that means something was wrong rather than merely unlucky.
  stateMismatch,

  /// Discord answered the authorize step with `error=…`.
  denied,

  /// A token came back but `/users/@me` did not answer with a user.
  identityFailed,
}

/// The outcome of a link attempt, as a value.
@immutable
class DiscordLinkResult {
  const DiscordLinkResult(this.status, [this.identity]);

  final DiscordLinkStatus status;
  final DiscordIdentity? identity;

  bool get ok => status == DiscordLinkStatus.ok && identity != null;

  /// What the SnackBar says. Japanese, and specific enough to act on: 「連携を
  /// やめました」 needs no action, 「確認に失敗しました」 means try again from the app
  /// rather than from a link somebody sent.
  String get label => switch (status) {
    DiscordLinkStatus.ok => '連携しました',
    DiscordLinkStatus.cancelled => '連携をやめました',
    DiscordLinkStatus.stateMismatch => '確認に失敗しました。アプリからもう一度お試しください',
    DiscordLinkStatus.denied => 'Discord で許可されませんでした',
    DiscordLinkStatus.identityFailed => 'ユーザー情報を取得できませんでした',
  };
}

/// 「Discord で連携」, end to end.
///
/// The implicit grant (`response_type=token`) is used here and **only** here,
/// because `identify` is all it asks for and no server is involved: the token
/// arrives in the fragment, is spent once on `/users/@me`, and is dropped on
/// the floor. It is **never persisted** — not in prefs, not in the secure
/// store, not in a field on this object. What the app keeps is the id and the
/// name, which are the two things the oversleep post needs, and neither of
/// them can be used to act as the user.
class DiscordOAuthService {
  DiscordOAuthService(this._authorizer, this._client);

  final OAuthAuthorizer _authorizer;
  final http.Client _client;

  /// The state of the flow currently in the air, exposed for the emulator
  /// check only — it is what an `adb am start` has to echo back.
  @visibleForTesting
  String? lastState;

  Future<DiscordLinkResult> link() async {
    final state = randomOAuthState();
    lastState = state;
    final callback = await _authorizer.authorize(
      url: buildDiscordAuthorizeUrl(
        responseType: 'token',
        scopes: kDiscordIdentifyScopes,
        state: state,
        // Always show the consent screen: without it a user who already
        // authorised once is bounced straight back, which looks like nothing
        // happened when they pressed the button to *change* accounts.
        prompt: 'consent',
      ),
      callbackUrlScheme: kDiscordCallbackScheme,
    );
    if (callback == null) {
      return const DiscordLinkResult(DiscordLinkStatus.cancelled);
    }

    final parsed = parseDiscordCallback(callback, expectedState: state);
    if (!parsed.ok) {
      return DiscordLinkResult(switch (parsed.error) {
        DiscordCallbackError.stateMismatch => DiscordLinkStatus.stateMismatch,
        DiscordCallbackError.denied => DiscordLinkStatus.denied,
        _ => DiscordLinkStatus.identityFailed,
      });
    }
    final token = parsed.accessToken;
    if (token == null || token.isEmpty) {
      return const DiscordLinkResult(DiscordLinkStatus.identityFailed);
    }

    final identity = await fetchIdentity(token);
    return identity == null
        ? const DiscordLinkResult(DiscordLinkStatus.identityFailed)
        : DiscordLinkResult(DiscordLinkStatus.ok, identity);
  }

  /// `GET /users/@me` with the bearer token. Null for every failure.
  @visibleForTesting
  Future<DiscordIdentity?> fetchIdentity(String accessToken) async {
    try {
      final response = await _client
          .get(
            Uri.https('discord.com', '/api/users/@me'),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(discordIdentityTimeout);
      if (response.statusCode != 200) return null;
      // bodyBytes, not body: `http` falls back to latin-1 when Discord omits
      // the charset, and a global_name in kana would come back as mojibake.
      return parseDiscordIdentity(utf8.decode(response.bodyBytes));
    } on Object {
      return null;
    }
  }
}

final discordOAuthServiceProvider = Provider(
  (ref) => DiscordOAuthService(
    ref.watch(oauthAuthorizerProvider),
    ref.watch(httpClientProvider),
  ),
);

/// Why 「チャンネルを連携」 ended the way it did.
enum DiscordChannelLinkStatus {
  ok,

  /// No 連携サーバー is configured. Not a failure so much as a step not yet
  /// taken, and it gets its own sentence because the fix is in a README and
  /// not in this app.
  noEndpoint,

  cancelled,
  stateMismatch,
  denied,

  /// The Worker did not hand back a webhook — it is down, the code was
  /// already spent, or the secret was never put on it.
  exchangeFailed,
}

/// The outcome of 「チャンネルを連携」, as a value.
@immutable
class DiscordChannelLinkResult {
  const DiscordChannelLinkResult(this.status, [this.grant]);

  final DiscordChannelLinkStatus status;
  final DiscordWebhookGrant? grant;

  bool get ok => status == DiscordChannelLinkStatus.ok && grant != null;

  String get label => switch (status) {
    DiscordChannelLinkStatus.ok => '共有先を追加しました',
    DiscordChannelLinkStatus.noEndpoint => '連携サーバーURL が未設定です',
    DiscordChannelLinkStatus.cancelled => '連携をやめました',
    DiscordChannelLinkStatus.stateMismatch =>
      '確認に失敗しました。アプリからもう一度お試しください',
    DiscordChannelLinkStatus.denied => 'Discord で許可されませんでした',
    DiscordChannelLinkStatus.exchangeFailed => 'チャンネルを連携できませんでした',
  };
}

/// 「チャンネルを連携（Discord で選ぶ）」, end to end.
///
/// The **code** grant, not the implicit one, because `webhook.incoming` only
/// hands the webhook over with the token — and that exchange needs the client
/// secret, which is why [endpoint] (the Worker) has to exist at all. The app
/// never sees a token: what comes back over [endpoint] is a webhook URL and a
/// couple of names.
class DiscordChannelLinker {
  const DiscordChannelLinker(this._authorizer, this._exchange);

  final OAuthAuthorizer _authorizer;
  final DiscordExchangeClient _exchange;

  Future<DiscordChannelLinkResult> link({required String endpoint}) async {
    if (!isDiscordExchangeEndpoint(endpoint)) {
      return const DiscordChannelLinkResult(
        DiscordChannelLinkStatus.noEndpoint,
      );
    }

    final state = randomOAuthState();
    final callback = await _authorizer.authorize(
      url: buildDiscordAuthorizeUrl(
        responseType: 'code',
        // `webhook.incoming` is what makes Discord show the channel picker;
        // `identify` is only so the Worker can name the server it landed in.
        scopes: kDiscordWebhookScopes,
        state: state,
        // No prompt=consent here: picking a channel *is* the consent screen,
        // and Discord shows it every time regardless.
      ),
      callbackUrlScheme: kDiscordCallbackScheme,
    );
    if (callback == null) {
      return const DiscordChannelLinkResult(
        DiscordChannelLinkStatus.cancelled,
      );
    }

    final parsed = parseDiscordCallback(callback, expectedState: state);
    if (!parsed.ok) {
      return DiscordChannelLinkResult(switch (parsed.error) {
        DiscordCallbackError.stateMismatch =>
          DiscordChannelLinkStatus.stateMismatch,
        DiscordCallbackError.denied => DiscordChannelLinkStatus.denied,
        _ => DiscordChannelLinkStatus.exchangeFailed,
      });
    }
    final code = parsed.code;
    if (code == null || code.isEmpty) {
      return const DiscordChannelLinkResult(
        DiscordChannelLinkStatus.exchangeFailed,
      );
    }

    final grant = await _exchange.exchange(
      endpoint: endpoint,
      code: code,
      // The same redirect that went out with the authorize request. Discord
      // checks the two match, and a mismatch here is a 400 on a code that is
      // then spent and unusable.
      redirectUri: kDiscordRedirectUri,
    );
    return grant == null
        ? const DiscordChannelLinkResult(
            DiscordChannelLinkStatus.exchangeFailed,
          )
        : DiscordChannelLinkResult(DiscordChannelLinkStatus.ok, grant);
  }
}

final discordChannelLinkerProvider = Provider(
  (ref) => DiscordChannelLinker(
    ref.watch(oauthAuthorizerProvider),
    ref.watch(discordExchangeClientProvider),
  ),
);
