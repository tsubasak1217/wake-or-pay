import 'package:flutter/cupertino.dart';
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

/// 設定 is reached through オプション: Home has no app bar action any more, only
/// the shared header, and ショップ carries no links of its own.
Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('appHeaderOptions')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('optionsSettingsRow')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts on Home and can reach settings', (tester) async {
    await pumpApp(tester);
    expect(find.byKey(const ValueKey('appHeader')), findsOneWidget);

    await openSettings(tester);
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
    await openSettings(tester);

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

  test('every theme is set in M PLUS Rounded 1c', () {
    for (final theme in AppThemes.all) {
      final data = theme.themeData;
      expect(
        data.textTheme.bodyMedium?.fontFamily,
        appFontFamily,
        reason: '${theme.id} body',
      );
      expect(
        data.primaryTextTheme.titleLarge?.fontFamily,
        appFontFamily,
        reason: '${theme.id} app bar',
      );
    }
  });

  testWidgets('the time wheel is drawn in it too', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final picker = tester.widget<CupertinoDatePicker>(
      find.byKey(const ValueKey('timeWheel')),
    );
    expect(picker, isNotNull);
    final cupertino = CupertinoTheme.of(
      tester.element(find.byKey(const ValueKey('timeWheel'))),
    );
    expect(
      cupertino.textTheme.dateTimePickerTextStyle.fontFamily,
      appFontFamily,
      reason: 'Cupertino carries its own theme and would use its own face',
    );
  });
}
