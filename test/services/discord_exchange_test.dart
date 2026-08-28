import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/services/discord_exchange.dart';

void main() {
  group('buildDiscordExchangeUrl', () {
    test('appends the path to a bare base', () {
      expect(
        buildDiscordExchangeUrl('https://w.example.workers.dev'),
        'https://w.example.workers.dev/discord/exchange',
      );
    });

    test('a trailing slash — or three — does not double the slash', () {
      expect(
        buildDiscordExchangeUrl('https://w.example.workers.dev/'),
        'https://w.example.workers.dev/discord/exchange',
      );
      expect(
        buildDiscordExchangeUrl('https://w.example.workers.dev///'),
        'https://w.example.workers.dev/discord/exchange',
      );
    });

    test('the full URL pasted from the README is left alone', () {
      expect(
        buildDiscordExchangeUrl(
          'https://w.example.workers.dev/discord/exchange',
        ),
        'https://w.example.workers.dev/discord/exchange',
      );
    });

    test('surrounding whitespace from a paste is trimmed', () {
      expect(
        buildDiscordExchangeUrl('  https://w.example.workers.dev \n'),
        'https://w.example.workers.dev/discord/exchange',
      );
    });
  });

  group('isDiscordExchangeEndpoint', () {
    test('https only — the body carries an authorization code', () {
      expect(isDiscordExchangeEndpoint('https://w.example.workers.dev'), isTrue);
      expect(isDiscordExchangeEndpoint('http://w.example.workers.dev'), isFalse);
    });

    test('empty is not an endpoint', () {
      expect(isDiscordExchangeEndpoint(''), isFalse);
      expect(isDiscordExchangeEndpoint('   '), isFalse);
      expect(isDiscordExchangeEndpoint(kDiscordExchangeEndpoint), isFalse);
    });

    test('nonsense is not an endpoint', () {
      expect(isDiscordExchangeEndpoint('workers.dev'), isFalse);
      expect(isDiscordExchangeEndpoint('https://'), isFalse);
    });
  });

  group('parseDiscordExchangeResponse', () {
    test('reads the webhook and both names', () {
      final grant = parseDiscordExchangeResponse(
        '{"webhook":{"id":"999","url":"https://discord.com/api/webhooks/999/T",'
        '"channel_id":"222","guild_id":"111","name":"Wake or Pay"},'
        '"guild_name":"みんなのサーバー","channel_name":"一般"}',
      );
      expect(grant!.id, '999');
      expect(grant.url, 'https://discord.com/api/webhooks/999/T');
      expect(grant.channelId, '222');
      expect(grant.guildId, '111');
      expect(grant.displayName, 'みんなのサーバー/#一般');
    });

    test('the display name falls back a step at a time', () {
      DiscordWebhookGrant grant({
        String guild = '',
        String channel = '',
        String name = '',
      }) => DiscordWebhookGrant(
        id: '1',
        url: 'u',
        guildName: guild,
        channelName: channel,
        webhookName: name,
      );

      expect(grant(guild: 'S', channel: 'C').displayName, 'S/#C');
      // The realistic case: channel_name needs a scope this app never asks
      // for, so the server name alone is what a linked channel is called.
      expect(grant(guild: 'S', name: 'W').displayName, 'S');
      expect(grant(channel: 'C', name: 'W').displayName, '#C');
      expect(grant(name: 'W').displayName, 'W');
      expect(grant().displayName, 'Discord 共有先');
    });

    test('an answer with no webhook URL is not a grant', () {
      expect(parseDiscordExchangeResponse('{"webhook":{"id":"9"}}'), isNull);
      expect(
        parseDiscordExchangeResponse('{"webhook":{"url":"https://x"}}'),
        isNull,
      );
      expect(parseDiscordExchangeResponse('{"error":"nope"}'), isNull);
    });

    test('HTML from a proxy is null, not a throw', () {
      expect(parseDiscordExchangeResponse('<html>'), isNull);
      expect(parseDiscordExchangeResponse(''), isNull);
      expect(parseDiscordExchangeResponse('[]'), isNull);
    });

    test('missing optional names come back empty, not null-crashing', () {
      final grant = parseDiscordExchangeResponse(
        '{"webhook":{"id":"9","url":"https://x","channel_id":null,'
        '"guild_id":null,"name":null},"guild_name":null,"channel_name":null}',
      );
      expect(grant!.guildName, isEmpty);
      expect(grant.channelId, isEmpty);
      expect(grant.displayName, 'Discord 共有先');
    });
  });
}
