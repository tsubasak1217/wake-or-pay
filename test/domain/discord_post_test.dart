import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/discord_post.dart';
import 'package:wake_or_pay/domain/models.dart';

/// The Discord post, built and checked before a byte goes out — spec 11.5 and
/// 11.6. Nothing here touches a network or a disk.

/// Nothing on this device: the default for a builder that must not guess a
/// file into existence.
bool noFiles(String path) => false;

/// One file, and only that one.
bool Function(String) only(String path) => (p) => p == path;

void main() {
  group('discordQuote', () {
    test('one line gets one marker', () {
      expect(discordQuote('ごめんなさい。'), '> ごめんなさい。');
    });

    test('every line of a paragraph is quoted, not just the first', () {
      expect(
        discordQuote('ごめんなさい。\nこんどジュースおごります。'),
        '> ごめんなさい。\n> こんどジュースおごります。',
        reason:
            'one marker in front of a paragraph quotes the first line only, '
            'and the rest falls out of the block',
      );
    });

    test('a blank line inside stays inside the block', () {
      expect(discordQuote('あ\n\nい'), '> あ\n> \n> い');
    });

    test('nothing to quote quotes nothing', () {
      expect(discordQuote(''), '');
      expect(discordQuote('   \n  '), '');
    });
  });

  group('discordOversleepContent', () {
    const message = 'ごめんなさい。こんどジュースおごります。';

    test('a Discord ID becomes a mention', () {
      expect(
        discordOversleepContent(
          discordUserId: '123456789',
          userName: '山田花子',
          message: message,
        ),
        '<@123456789> が寝坊をしています！\n> ごめんなさい。こんどジュースおごります。',
      );
    });

    test('a pasted mention is stripped back to the ID', () {
      expect(
        discordOversleepContent(
          discordUserId: '<@123456789>',
          userName: '山田花子',
          message: message,
        ),
        startsWith('<@123456789> が寝坊をしています！'),
        reason: 'Discord puts the whole mention on the clipboard, not the ID',
      );
    });

    test('without an ID it names the user instead', () {
      expect(
        discordOversleepContent(
          discordUserId: null,
          userName: '山田花子',
          message: message,
        ),
        '山田花子 が寝坊をしています！\n> ごめんなさい。こんどジュースおごります。',
      );
      expect(
        discordOversleepContent(
          discordUserId: '',
          userName: '山田花子',
          message: message,
        ),
        startsWith('山田花子 が寝坊をしています！'),
      );
    });

    test('with neither, the same fallback the mail and the SMS use', () {
      expect(
        discordOversleepContent(
          discordUserId: '',
          userName: '   ',
          message: message,
        ),
        '$oversleepUserNameFallback が寝坊をしています！\n> ごめんなさい。こんどジュースおごります。',
      );
    });

    test('the default body is the share model\'s, not a second copy', () {
      final at = DateTime(2026, 8, 27, 7, 5);
      expect(
        discordOversleepContent(
          discordUserId: '1',
          userName: '山田花子',
          message: oversleepShareBodyFor(const OversleepShare(), at),
        ),
        '<@1> が寝坊をしています！\n> 07:05 のアラームを解除できていません。',
      );
    });

    test('an empty message leaves no empty quote line', () {
      expect(
        discordOversleepContent(
          discordUserId: '1',
          userName: '山田花子',
          message: '   ',
        ),
        '<@1> が寝坊をしています！',
        reason: 'a bare 「> 」 would read as the app trailing off',
      );
    });

    test('a message longer than Discord allows is cut, not refused', () {
      final content = discordOversleepContent(
        discordUserId: '1',
        userName: '山田花子',
        message: 'あ' * 3000,
      );
      expect(content.length, discordContentLimit);
      expect(content, endsWith('…'));
    });
  });

  group('truncateDiscordContent', () {
    test('the boundary: 2000 stands, 2001 is cut to 2000', () {
      final exact = 'あ' * discordContentLimit;
      expect(truncateDiscordContent(exact), exact);
      expect(truncateDiscordContent(exact).length, discordContentLimit);

      final over = 'あ' * (discordContentLimit + 1);
      final cut = truncateDiscordContent(over);
      expect(cut.length, discordContentLimit);
      expect(cut, endsWith('…'));
      expect(cut.substring(0, discordContentLimit - 1), 'あ' * 1999);
    });

    test('the cut never lands inside a surrogate pair', () {
      // 😴 is two code units, so a cut at an odd budget must drop the whole
      // emoji rather than half of it and leave a replacement glyph behind.
      final cut = truncateDiscordContent('😴' * 10, limit: 7);
      expect(cut, '😴😴😴…', reason: '3 emoji is 6 units, plus the ellipsis');
      expect(cut.runes.length, 4);
    });
  });

  group('buildDiscordPost', () {
    String contentOf(DiscordPost post) =>
        (jsonDecode(post.fields['payload_json']!) as Map)['content'] as String;

    test('content only: the body travels in payload_json, no file', () {
      final post = buildDiscordPost(content: 'こんにちは', fileExists: noFiles);
      expect(post.fields.keys, ['payload_json']);
      expect(contentOf(post), 'こんにちは');
      expect(post.file, isNull);
    });

    test('with a recording, the same shape plus files[0]', () {
      final post = buildDiscordPost(
        content: 'こんにちは',
        recordingPath: '/tmp/a.m4a',
        fileExists: only('/tmp/a.m4a'),
      );
      expect(
        post.fields.keys,
        ['payload_json'],
        reason: 'one shape for both cases, so there is one thing to get right',
      );
      expect(contentOf(post), 'こんにちは');
      expect(
        post.file,
        const DiscordFilePart(
          field: 'files[0]',
          filename: discordRecordingFilename,
          path: '/tmp/a.m4a',
        ),
      );
      expect(
        post.file!.filename,
        'share.m4a',
        reason: 'the channel never sees the app-private path',
      );
    });

    test('a recording that is no longer there is dropped, not fatal', () {
      final post = buildDiscordPost(
        content: 'こんにちは',
        recordingPath: '/tmp/deleted.m4a',
        fileExists: noFiles,
      );
      expect(post.file, isNull);
      expect(
        contentOf(post),
        'こんにちは',
        reason: 'a user who deleted the file must still get the message',
      );
    });

    test('a blank path is not a path', () {
      expect(
        buildDiscordPost(
          content: 'x',
          recordingPath: '   ',
          fileExists: (_) => true,
        ).file,
        isNull,
      );
    });

    test('an over-long body is cut here too', () {
      final post = buildDiscordPost(content: 'あ' * 2500, fileExists: noFiles);
      expect(contentOf(post).length, discordContentLimit);
    });
  });

  group('DiscordPostResult', () {
    test('each outcome says which of the user\'s problems they have', () {
      expect(const DiscordPostResult.success(204).label, '成功');
      expect(const DiscordPostResult(ok: true, statusCode: 200).label, '成功');
      expect(
        const DiscordPostResult(ok: false, statusCode: 404).label,
        '失敗（HTTP 404）',
        reason: '404 is a webhook that was deleted, and the user can fix that',
      );
      expect(
        const DiscordPostResult(ok: false, error: 'SocketException').label,
        '失敗（通信エラー）',
      );
    });

    test('it is a value, so a log row can compare two of them', () {
      expect(
        const DiscordPostResult(ok: false, statusCode: 404),
        const DiscordPostResult(ok: false, statusCode: 404),
      );
      expect(
        const DiscordPostResult(ok: false, statusCode: 404),
        isNot(const DiscordPostResult(ok: false, statusCode: 401)),
      );
    });
  });
}
