import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/app/profile_controller.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/data/repositories/profile_repository.dart';
import 'package:wake_or_pay/domain/profile_catalog.dart';
import 'package:wake_or_pay/main.dart';

import '../helpers.dart';

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  final container = await testContainer(
    prefs: prefs,
    extra: [fakeAlarmServiceOverride()],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const WakeOrPayApp(),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<ProviderContainer> openOverlay(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  final container = await pumpApp(tester, prefs: prefs);
  await tester.tap(find.byKey(const ValueKey('appHeaderAvatar')));
  await tester.pumpAndSettle();
  return container;
}

String headerName(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('appHeaderName'))).data!;

/// The overlay is taller than a test viewport, so anything below the fold has
/// to be scrolled into the list before it can be tapped.
Future<void> scrollTo(WidgetTester tester, Finder target) async {
  final list = find
      .descendant(
        of: find.byKey(const ValueKey('profileOverlay')),
        matching: find.byType(Scrollable),
      )
      .first;
  tester.state<ScrollableState>(list).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(target, 120, scrollable: list);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the avatar opens the overlay and 閉じる closes it', (
    tester,
  ) async {
    await openOverlay(tester);

    expect(find.byKey(const ValueKey('profileOverlay')), findsOneWidget);
    expect(find.text('プロフィール設定'), findsOneWidget);

    await scrollTo(tester, find.text('コレクション'));
    expect(find.text('コレクション'), findsOneWidget);
    await scrollTo(
      tester,
      find.byKey(const ValueKey('profileActivityPlaceholder')),
    );
    expect(
      find.byKey(const ValueKey('profileActivityPlaceholder')),
      findsOneWidget,
    );

    // The way out is outside the list, so it never needs scrolling to.
    await tester.tap(find.byKey(const ValueKey('profileOverlayClose')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profileOverlay')), findsNothing);
    // Non-opaque: the tab it covered was never left.
    expect(find.byKey(const ValueKey('appHeader')), findsOneWidget);
  });

  testWidgets('a downward flick puts it away', (tester) async {
    await openOverlay(tester);

    await tester.fling(
      find.byKey(const ValueKey('profileOverlayHandle')),
      const Offset(0, 300),
      1200,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profileOverlay')), findsNothing);
  });

  testWidgets('the header block counts the XP owed to the next level', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await container.read(profileProvider.notifier).addXp(60);
    await tester.tap(find.byKey(const ValueKey('appHeaderAvatar')));
    await tester.pumpAndSettle();

    // 60 XP is level 2 (50) with 90 still owed on the 150 boundary.
    expect(find.text('経験値 60 / 次のLvまで 90'), findsOneWidget);
  });

  testWidgets('editing the name updates the header behind it', (tester) async {
    final container = await openOverlay(tester);
    expect(find.text('未設定'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('profileUserNameRow')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('userNameField')),
      ' 山田花子 ',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(container.read(profileProvider).userName, '山田花子');

    await tester.tap(find.byKey(const ValueKey('profileOverlayClose')));
    await tester.pumpAndSettle();
    expect(headerName(tester), 'Lv1 山田花子');
  });

  testWidgets('the Discord ID keeps only digits and is stored', (tester) async {
    final container = await openOverlay(tester);

    await tester.tap(find.byKey(const ValueKey('profileDiscordIdRow')));
    await tester.pumpAndSettle();
    // The formatter drops everything but the digits as it is typed.
    await tester.enterText(
      find.byKey(const ValueKey('discordUserIdField')),
      '<@123456789>',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(container.read(profileProvider).discordUserId, '123456789');
    expect(find.text('123456789'), findsOneWidget);
  });

  testWidgets('メール送信設定 says 未設定 and opens the SMTP editor', (tester) async {
    await openOverlay(tester);

    await scrollTo(tester, find.byKey(const ValueKey('profileMailRow')));
    expect(find.text('メール送信設定'), findsOneWidget);
    // Nothing has been entered, and a half-filled account is 未設定 to every
    // other screen — this row must not be the one place that calls it done.
    expect(find.text('未設定'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('profileMailRow')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mailPreset-gmail')), findsOneWidget);
    expect(find.byKey(const ValueKey('mailHostField')), findsOneWidget);
  });

  testWidgets('picking an icon persists and repaints the header', (
    tester,
  ) async {
    final container = await openOverlay(tester);
    final sun = ProfileCatalog.icons[1];
    expect(sun.id, 'sun');

    await scrollTo(tester, find.byKey(ValueKey('collectionIcon-${sun.id}')));
    await tester.tap(find.byKey(ValueKey('collectionIcon-${sun.id}')));
    await tester.pumpAndSettle();

    expect(container.read(profileProvider).iconId, sun.id);
    // Read back off storage through a repository of its own: what the header
    // shows has to be what the next launch would find.
    final reread = ProfileRepository(
      container.read(sharedPreferencesProvider),
    ).read();
    expect(reread.iconId, sun.id);

    await tester.tap(find.byKey(const ValueKey('profileOverlayClose')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('appHeaderAvatar')),
        matching: find.text(sun.emoji),
      ),
      findsOneWidget,
    );
  });

  testWidgets('picking a plate and a frame persists too', (tester) async {
    final container = await openOverlay(tester);

    await scrollTo(
      tester,
      find.byKey(const ValueKey('collectionPlate-plate_dawn')),
    );
    await tester.tap(find.byKey(const ValueKey('collectionPlate-plate_dawn')));
    await tester.pumpAndSettle();

    await scrollTo(
      tester,
      find.byKey(const ValueKey('collectionFrame-frame_thick')),
    );
    await tester.tap(find.byKey(const ValueKey('collectionFrame-frame_thick')));
    await tester.pumpAndSettle();

    final profile = container.read(profileProvider);
    expect(profile.plateBackgroundId, 'plate_dawn');
    expect(profile.frameId, 'frame_thick');
  });

  testWidgets('an unowned cosmetic cannot be picked', (tester) async {
    // Only the default icon granted: the pickers read the owned set, so the
    // day something has to be earned this is already the behaviour.
    final container = await openOverlay(
      tester,
      prefs: {
        'profile.ownedIconIds': [ProfileCatalog.defaultIconId],
      },
    );

    await scrollTo(tester, find.byKey(const ValueKey('collectionIcon-sun')));
    await tester.tap(find.byKey(const ValueKey('collectionIcon-sun')));
    await tester.pumpAndSettle();

    expect(
      container.read(profileProvider).iconId,
      ProfileCatalog.defaultIconId,
    );
  });
}
