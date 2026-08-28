import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../domain/discord_oauth.dart';
import 'discord_sender.dart';

/// The deployed 連携サーバー — **the single place this app learns about it.**
///
/// A compile-time constant and nothing else. There used to be a
/// 「連携サーバーURL」 row the user could paste into, and it was the wrong shape
/// for the job twice over: it asked a user to know a deployment detail, and it
/// made a URL that decides where an authorization code is sent into something
/// anybody could change from inside the app. The person who deploys the Worker
/// is the person who builds the APK, so this belongs in the build.
///
/// This value is **the Worker belonging to whoever built this APK**, and it is
/// the one thing in this file a fork has to change. Pointing a build at
/// somebody else's Worker spends *their* client secret on *your* users'
/// authorizations — see `worker/README.md`, which is five commands long.
///
/// Leaving it empty is a legitimate build: 「Discord で連携」 needs no server at
/// all and keeps working, and only 「チャンネルを連携」 refuses, saying so by name
/// rather than failing quietly.
///
/// **The base URL only.** `/discord/exchange` is appended by
/// [buildDiscordExchangeUrl] — which is forgiving about a trailing slash and
/// about somebody pasting the full path, because both are what actually gets
/// copied out of a terminal.
const kDiscordExchangeEndpoint =
    'https://wake-or-pay-discord.wakeorpay.workers.dev';

/// The path the Worker serves. Kept beside the URL builder so the app and
/// `worker/src/index.ts` cannot drift apart silently.
const kDiscordExchangePath = '/discord/exchange';

