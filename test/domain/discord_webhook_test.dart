import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/models.dart';

/// A URL of exactly the shape Discord's own copy button hands back.
const good = 'https://discord.com/api/webhooks/123456789/abcTOKEN';

void main() {
  group('isDiscordWebhookUrl', () {
    test('the shape the copy button hands back', () {
      expect(isDiscordWebhookUrl(good), isTrue);
    });

    test('every host Discord still serves webhooks from', () {
      for (final host in const [
        'discord.com',
        'www.discord.com',
        'canary.discord.com',
        'ptb.discord.com',
        'discordapp.com',
        'www.discordapp.com',
        'canary.discordapp.com',
        'ptb.discordapp.com',
      ]) {
        expect(
          isDiscordWebhookUrl('https://$host/api/webhooks/123456789/abcTOKEN'),
          isTrue,
          reason: '$host is a working webhook host',
        );
      }
    });

    test('a versioned path is just as valid', () {
      // Discord's own button emits the unversioned form, but /api/v10/… works
      // and users do paste it.
      expect(
        isDiscordWebhookUrl(
          'https://discord.com/api/v10/webhooks/123456789/abcTOKEN',
        ),
        isTrue,
      );
    });

    test('the token may be any non-empty segment', () {
      // Permissive on purpose: Discord has changed the token's shape before,
      // and a rejected working URL is worse than an accepted broken one.
      expect(isDiscordWebhookUrl('https://discord.com/api/webhooks/1/x'),
          isTrue);
    });

    test('everything the sender depends on is strict', () {
      expect(
        isDiscordWebhookUrl('http://discord.com/api/webhooks/123456789/abc'),
        isFalse,
        reason: 'a token must not travel in the clear',
      );
      expect(
        isDiscordWebhookUrl('https://example.com/api/webhooks/123456789/abc'),
        isFalse,
        reason: 'not a Discord host',
      );
      expect(
        isDiscordWebhookUrl('https://discord.com/api/webhooks/123456789'),
        isFalse,
        reason: 'no token, nothing to post with',
      );
      expect(
        isDiscordWebhookUrl('https://discord.com/api/webhooks/abc/token'),
        isFalse,
        reason: 'the webhook id is numeric',
      );
      expect(
        isDiscordWebhookUrl('https://discord.com/channels/123/456'),
        isFalse,
        reason: 'a channel link is not a webhook',
      );
      expect(isDiscordWebhookUrl('おはよう'), isFalse);
      expect(isDiscordWebhookUrl(''), isFalse);
    });
  });

  group('normalizeDiscordWebhookUrl', () {
    test('whitespace, query and a trailing slash are noise', () {
      expect(normalizeDiscordWebhookUrl('  $good  '), good);
      expect(normalizeDiscordWebhookUrl('$good?thread_id=42'), good);
      expect(normalizeDiscordWebhookUrl('$good/'), good);
      expect(normalizeDiscordWebhookUrl('$good#frag'), good);
      expect(normalizeDiscordWebhookUrl('  $good/?thread_id=42'), good);
    });

    test('a URL pasted out of a browser still validates', () {
      expect(isDiscordWebhookUrl('  $good/?thread_id=42  '), isTrue);
    });

    test('nothing else is touched', () {
      expect(normalizeDiscordWebhookUrl(good), good);
      expect(normalizeDiscordWebhookUrl(''), '');
    });
  });

  group('DiscordWebhook', () {
    final webhook = DiscordWebhook(
      id: 'w1',
      url: good,
      displayName: 'みんなのサーバー/#一般',
      createdAt: DateTime(2026, 8, 27),
    );

    test('usable needs both a URL to post to and a name to pick it by', () {
      expect(webhook.isUsable, isTrue);
      expect(webhook.copyWith(url: '   ').isUsable, isFalse);
      expect(webhook.copyWith(displayName: '  ').isUsable, isFalse);
    });

    test('copyWith replaces only what it is given', () {
      final renamed = webhook.copyWith(displayName: '別名');
      expect(renamed.displayName, '別名');
      expect(renamed.url, good, reason: 'kept');
      expect(renamed.createdAt, webhook.createdAt);
    });
  });

  group('webhookDefaultName', () {
    test('server only — where it lands in practice', () {
      // channel_name is null from Discord, so the server name alone is the
      // label, and never the webhook's own 「Wake or Pay」.
      expect(
        webhookDefaultName('みんなのサーバー', '', 'Wake or Pay'),
        'みんなのサーバー',
      );
    });

    test('server and channel — the form the user recognises', () {
      expect(
        webhookDefaultName('みんなのサーバー', '一般', 'Wake or Pay'),
        'みんなのサーバー/#一般',
      );
    });

    test('neither — the webhook name, then the plain fallback', () {
      // No server name came back: the webhook's own name is a real name and
      // beats the empty-list-proof fallback.
      expect(webhookDefaultName('', '', 'Wake or Pay'), 'Wake or Pay');
      // Nothing at all: an unnamed row could not be picked out of the list.
      expect(webhookDefaultName('', '', ''), 'Discord 連携先');
      // Whitespace is nothing.
      expect(webhookDefaultName('   ', '', '  '), 'Discord 連携先');
    });
  });
}
