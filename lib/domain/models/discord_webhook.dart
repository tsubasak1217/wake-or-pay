import 'package:flutter/foundation.dart';

/// One Discord 共有先, per spec 11.6.
///
/// App-wide, not per alarm: the same server is worth registering once, and
/// each alarm then ticks the ones it posts to ([OversleepShare.webhookIds]).
///
/// [displayName] **defaults to the server name** the 連携 landed in — see
/// [webhookDefaultName], which the 「チャンネルを連携」 path fills this from. The
/// channel name would make it 「みんなのサーバー/#一般」, but Discord does not expose
/// it through user OAuth (that needs a bot in the guild or `guilds.members.read`
/// — see `worker/README.md`), so the server name alone is where it lands, and
/// the webhook's own name (「Wake or Pay」) is only the fallback when even the
/// server name is missing. The user can **rename** any row afterwards — two
/// channels in the same server both default to the same server name, and a
/// rename is how they are told apart.
@immutable
class DiscordWebhook {
  const DiscordWebhook({
    required this.id,
    required this.url,
    required this.displayName,
    required this.createdAt,
  });

  final String id;

  /// The full webhook URL, including its token. Secret in the sense that
  /// anyone holding it can post; it never leaves the device except to Discord.
  final String url;

  final String displayName;
  final DateTime createdAt;

  /// A webhook with no URL could never post and a nameless one could never be
  /// picked out of the list.
  bool get isUsable => url.trim().isNotEmpty && displayName.trim().isNotEmpty;

  DiscordWebhook copyWith({
    String? id,
    String? url,
    String? displayName,
    DateTime? createdAt,
  }) => DiscordWebhook(
    id: id ?? this.id,
    url: url ?? this.url,
    displayName: displayName ?? this.displayName,
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  bool operator ==(Object other) =>
      other is DiscordWebhook &&
      other.id == id &&
      other.url == url &&
      other.displayName == displayName &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, url, displayName, createdAt);

  @override
  String toString() => 'DiscordWebhook($displayName)';
}

/// The name a freshly-linked 共有先 is registered under. Pure.
///
/// Priority, highest first:
///
/// 1. **`{guild}/#{channel}`** when both are known. This is what the user
///    recognises, and the only branch that shows a channel — reachable only if
///    [channelName] ever becomes non-empty, which today it never does (Discord
///    withholds it from user OAuth).
/// 2. **The server name** alone — where it lands in practice.
/// 3. **The webhook's own name** (「Wake or Pay」, the application name) — worse,
///    but a real name, used only when no server name came back.
/// 4. **「Discord 連携先」** — an unnamed row cannot be picked out of a list, so
///    it never gets an empty label.
///
/// Deliberately not 「Wake or Pay」 whenever a server name is available: that
/// fixed application name is the same on every row and tells the user nothing.
String webhookDefaultName(
  String guildName,
  String channelName,
  String webhookName,
) {
  final guild = guildName.trim();
  final channel = channelName.trim();
  final webhook = webhookName.trim();
  if (guild.isNotEmpty && channel.isNotEmpty) return '$guild/#$channel';
  if (guild.isNotEmpty) return guild;
  if (webhook.isNotEmpty) return webhook;
  return 'Discord 連携先';
}

/// Every host Discord serves webhooks from.
///
/// `discordapp.com` is the original domain and still resolves; `canary.` and
/// `ptb.` are the two public test builds, and a user who copied a URL out of
/// one of those has a perfectly working webhook.
const _discordWebhookHosts = {
  'discord.com',
  'www.discord.com',
  'canary.discord.com',
  'ptb.discord.com',
  'discordapp.com',
  'www.discordapp.com',
  'canary.discordapp.com',
  'ptb.discordapp.com',
};

/// A pasted URL with the whitespace and the query string taken off. Pure.
///
/// Discord's own copy button hands back a bare URL, but a URL pasted out of a
/// browser can arrive with `?thread_id=…` or a trailing slash on it, and both
/// of those are noise the sender would have to strip anyway.
String normalizeDiscordWebhookUrl(String raw) {
  final trimmed = raw.trim();
  final queryAt = trimmed.indexOf('?');
  final withoutQuery = queryAt < 0 ? trimmed : trimmed.substring(0, queryAt);
  final hashAt = withoutQuery.indexOf('#');
  final bare = hashAt < 0 ? withoutQuery : withoutQuery.substring(0, hashAt);
  return bare.endsWith('/') ? bare.substring(0, bare.length - 1) : bare;
}

/// Whether [raw] is a Discord webhook URL. Pure.
///
/// Permissive about the token, because Discord has changed its shape before
/// and a rejected working URL is worse than an accepted broken one: the token
/// only has to be a non-empty path segment. Strict about everything the
/// *sender* depends on — https, a Discord host, `/api/webhooks/`, and a
/// numeric webhook id — because those are what make it a webhook at all.
bool isDiscordWebhookUrl(String raw) {
  final uri = Uri.tryParse(normalizeDiscordWebhookUrl(raw));
  if (uri == null || uri.scheme != 'https') return false;
  if (!_discordWebhookHosts.contains(uri.host.toLowerCase())) return false;

  final segments = [
    for (final segment in uri.pathSegments)
      if (segment.isNotEmpty) segment,
  ];
  // `api/webhooks/<id>/<token>`, optionally with a version in between:
  // Discord's own copy button emits the unversioned form, but `/api/v10/…`
  // works just as well and users do paste it.
  if (segments.length < 4) return false;
  if (segments.first != 'api') return false;
  final rest = segments[1].startsWith('v') ? segments.sublist(2) : segments
      .sublist(1);
  if (rest.length != 3) return false;
  if (rest[0] != 'webhooks') return false;
  if (rest[1].isEmpty || !RegExp(r'^\d+$').hasMatch(rest[1])) return false;
  return rest[2].isNotEmpty;
}
