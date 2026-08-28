import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../domain/discord_post.dart';
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

/// How long a post is allowed to take.
///
/// Longer than [discordLookupTimeout] because this one carries a 30 second
/// recording up a phone's uplink, and nobody is waiting at a text field for
/// it. Still bounded: the ringing screen calls this, and a webhook that never
/// answers must not leave the dispatcher hanging until the user gives up.
const discordPostTimeout = Duration(seconds: 30);

/// Posting an overslept alarm to one 共有先.
///
/// An interface because stage D fires the same posts from a background
/// isolate, and because every test in this app must be able to hand in
/// something that does not reach the network: a webhook URL is somebody's live
/// Discord channel.
abstract class DiscordWebhookSender {
  /// Never throws. See [DiscordPostResult].
  Future<DiscordPostResult> post({
    required String url,
    required String content,
    String? recordingPath,
  });
}

/// The real one, over [httpClientProvider].
class HttpDiscordWebhookSender implements DiscordWebhookSender {
  const HttpDiscordWebhookSender(this._client);

  final http.Client _client;

  /// Every failure is a value, never a throw.
  ///
  /// This runs at the moment the alarm has already been slept through, from
  /// the ringing screen's dispatcher. A webhook that was revoked last week, a
  /// phone in a tunnel, a recording file that vanished — none of them may take
  /// down the screen, the loss clock, or the *other* webhook in the same list.
  @override
  Future<DiscordPostResult> post({
    required String url,
    required String content,
    String? recordingPath,
  }) async {
    try {
      final plan = buildDiscordPost(
        content: content,
        recordingPath: recordingPath,
        fileExists: (path) => File(path).existsSync(),
      );
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(normalizeDiscordWebhookUrl(url)),
      )..fields.addAll(plan.fields);
      final file = plan.file;
      if (file != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            file.field,
            file.path,
            filename: file.filename,
          ),
        );
      }
      final streamed = await _client.send(request).timeout(discordPostTimeout);
      // Drained even though nothing here reads it: an unread response body
      // holds the connection open.
      final response = await http.Response.fromStream(streamed);
      final code = response.statusCode;
      return code >= 200 && code < 300
          ? DiscordPostResult.success(code)
          : DiscordPostResult(ok: false, statusCode: code);
    } on Object catch (e) {
      return DiscordPostResult(ok: false, error: '$e');
    }
  }
}

final discordWebhookSenderProvider = Provider<DiscordWebhookSender>(
  (ref) => HttpDiscordWebhookSender(ref.watch(httpClientProvider)),
);

/// How the `DELETE` on a 共有先 turned out.
///
/// - [deleted]: Discord answered 204 — the webhook is gone there too.
/// - [alreadyGoneOrInvalid]: 401 / 403 / 404 — the remote webhook is already
///   absent or its token no longer authorizes (someone deleted it in Discord,
///   or reset it). There is nothing left to delete, so the local row should go
///   too — the two are already in sync.
/// - [httpError]: any other status. Something answered, but not with a delete
///   we can trust; the user is asked whether to drop the local row anyway.
/// - [networkError]: the request never got an answer (offline, timeout). Same
///   question — never trap the user with an undeletable row when Discord is
///   simply unreachable.
enum DiscordDeleteOutcome { deleted, alreadyGoneOrInvalid, httpError, networkError }

/// The result of [DiscordWebhookDeleter.deleteRemote]. A value, never a throw.
@immutable
class DiscordDeleteResult {
  const DiscordDeleteResult(this.outcome, {this.statusCode});

  final DiscordDeleteOutcome outcome;

  /// The HTTP status, when there was one. Null means no answer came back.
  final int? statusCode;

  /// Whether the local row should be removed without further asking: the remote
  /// is gone ([deleted]) or was already gone ([alreadyGoneOrInvalid]).
  bool get removeLocalSilently =>
      outcome == DiscordDeleteOutcome.deleted ||
      outcome == DiscordDeleteOutcome.alreadyGoneOrInvalid;

  /// One short Japanese phrase naming the failure, for the 「…できませんでした
  /// （{reason}）」 dialog. Only meaningful when [removeLocalSilently] is false.
  String get reason => statusCode != null ? 'HTTP $statusCode' : '通信エラー';

  @override
  bool operator ==(Object other) =>
      other is DiscordDeleteResult &&
      other.outcome == outcome &&
      other.statusCode == statusCode;

  @override
  int get hashCode => Object.hash(outcome, statusCode);

  @override
  String toString() => 'DiscordDeleteResult($outcome, $statusCode)';
}

/// Deletes the **remote** Discord webhook that a 共有先 stands for.
///
/// An interface so tests hand in something that does not reach the network — a
/// webhook URL is somebody's live Discord channel, and a DELETE against it is
/// irreversible.
abstract class DiscordWebhookDeleter {
  /// Never throws. See [DiscordDeleteResult].
  Future<DiscordDeleteResult> deleteRemote(String webhookUrl);
}

/// The real one, over [httpClientProvider].
class HttpDiscordWebhookDeleter implements DiscordWebhookDeleter {
  const HttpDiscordWebhookDeleter(this._client);

  final http.Client _client;

  /// `DELETE …/webhooks/{id}/{token}` — no auth header, the token in the path
  /// is the credential (verified against Discord's docs). Every failure is a
  /// value: this is called from a confirm dialog the user is watching, and a
  /// throw here would leave them with a spinner that never resolves.
  @override
  Future<DiscordDeleteResult> deleteRemote(String webhookUrl) async {
    try {
      final response = await _client
          .delete(Uri.parse(discordWebhookDeleteUrl(webhookUrl)))
          .timeout(discordPostTimeout);
      final code = response.statusCode;
      if (code >= 200 && code < 300) {
        return const DiscordDeleteResult(DiscordDeleteOutcome.deleted);
      }
      if (code == 401 || code == 403 || code == 404) {
        return DiscordDeleteResult(
          DiscordDeleteOutcome.alreadyGoneOrInvalid,
          statusCode: code,
        );
      }
      return DiscordDeleteResult(
        DiscordDeleteOutcome.httpError,
        statusCode: code,
      );
    } on Object {
      return const DiscordDeleteResult(DiscordDeleteOutcome.networkError);
    }
  }
}

final discordWebhookDeleterProvider = Provider<DiscordWebhookDeleter>(
  (ref) => HttpDiscordWebhookDeleter(ref.watch(httpClientProvider)),
);
