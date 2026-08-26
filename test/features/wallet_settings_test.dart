import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/app/theme.dart';
import 'package:wake_or_pay/app/theme_controller.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/main.dart';

import '../helpers.dart';

Future<ProviderContainer> pumpHome(WidgetTester tester) async {
  final container = await testContainer(extra: [fakeAlarmServiceOverride()]);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const WakeOrPayApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('Wallet', () {
    testWidgets('dev charge adds 1,000 coins and is labelled as dev-only', (
      tester,
    ) async {
      final container = await pumpHome(tester);
      await tester.tap(find.text('ウォレット'));
      await tester.pumpAndSettle();

      expect(find.text('🪙 0'), findsOneWidget);
      expect(find.textContaining('開発用'), findsWidgets);

      await tester.tap(find.text('開発用チャージ（+1,000コイン）'));
      await tester.pumpAndSettle();

      expect(find.text('🪙 1000'), findsOneWidget);
      expect(
        (await container.read(walletRepositoryProvider).read()).coins,
        1000,
      );
    });

    testWidgets('history lists past sessions', (tester) async {
      final container = await pumpHome(tester);
      await container
          .read(alarmSessionRepositoryProvider)
          .save(
            AlarmSession(
              id: 's1',
              alarmId: 'a1',
              firedAt: DateTime(2026, 8, 27, 7),
              dismissedAt: DateTime(2026, 8, 27, 7, 13),
              status: SessionStatus.failed,
              loss: 1300,
              kakugoSnapshot: const Kakugo(ratePerMinute: 100, cap: 2000),
            ),
          );

      await tester.tap(find.text('ウォレット'));
      await tester.pumpAndSettle();

      expect(find.text('8/27 07:00'), findsOneWidget);
      expect(find.text('起床失敗'), findsOneWidget);
      expect(find.text('−1300'), findsOneWidget);
    });

    testWidgets('there is no coin to token conversion offered', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.text('ウォレット'));
      await tester.pumpAndSettle();

      expect(find.text('コインとトークンは交換できません。'), findsOneWidget);
      expect(find.textContaining('コインをトークン'), findsNothing);
    });
  });

  group('Settings', () {
    testWidgets('a locked theme cannot be taken without tokens', (
      tester,
    ) async {
      final container = await pumpHome(tester);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, '交換'), findsNWidgets(2));

      // Priced but unaffordable: the button is disabled, nothing changes.
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '交換').first,
      );
      expect(button.onPressed, isNull);
      expect(container.read(settingsProvider).unlockedThemeIds, {
        AppThemes.defaultThemeId,
      });
    });

    testWidgets('spending 100 tokens unlocks and applies a theme', (
      tester,
    ) async {
      final container = await pumpHome(tester);
      await container
          .read(walletRepositoryProvider)
          .write(const Wallet(tokens: 250));

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, '交換').first);
      await tester.pumpAndSettle();

      final settings = container.read(settingsProvider);
      expect(settings.unlockedThemeIds, contains(AppThemes.sunrise.id));
      expect(settings.themeId, AppThemes.sunrise.id);
      expect(
        (await container.read(walletRepositoryProvider).read()).tokens,
        150,
      );
      expect(
        Theme.of(tester.element(find.text('設定'))).colorScheme.brightness,
        AppThemes.sunrise.brightness,
      );
    });

    testWidgets('the default theme is free and always unlocked', (
      tester,
    ) async {
      final container = await pumpHome(tester);
      expect(
        container.read(settingsProvider).unlockedThemeIds,
        contains(AppThemes.defaultThemeId),
      );
      expect(AppThemes.byId(AppThemes.defaultThemeId).price, 0);
    });
  });
}
