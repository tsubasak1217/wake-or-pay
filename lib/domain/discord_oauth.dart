import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// The Discord application this app authorises against.
///
/// Public by design — a client ID is not a secret, it is the name Discord
/// knows this app by, and it has to be in the authorize URL the browser opens.
/// The **client secret** is the one that must never be here; it lives only in
/// the Cloudflare Worker (`worker/`), because the code-for-token exchange is
/// the only call that needs it.
const kDiscordClientId = '1542696296337506415';

/// Where Discord sends the browser back to. Registered in the Developer
/// Portal, matched **exactly** by Discord — one character of difference and
/// the authorize page refuses before the user ever sees a consent screen.
///
/// **https, not `wakeorpay://`.** The custom scheme was what this used to be,
/// and Discord refuses it for this application outright: the authorize page
/// ends at `discord.com/oauth2/error?error=invalid_request` saying
/// 「Redirect URI 'wakeorpay://discord/callback' is not supported by client」
/// before any consent screen — so the app waited forever for a callback that
/// was never going to be sent. Discord accepts an https redirect, so the
/// Worker owns the landing page and hands the parameters back to the app: by
/// **App Links** when Android has verified the Worker's `assetlinks.json`
/// (the app opens directly, no browser is ever seen), and by a
/// `wakeorpay://` bounce from that page when it has not.
const kDiscordRedirectUri =
    'https://wake-or-pay-discord.wakeorpay.workers.dev/discord/callback';

/// The custom scheme `MainActivity` claims, for the Worker page's bounce.
///
/// Still here, and still claimed by exactly one component in the app: it is
/// the fallback the landing page uses when the https link was not verified.
const kDiscordCallbackScheme = 'wakeorpay';

/// The host half of [kDiscordRedirectUri]. `MainActivity` claims it with
/// `autoVerify="true"`, which is what makes the https redirect skip the
/// browser entirely.
const kDiscordCallbackHost = 'wake-or-pay-discord.wakeorpay.workers.dev';

/// The path both forms of the callback share.
const kDiscordCallbackPath = '/discord/callback';

/// Whether [uri] is a Discord callback this app should route — either form.
///
/// The https one only counts on the exact host and path: `MainActivity` has an
/// `autoVerify` filter for them and nothing else, and a stray https intent
/// that happened to reach the app is not an answer to anything.
bool isDiscordCallbackUri(Uri uri) {
  if (uri.scheme == kDiscordCallbackScheme) return true;
  return uri.scheme == 'https' &&
      uri.host == kDiscordCallbackHost &&
      uri.path == kDiscordCallbackPath;
}

/// `identify` is the whole of what 「Discord で連携」 asks for: it is exactly
/// `GET /users/@me` without the email, which is the user's id, username,
/// global_name and avatar hash — the four things the profile row shows.
const kDiscordIdentifyScopes = ['identify'];

/// 「チャンネルを連携」. `webhook.incoming` is what makes Discord show the
/// channel picker and hand a ready-made webhook back with the token; `identify`
/// rides along only so the Worker can name the server the webhook landed in.
const kDiscordWebhookScopes = ['webhook.incoming', 'identify'];

/// Builds the URL the browser opens. Pure, so the exact string is testable
/// without a browser, a plugin, or a network.
///
/// The query is assembled by hand with [Uri.encodeComponent] rather than by
/// `Uri.https`'s map, for one reason: that map encodes a **space as `+`**, and
/// the scope parameter is space-separated. `scope=webhook.incoming+identify`
/// is form encoding leaking into a URL query, which Discord's own examples
/// never use — and a scope Discord fails to split is a consent screen that
/// asks for the wrong thing, or refuses. [Uri.encodeComponent] gives `%20`.
///
/// The redirect URI is encoded by the same call. A raw `wakeorpay://…` in the
/// query is the single most common reason Discord answers
/// 「無効な OAuth2 リダイレクト URI」 before showing anything.
String buildDiscordAuthorizeUrl({
  required String responseType,
  required List<String> scopes,
  required String state,
  String clientId = kDiscordClientId,
  String redirectUri = kDiscordRedirectUri,
  String? prompt,
}) {
  final query = {
    'client_id': clientId,
    'response_type': responseType,
    'scope': scopes.join(' '),
    'redirect_uri': redirectUri,
    'state': state,
    'prompt': ?prompt,
  }.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return 'https://discord.com/oauth2/authorize?$query';
}

