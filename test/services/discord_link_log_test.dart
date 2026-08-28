import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/services/discord_link_log.dart';

void main() {
  test('DiscordLogEntry.clock pads hh:mm:ss with zeros', () {
    final entry = DiscordLogEntry(DateTime(2026, 1, 1, 3, 28, 41), 'x');
    expect(entry.clock, '03:28:41');
  });

  group('DiscordLinkLog', () {
    test('caps at kDiscordLogLength, newest first', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(discordLinkLogProvider.notifier);

      for (var i = 0; i < kDiscordLogLength + 5; i++) {
        notifier.add('line $i', now: DateTime(2026, 1, 1, 0, 0, i));
      }

      final entries = container.read(discordLinkLogProvider);
      expect(entries, hasLength(kDiscordLogLength));
      expect(entries.first.message, 'line ${kDiscordLogLength + 4}');
      expect(entries.last.message, 'line 5');
    });

    test('clear empties the log', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(discordLinkLogProvider.notifier);

      notifier.add('a');
      notifier.clear();

      expect(container.read(discordLinkLogProvider), isEmpty);
    });
  });

  group('DiscordFlowStatusController', () {
    test('set updates the status and appends a matching log line', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(discordFlowStatusProvider.notifier)
          .set(DiscordFlowPhase.waiting, '承認を待っています…');

      expect(
        container.read(discordFlowStatusProvider).phase,
        DiscordFlowPhase.waiting,
      );
      expect(
        container.read(discordLinkLogProvider).single.message,
        '承認を待っています…',
      );
    });

    test('an empty message updates the phase without adding a blank log '
        'line', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(discordFlowStatusProvider.notifier)
          .set(DiscordFlowPhase.idle, '');

      expect(container.read(discordLinkLogProvider), isEmpty);
    });

    test('reset returns to idle without touching the log that led up to it',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(discordFlowStatusProvider.notifier);

      controller.set(DiscordFlowPhase.done, '連携しました');
      controller.reset();

      expect(
        container.read(discordFlowStatusProvider),
        const DiscordFlowStatus.idle(),
      );
      expect(container.read(discordLinkLogProvider), hasLength(1));
    });
  });

  group('DiscordFlowReporter', () {
    test('the silent reporter calls nothing and never throws', () {
      expect(
        () => DiscordFlowReporter.silent.phase(DiscordFlowPhase.opening, 'x'),
        returnsNormally,
      );
      expect(
        () => DiscordFlowReporter.silent.log('x'),
        returnsNormally,
      );
    });

    test('discordFlowReporterProvider wires phase() and log() to the two '
        'notifiers', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final reporter = container.read(discordFlowReporterProvider);

      reporter.phase(DiscordFlowPhase.working, '連携サーバーに問い合わせています…');
      expect(
        container.read(discordFlowStatusProvider).phase,
        DiscordFlowPhase.working,
      );

      reporter.log('Discord アプリで開きました');
      expect(
        container.read(discordLinkLogProvider).first.message,
        'Discord アプリで開きました',
      );
    });
  });
}
