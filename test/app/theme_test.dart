import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/app/theme.dart';
import 'package:wake_or_pay/main.dart';

void main() {
  testWidgets('starts on Home and can reach settings', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: WakeOrPayApp()));
    await tester.pumpAndSettle();

    expect(find.text('覚悟の目覚まし'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('設定'), findsOneWidget);
  });

  testWidgets('selecting a theme recolors the app', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: WakeOrPayApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    Brightness brightness() =>
        Theme.of(tester.element(find.text('設定'))).colorScheme.brightness;

    expect(brightness(), AppThemes.midnight.brightness);

    await tester.tap(find.text(AppThemes.sunrise.name));
    await tester.pumpAndSettle();

    expect(brightness(), AppThemes.sunrise.brightness);
  });

  test('every theme id resolves, unknown falls back to the default', () {
    for (final theme in AppThemes.all) {
      expect(AppThemes.byId(theme.id).id, theme.id);
    }
    expect(AppThemes.byId('nope').id, AppThemes.defaultThemeId);
    expect(AppThemes.byId(AppThemes.defaultThemeId).price, 0);
  });
}