/// A fresh, unguessable `state`.
///
/// The point is not secrecy but binding: the value goes out with the authorize
/// URL and has to come back unchanged, so a callback somebody else's page
/// arranged cannot be mistaken for the one this app asked for.
String randomOAuthState([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// Why a callback did not produce anything usable.
enum DiscordCallbackError {
  /// The `state` that came back is not the one that went out. Treated as a
  /// hard failure and never as "try again anyway": that is the whole reason
  /// the parameter exists.
  stateMismatch,

  /// Discord said `error=…` — the user pressed キャンセル, most often.
  denied,

  /// A callback with neither a code nor an error in it.
  malformed,
}

/// What came back on the callback — either form of it.
///
/// One shape now, because there is one grant: the **authorization code**.
/// Every failure fills [error] instead of throwing — this runs from a button
/// press and the screen has to say what happened.
@immutable
class DiscordCallbackResult {
  const DiscordCallbackResult._({this.code, this.error});

  const DiscordCallbackResult.authorizationCode(String code)
    : this._(code: code);
  const DiscordCallbackResult.failed(DiscordCallbackError error)
    : this._(error: error);

  final String? code;
  final DiscordCallbackError? error;

  bool get ok => error == null && code != null;

  @override
  bool operator ==(Object other) =>
      other is DiscordCallbackResult &&
      other.code == code &&
      other.error == error;

  @override
  int get hashCode => Object.hash(code, error);

  @override
  String toString() =>
      ok ? 'DiscordCallbackResult(code)' : 'DiscordCallbackResult($error)';
}

/// Reads a callback URL. Pure.
///
/// Handles both forms the app can be handed, because they carry the same
/// query: the verified https link
/// `https://wake-or-pay-discord…/discord/callback?code=…&state=…` that Android
/// routes straight to the app, and the `wakeorpay://discord/callback?…` bounce
/// the Worker's landing page performs when it did not. Discord's refusals
/// arrive the same way, as `?error=…&error_description=…`.
///
/// The **fragment is no longer read**. It only ever held the implicit grant's
/// `#access_token=…`, and that grant is gone: `identify` now goes through the
/// same code exchange as `webhook.incoming`, so no token ever reaches the app.
///
/// The state is checked first and checked always — before the code is even
/// looked at — so a callback that was not this app's cannot be half-processed.
DiscordCallbackResult parseDiscordCallback(
  String url, {
  required String expectedState,
}) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return const DiscordCallbackResult.failed(DiscordCallbackError.malformed);
  }

  final params = uri.queryParameters;

  if (params['state'] != expectedState) {
    return const DiscordCallbackResult.failed(
      DiscordCallbackError.stateMismatch,
    );
  }
  if ((params['error'] ?? '').isNotEmpty) {
    return const DiscordCallbackResult.failed(DiscordCallbackError.denied);
  }

  final code = params['code'] ?? '';
  if (code.isNotEmpty) return DiscordCallbackResult.authorizationCode(code);
  return const DiscordCallbackResult.failed(DiscordCallbackError.malformed);
}

/// The part of `GET /users/@me` this app keeps.
@immutable
class DiscordIdentity {
  const DiscordIdentity({
    required this.id,
    required this.username,
    this.globalName = '',
    this.avatar = '',
  });

  /// The snowflake. This is what goes in `<@…>` when the oversleep post
  /// mentions the user, and it is the reason the whole flow exists: typing it
  /// by hand needs Discord's developer mode turned on first.
  final String id;

  final String username;

  /// Discord's newer display name. Shown when set, because it is what the
  /// user sees themselves called everywhere else.
  final String globalName;

  final String avatar;

  /// What 「連携済み：…」 shows.
  String get displayName => globalName.isEmpty ? username : globalName;

  @override
  bool operator ==(Object other) =>
      other is DiscordIdentity &&
      other.id == id &&
      other.username == username &&
      other.globalName == globalName &&
      other.avatar == avatar;

  @override
  int get hashCode => Object.hash(id, username, globalName, avatar);

  @override
  String toString() => 'DiscordIdentity($id, @$username)';
}

/// Reads a `/users/@me` body. Pure, and null for anything that is not one.
///
/// Null rather than a throw for every shape that is not a user: a captive
/// portal answering HTML, a rate-limit body, an object with no `id`. The
/// caller has to say 「取得できませんでした」 in all of those cases anyway.
DiscordIdentity? parseDiscordIdentity(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final id = (decoded['id'] as String?)?.trim() ?? '';
  if (id.isEmpty) return null;
  return DiscordIdentity(
    id: id,
    username: (decoded['username'] as String?)?.trim() ?? '',
    globalName: (decoded['global_name'] as String?)?.trim() ?? '',
    avatar: (decoded['avatar'] as String?)?.trim() ?? '',
  );
}
