import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/app/theme.dart';
import 'package:wake_or_pay/app/theme_controller.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/main.dart';

import '../helpers.dart';

Future<void> pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  // UncontrolledProviderScope, so the container outlives the widget tree and
  // drift's stream teardown does not leave a timer pending inside the test.
  final container = await testContainer(prefs: prefs);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const WakeOrPayApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts on Home and can reach settings', (tester) async {
    await pumpApp(tester);
    expect(find.text('覚悟の目覚まし'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('設定'), findsOneWidget);
  });

  testWidgets('selecting an unlocked theme recolors the app', (tester) async {
    await pumpApp(
      tester,
      prefs: {
        'settings.unlockedThemeIds': [
          AppThemes.defaultThemeId,
          AppThemes.sunrise.id,
        ],
      },
    );
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    Brightness brightness() =>
        Theme.of(tester.element(find.text('設定'))).colorScheme.brightness;

    expect(brightness(), AppThemes.midnight.brightness);

    await tester.tap(find.text(AppThemes.sunrise.name));
    await tester.pumpAndSettle();

    expect(brightness(), AppThemes.sunrise.brightness);
  });

  test('the chosen theme survives a restart', () async {
    final first = await testContainer();
    await first
        .read(settingsProvider.notifier)
        .selectTheme(AppThemes.forest.id);

    // A fresh container reading the same store, i.e. a relaunch.
    final second = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          first.read(sharedPreferencesProvider),
        ),
      ],
    );
    addTearDown(second.dispose);
    expect(second.read(currentThemeProvider).id, AppThemes.forest.id);
  });

  test('every theme id resolves, unknown falls back to the default', () {
    for (final theme in AppThemes.all) {
      expect(AppThemes.byId(theme.id).id, theme.id);
    }
    expect(AppThemes.byId('nope').id, AppThemes.defaultThemeId);
    expect(AppThemes.byId(AppThemes.defaultThemeId).price, 0);
  });
}
