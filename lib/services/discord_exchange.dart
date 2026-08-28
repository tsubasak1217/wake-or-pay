import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/providers.dart';
import 'discord_sender.dart';

/// The deployed 連携サーバー, baked in at build time.
///
/// **Empty by default, and that is on purpose.** Every install of this app
/// would otherwise point at one person's Cloudflare account, whose client
/// secret would be spent on strangers' authorizations. Whoever builds the app
/// puts their own Worker here, or the user pastes theirs into the
/// 「連携サーバーURL」 row — see [discordExchangeEndpointProvider].
///
/// The base URL only. `/discord/exchange` is appended by
/// [buildDiscordExchangeUrl].
const kDiscordExchangeEndpoint = '';

/// Where the runtime override lives. One key, one string.
const kDiscordExchangeEndpointPrefsKey = 'discord.exchangeEndpoint';

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

/// How long the Worker is given. Longer than a plain lookup — it makes two
/// calls to Discord of its own — and still bounded, because a user is staring
/// at a spinner.
const discordExchangeTimeout = Duration(seconds: 20);

/// The one call to the 連携サーバー.
class DiscordExchangeClient {
  const DiscordExchangeClient(this._client);

  final http.Client _client;

  /// Null for every failure: a Worker that is down, a 400 from a code that was
  /// already spent, an answer that is not JSON. The screen says
  /// 「チャンネルを連携できませんでした」 in all of them.
  Future<DiscordWebhookGrant?> exchange({
    required String endpoint,
    required String code,
    required String redirectUri,
  }) async {
    if (!isDiscordExchangeEndpoint(endpoint)) return null;
    try {
      final response = await _client
          .post(
            Uri.parse(buildDiscordExchangeUrl(endpoint)),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({'code': code, 'redirect_uri': redirectUri}),
          )
          .timeout(discordExchangeTimeout);
      if (response.statusCode != 200) return null;
      return parseDiscordExchangeResponse(utf8.decode(response.bodyBytes));
    } on Object {
      return null;
    }
  }
}

final discordExchangeClientProvider = Provider(
  (ref) => DiscordExchangeClient(ref.watch(httpClientProvider)),
);

/// The endpoint actually in force: what the user pasted, or the build-time
/// constant when they have pasted nothing.
final discordExchangeEndpointProvider =
    NotifierProvider<DiscordExchangeEndpointController, String>(
      DiscordExchangeEndpointController.new,
    );

class DiscordExchangeEndpointController extends Notifier<String> {
  @override
  String build() {
    final stored = ref
        .watch(sharedPreferencesProvider)
        .getString(kDiscordExchangeEndpointPrefsKey);
    return (stored == null || stored.trim().isEmpty)
        ? kDiscordExchangeEndpoint
        : stored.trim();
  }

  /// Blank clears the override, which puts [kDiscordExchangeEndpoint] back —
  /// so the row can always be emptied to get to the default, rather than
  /// needing a separate 「戻す」.
  Future<void> set(String endpoint) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final trimmed = endpoint.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(kDiscordExchangeEndpointPrefsKey);
      state = kDiscordExchangeEndpoint;
      return;
    }
    await prefs.setString(kDiscordExchangeEndpointPrefsKey, trimmed);
    state = trimmed;
  }
}
