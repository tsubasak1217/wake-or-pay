import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'models.dart';

/// The longest `content` Discord will accept on a webhook post.
///
/// Discord answers a longer one with a 400 and posts nothing, so a message the
/// user typed at length would silently become no message at all — the one
/// outcome this feature exists to prevent.
const discordContentLimit = 2000;

/// [content] cut to [limit] characters, ending in an ellipsis when it was cut.
/// Pure.
///
/// Walks runes rather than code units so a cut never lands in the middle of a
/// surrogate pair and turns the last character into a replacement glyph. The
/// budget is still counted in code units, because that is what Discord counts.
String truncateDiscordContent(String content, {int limit = discordContentLimit}) {
  if (content.length <= limit) return content;
  final kept = StringBuffer();
  var used = 0;
  for (final rune in content.runes) {
    final piece = String.fromCharCode(rune);
    if (used + piece.length > limit - 1) break;
    kept.write(piece);
    used += piece.length;
  }
  return '$kept…';
}

/// [message] in Discord's quote notation. Pure.
///
/// **Every** line gets its own `> `. Discord's quote is per line: one marker in
/// front of a paragraph quotes the first line only, and every line after it
/// falls out of the block and reads as the app talking rather than as the
/// user. An empty message quotes nothing at all.
String discordQuote(String message) {
  final trimmed = message.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.split('\n').map((line) => '> $line').join('\n');
}

/// The whole body posted to a 共有先, per spec 11.6. Pure.
///
/// ```
/// <@123456789> が寝坊をしています！
/// > ごめんなさい。こんどジュースおごります。
/// ```
///
/// The mention is the point of the first line: a post that only *names* the
/// sleeper is a post everyone scrolls past, and a post that pings them is one
/// their phone shouts about. Without a Discord ID there is nothing to ping, so
/// it falls back to the profile name — and to [oversleepUserNameFallback] when
/// there is not even one of those, exactly as the mail and the SMS do.
///
/// [message] is the share body — see `oversleepShareBodyFor`, which is where
/// the default sentence 「HH:MM のアラームを解除できていません。」 lives.
String discordOversleepContent({
  required String? discordUserId,
  required String userName,
  required String message,
}) {
  final id = normalizeDiscordUserId(discordUserId ?? '');
  final who = id.isEmpty ? oversleepSubjectName(userName) : '<@$id>';
  final quote = discordQuote(message);
  final headline = '$who が寝坊をしています！';
  return truncateDiscordContent(
    quote.isEmpty ? headline : '$headline\n$quote',
  );
}

/// One file attached to a webhook post.
@immutable
class DiscordFilePart {
  const DiscordFilePart({
    required this.field,
    required this.filename,
    required this.path,
  });

  /// Discord's own name for the first attachment of a multipart post.
  final String field;

  /// What the file is called *in the channel* — never the on-device path,
  /// which carries the alarm's id and the app's private directory in it.
  final String filename;

  /// Where to read the bytes from on this device.
  final String path;

  @override
  bool operator ==(Object other) =>
      other is DiscordFilePart &&
      other.field == field &&
      other.filename == filename &&
      other.path == path;

  @override
  int get hashCode => Object.hash(field, filename, path);

  @override
  String toString() => 'DiscordFilePart($field, $filename, $path)';
}

/// What the share recording is called once it reaches the channel.
const discordRecordingFilename = 'share.m4a';

/// A whole `multipart/form-data` post, described without sending it, per spec
/// 11.5.
@immutable
class DiscordPost {
  const DiscordPost({required this.fields, this.file});

  /// The form fields, ready to be written as they stand.
  final Map<String, String> fields;

  /// The share recording, or null when there is none to attach.
  final DiscordFilePart? file;

  @override
  bool operator ==(Object other) =>
      other is DiscordPost &&
      mapEquals(other.fields, fields) &&
      other.file == file;

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(fields.entries), file);

  @override
  String toString() => 'DiscordPost(${fields.keys.join(',')}, file $file)';
}

/// The post to make, built and checked before a byte goes out. Pure.
///
/// The body always travels in **`payload_json`**, with or without a file. A
/// bare `content` field works too when nothing is attached, but then the
/// with-file and the without-file post would be two different requests to
/// build, to read and to debug at 6am; Discord's own convention is
/// `payload_json` beside `files[0]`, and one shape means one thing to get
/// right.
///
/// [fileExists] is injected rather than reached for, both to keep this pure
/// and because it is the whole point of the check: a user who deleted the
/// recording out from under the app must still get the **message**. A missing
/// file is dropped here, quietly, instead of failing the post that matters.
DiscordPost buildDiscordPost({
  required String content,
  String? recordingPath,
  required bool Function(String path) fileExists,
}) {
  final path = recordingPath?.trim() ?? '';
  final attach = path.isNotEmpty && fileExists(path);
  return DiscordPost(
    fields: {
      'payload_json': jsonEncode({'content': truncateDiscordContent(content)}),
    },
    file: attach
        ? DiscordFilePart(
            field: 'files[0]',
            filename: discordRecordingFilename,
            path: path,
          )
        : null,
  );
}

/// How a single webhook post turned out.
///
/// Kept as a value rather than an exception because **every** outcome is an
/// ordinary one here: the alarm has already gone off, and a revoked webhook is
/// a line in the log, not a reason for anything above to stop.
@immutable
class DiscordPostResult {
  const DiscordPostResult({required this.ok, this.statusCode, this.error});

  const DiscordPostResult.success(int status)
    : ok = true,
      statusCode = status,
      error = null;

  final bool ok;

  /// The HTTP status, when there was one. Null means the request never got an
  /// answer at all.
  final int? statusCode;

  /// Whatever was thrown, for the log. Never shown to the user raw.
  final String? error;

  /// One short Japanese phrase for the log row and the SnackBar.
  ///
  /// The status is spelled out because it is the one thing that tells a user
  /// which of their problems they have: 404 is a webhook that was deleted,
  /// 401 a token that was reset, and 通信エラー is simply the train tunnel.
  String get label {
    if (ok) return '成功';
    if (statusCode != null) return '失敗（HTTP $statusCode）';
    return '失敗（通信エラー）';
  }

  @override
  bool operator ==(Object other) =>
      other is DiscordPostResult &&
      other.ok == ok &&
      other.statusCode == statusCode &&
      other.error == error;

  @override
  int get hashCode => Object.hash(ok, statusCode, error);

  @override
  String toString() => 'DiscordPostResult($label)';
}
