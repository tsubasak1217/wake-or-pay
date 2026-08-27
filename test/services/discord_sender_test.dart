import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/services/discord_sender.dart';

import '../helpers.dart';

/// The real sender, over a client that never reaches the network — a webhook
/// URL is somebody's live Discord channel.

const url = 'https://discord.com/api/webhooks/123456789/token-abc';

void main() {
  group('HttpDiscordWebhookSender', () {
    test('a 204 is a success, and the body is what went out', () async {
      final http = FakeHttpClient();
      final result = await HttpDiscordWebhookSender(http).post(
        url: url,
        content: '<@1> が寝坊をしています！\n> おきて',
      );

      expect(result.ok, isTrue);
      expect(result.statusCode, 204);
      expect(result.label, '成功');

      final post = http.posted.single;
      expect(post.url, url);
      expect(post.content, '<@1> が寝坊をしています！\n> おきて');
      expect(post.filenames, isEmpty);
    });

    test('a recording rides along as files[0], named share.m4a', () async {
      final dir = Directory.systemTemp.createTempSync('wake_or_pay_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/a1-recording.m4a')
        ..writeAsBytesSync(const [0, 1, 2, 3]);

      final http = FakeHttpClient();
      final result = await HttpDiscordWebhookSender(
        http,
      ).post(url: url, content: 'おきて', recordingPath: file.path);

      expect(result.ok, isTrue);
      final post = http.posted.single;
      expect(post.content, 'おきて');
      expect(
        post.filenames,
        ['share.m4a'],
        reason: 'the channel never sees the app-private path',
      );
    });

    test('a recording that was deleted still posts the message', () async {
      final http = FakeHttpClient();
      final result = await HttpDiscordWebhookSender(http).post(
        url: url,
        content: 'おきて',
        recordingPath: '${Directory.systemTemp.path}/not-there-at-all.m4a',
      );

      expect(result.ok, isTrue);
      expect(http.posted.single.filenames, isEmpty);
      expect(http.posted.single.content, 'おきて');
    });

    test('a 404 is a failure that names the status', () async {
      final http = FakeHttpClient(postStatus: 404);
      final result = await HttpDiscordWebhookSender(
        http,
      ).post(url: url, content: 'おきて');

      expect(result.ok, isFalse);
      expect(result.statusCode, 404);
      expect(result.label, '失敗（HTTP 404）');
    });

    test('being offline is a result, never a throw', () async {
      final http = FakeHttpClient(throws: true);

      // No expectLater/throwsA here on purpose: the point is that nothing
      // escapes. This runs at the moment the alarm was slept through, and a
      // webhook that will not answer must not take down the ringing screen.
      final result = await HttpDiscordWebhookSender(
        http,
      ).post(url: url, content: 'おきて');

      expect(result.ok, isFalse);
      expect(result.statusCode, isNull);
      expect(result.error, contains('SocketException'));
      expect(result.label, '失敗（通信エラー）');
    });

    test('a URL with a query string on it is normalised first', () async {
      final http = FakeHttpClient();
      await HttpDiscordWebhookSender(
        http,
      ).post(url: '$url?thread_id=9/', content: 'おきて');
      expect(http.posted.single.url, url);
    });

    test('a URL that could never be parsed is a failed result', () async {
      final http = FakeHttpClient();
      final result = await HttpDiscordWebhookSender(
        http,
      ).post(url: '::not a url::', content: 'おきて');

      expect(result.ok, isFalse);
      expect(http.posted, isEmpty);
    });
  });

  group('DiscordSender.fetchWebhookName', () {
    test('the webhook\'s own name, when it can be had', () async {
      final http = FakeHttpClient(responses: {url: '{"name":"wake-up-bot"}'});
      expect(await DiscordSender(http).fetchWebhookName(url), 'wake-up-bot');
    });

    test('every failure is silent and gives null', () async {
      expect(
        await DiscordSender(FakeHttpClient(throws: true)).fetchWebhookName(url),
        isNull,
      );
      expect(
        await DiscordSender(FakeHttpClient()).fetchWebhookName(url),
        isNull,
        reason: 'a 404 from a revoked webhook is not a reason to refuse a save',
      );
      expect(
        await DiscordSender(
          FakeHttpClient(),
        ).fetchWebhookName('https://example.com/hooks/1/a'),
        isNull,
      );
    });
  });
}
