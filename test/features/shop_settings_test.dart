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

Future<void> openShop(WidgetTester tester) async {
  await tester.tap(find.text('ショップ'));
  await tester.pumpAndSettle();
}

/// 設定 has one entrance now: オプション › 設定・テーマ.
Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('appHeaderOptions')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('optionsSettingsRow')));
  await tester.pumpAndSettle();
}

void main() {
  group('ショップ', () {
    testWidgets('shows both balances', (tester) async {
      final container = await pumpHome(tester);
      await container
          .read(walletRepositoryProvider)
          .write(const Wallet(coins: 300, tokens: 7));
      await openShop(tester);

      expect(find.text('ショップ'), findsWidgets);
      expect(find.text('🪙 300'), findsOneWidget);
      expect(find.text('🎁 7'), findsOneWidget);
      expect(find.text('コインとトークンは交換できません。'), findsOneWidget);
      expect(find.textContaining('コインをトークン'), findsNothing);
    });

    testWidgets('dev charge adds 1,000 coins and is labelled as dev-only', (
      tester,
    ) async {
      final container = await pumpHome(tester);
      await openShop(tester);

      expect(find.text('🪙 0'), findsOneWidget);
      expect(find.text('コインを手に入れる'), findsOneWidget);
      expect(find.textContaining('開発用'), findsWidgets);
      expect(find.textContaining('コインの入手方法は準備中です。'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('shopDevCharge')));
      await tester.pumpAndSettle();

      expect(find.text('🪙 1000'), findsOneWidget);
      expect(
        (await container.read(walletRepositoryProvider).read()).coins,
        1000,
      );
    });

    testWidgets('carries no history, no contact log and no settings link', (
      tester,
    ) async {
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
      await container
          .read(contactEventRepositoryProvider)
          .save(
            ContactEvent(
              id: 'e1',
              sessionId: 's1',
              firedAt: DateTime(2026, 8, 27, 7, 5),
              contactName: '田中太郎さん',
              channel: ContactChannel.sms,
            ),
          );

      await openShop(tester);

      expect(find.text('履歴'), findsNothing);
      expect(find.text('8/27 07:00'), findsNothing);
      expect(find.text('起床失敗'), findsNothing);
      expect(find.byKey(const ValueKey('activityContactLog')), findsNothing);
      expect(find.text('設定・テーマ'), findsNothing);
    });

    testWidgets('ショップ sells no feature', (tester) async {
      await pumpHome(tester);
      await openShop(tester);

      for (final word in const ['課金', '購入', '広告', 'プレミアム']) {
        expect(find.textContaining(word), findsNothing, reason: word);
      }
    });
  });

  group('Settings', () {
    testWidgets('a locked theme cannot be taken without tokens', (
      tester,
    ) async {
      final container = await pumpHome(tester);
      await openSettings(tester);

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

      await openSettings(tester);

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