/// The full POST URL for a base. Pure.
///
/// Forgiving about what gets pasted: a Worker URL copied out of
/// `wrangler deploy` has no trailing slash, one copied out of a browser's
/// address bar does, and somebody who read the README twice pastes the whole
/// `/discord/exchange` URL. All three have to work — this row is the last
/// thing between the user and a button that says 「まだ使えません」.
String buildDiscordExchangeUrl(String base) {
  var trimmed = base.trim();
  while (trimmed.endsWith('/')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  if (trimmed.endsWith(kDiscordExchangePath)) return trimmed;
  return '$trimmed$kDiscordExchangePath';
}

/// Whether [base] could be a Worker at all. Pure.
///
/// https only: the exchange carries an authorization code, and a code sent
/// over http is a code anybody on the same wifi can spend before the app does.
bool isDiscordExchangeEndpoint(String base) {
  final uri = Uri.tryParse(buildDiscordExchangeUrl(base));
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}

/// What the Worker hands back: a webhook, and the names to call it by.
@immutable
class DiscordWebhookGrant {
  const DiscordWebhookGrant({
    required this.id,
    required this.url,
    this.channelId = '',
    this.guildId = '',
    this.webhookName = '',
    this.guildName = '',
    this.channelName = '',
  });

  final String id;
  final String url;
  final String channelId;
  final String guildId;

  /// The webhook's own name, as Discord created it — usually the application
  /// name, which is 「Wake or Pay」.
  final String webhookName;

  final String guildName;
  final String channelName;

  /// What the 共有先 list shows.
  ///
  /// 「みんなのサーバー/#一般」 is what the spec asks for and what the user
  /// recognises, but the channel name needs a scope this app does not ask for
  /// (see `worker/README.md`), so in practice this lands on the server name
  /// alone. The webhook's own name is the last fallback, and the plain
  /// 「Discord 共有先」 after that — an unnamed row cannot be picked out of a
  /// list.
  String get displayName {
    if (guildName.isNotEmpty && channelName.isNotEmpty) {
      return '$guildName/#$channelName';
    }
    if (guildName.isNotEmpty) return guildName;
    if (channelName.isNotEmpty) return '#$channelName';
    if (webhookName.isNotEmpty) return webhookName;
    return 'Discord 共有先';
  }

  @override
  bool operator ==(Object other) =>
      other is DiscordWebhookGrant &&
      other.id == id &&
      other.url == url &&
      other.channelId == channelId &&
      other.guildId == guildId &&
      other.webhookName == webhookName &&
      other.guildName == guildName &&
      other.channelName == channelName;

  @override
  int get hashCode => Object.hash(
    id,
    url,
    channelId,
    guildId,
    webhookName,
    guildName,
    channelName,
  );

  @override
  String toString() => 'DiscordWebhookGrant($displayName)';
}

/// Reads the Worker's answer. Pure, and null for anything that is not one.
DiscordWebhookGrant? parseDiscordExchangeResponse(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final webhook = decoded['webhook'];
  if (webhook is! Map) return null;

  String field(Map<Object?, Object?> map, String key) =>
      (map[key] as String?)?.trim() ?? '';

  final url = field(webhook, 'url');
  final id = field(webhook, 'id');
  // A grant with no URL could never post, which is the only thing a 共有先 is
  // for.
  if (url.isEmpty || id.isEmpty) return null;

  return DiscordWebhookGrant(
    id: id,
    url: url,
    channelId: field(webhook, 'channel_id'),
    guildId: field(webhook, 'guild_id'),
    webhookName: field(webhook, 'name'),
    guildName: field(decoded, 'guild_name'),
    channelName: field(decoded, 'channel_name'),
  );
}

/// Reads the Worker's `identify` answer — `{"user":{…}}`. Pure, and null for
/// anything that is not one.
///
/// A separate shape from `/users/@me` on purpose: the app no longer calls
/// Discord directly for this. `identify` moved onto the authorization-code
/// grant along with `webhook.incoming` (the implicit grant is gone), so the
/// access token is spent inside the Worker and only these four public fields
/// come back out.
DiscordIdentity? parseDiscordExchangeIdentity(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final user = decoded['user'];
  if (user is! Map) return null;
  final id = (user['id'] as String?)?.trim() ?? '';
  if (id.isEmpty) return null;
  return DiscordIdentity(
    id: id,
    username: (user['username'] as String?)?.trim() ?? '',
    globalName: (user['global_name'] as String?)?.trim() ?? '',
    avatar: (user['avatar'] as String?)?.trim() ?? '',
  );
}

/// How long the Worker is given. Longer than a plain lookup — it makes two
/// calls to Discord of its own — and still bounded, because a user is staring
/// at a spinner.
const discordExchangeTimeout = Duration(seconds: 20);

/// Which answer the Worker is being asked for. Sent as `mode`, because the
/// Worker cannot tell the two authorizations apart from the code alone and
/// guessing would turn a failed webhook exchange into a silent success.
enum DiscordExchangeMode {
  identify,
  webhook;

  String get wireValue => name;
}

/// The one call to the 連携サーバー.
class DiscordExchangeClient {
  const DiscordExchangeClient(this._client);

  final http.Client _client;

  /// The raw POST. Null body for every failure, so both callers below collapse
  /// a Worker that is down, a 400 from a code that was already spent and an
  /// answer that is not JSON into the same 「できませんでした」.
  Future<String?> _post({
    required String endpoint,
    required String code,
    required String redirectUri,
    required DiscordExchangeMode mode,
  }) async {
    if (!isDiscordExchangeEndpoint(endpoint)) return null;
    try {
      final response = await _client
          .post(
            Uri.parse(buildDiscordExchangeUrl(endpoint)),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'code': code,
              'redirect_uri': redirectUri,
              'mode': mode.wireValue,
            }),
          )
          .timeout(discordExchangeTimeout);
      if (response.statusCode != 200) return null;
      // bodyBytes, not body: `http` falls back to latin-1 when the charset is
      // absent, and a global_name in kana would come back as mojibake.
      return utf8.decode(response.bodyBytes);
    } on Object {
      return null;
    }
  }

  /// 「チャンネルを連携」. Null for every failure.
  Future<DiscordWebhookGrant?> exchange({
    required String endpoint,
    required String code,
    required String redirectUri,
  }) async {
    final body = await _post(
      endpoint: endpoint,
      code: code,
      redirectUri: redirectUri,
      mode: DiscordExchangeMode.webhook,
    );
    return body == null ? null : parseDiscordExchangeResponse(body);
  }

  /// 「Discord で連携」. Null for every failure.
  Future<DiscordIdentity?> exchangeIdentity({
    required String endpoint,
    required String code,
    required String redirectUri,
  }) async {
    final body = await _post(
      endpoint: endpoint,
      code: code,
      redirectUri: redirectUri,
      mode: DiscordExchangeMode.identify,
    );
    return body == null ? null : parseDiscordExchangeIdentity(body);
  }
}

final discordExchangeClientProvider = Provider(
  (ref) => DiscordExchangeClient(ref.watch(httpClientProvider)),
);
