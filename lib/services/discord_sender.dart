import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../domain/models.dart';

/// The one HTTP client the app talks to the network through.
///
/// A provider so every test can hand in a fake instead: nothing in this app is
/// allowed to reach the real internet from a test, and a webhook URL is
/// somebody's live Discord channel.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// How long a lookup is allowed to sit there.
///
/// Short on purpose: this fills in a text field the user can type into
/// themselves, so a slow network must never be the reason they cannot press
/// 保存.
const discordLookupTimeout = Duration(seconds: 5);

/// Everything the app does over the Discord webhook API.
///
/// One class so C3's actual sender lands next to the lookup that registers the
/// target, rather than in a second place that has to be found.
class DiscordSender {
  const DiscordSender(this._client);

  final http.Client _client;

  /// The webhook's own name, or null when it cannot be had.
  ///
  /// Used only to prefill 表示名 on the registration form. **Every** failure is
  /// silent and gives null — offline, a 404 from a revoked webhook, HTML from
  /// a captive portal, a body with no `name` in it. Registration is a local
  /// act and a lookup that did not work is not a reason to refuse it; the user
  /// types the display name by hand anyway, because Discord does not expose
  /// the server or channel name here at all.
  Future<String?> fetchWebhookName(String url) async {
    final normalized = normalizeDiscordWebhookUrl(url);
    if (!isDiscordWebhookUrl(normalized)) return null;
    try {
      final response = await _client
          .get(Uri.parse(normalized))
          .timeout(discordLookupTimeout);
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! Map) return null;
      final name = (body['name'] as String?)?.trim() ?? '';
      return name.isEmpty ? null : name;
    } on Object {
      return null;
    }
  }
}

final discordSenderProvider = Provider(
  (ref) => DiscordSender(ref.watch(httpClientProvider)),
);
