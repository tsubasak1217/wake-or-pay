import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/app/profile_controller.dart';
import 'package:wake_or_pay/app/usage_controller.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/data/repositories/profile_repository.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/domain/profile_catalog.dart';
import 'package:wake_or_pay/domain/title_catalog.dart';
import 'package:wake_or_pay/features/profile/profile_edit_screen.dart';
import 'package:wake_or_pay/main.dart';

import '../helpers.dart';

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  List<Override> extra = const [],
}) async {
  final container = await testContainer(
    prefs: prefs,
    extra: [fakeAlarmServiceOverride(), ...extra],
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
  List<Override> extra = const [],
}) async {
  final container = await pumpApp(tester, prefs: prefs, extra: extra);
  await tester.tap(find.byKey(const ValueKey('appHeaderAvatar')));
  await tester.pumpAndSettle();
  return container;
}

String headerName(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('appHeaderName'))).data!;

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

/// The overlay is taller than a test viewport, so anything below the fold has
/// to be scrolled into the list before it can be seen.
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

/// The editor's panel scrolls on its own; the preview above it does not move.
Finder get editorPanelScrollable => find.descendant(
  of: find.byKey(const ValueKey('editPanel')),
  matching: find.byType(Scrollable),
);

/// Opens one category drawer and taps one item in it. Everything in the editor
/// is two taps now: the chip, then the tile.
Future<void> pickInEditor(
  WidgetTester tester,
  String category,
  String itemKey,
) async {
  await tester.tap(find.byKey(ValueKey('editCategory-$category')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(itemKey)));
  await tester.pumpAndSettle();
}

/// The name lives on the plate: tapping it opens 「名前を変更」.
Future<void> renameInEditor(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('editNameplate')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('profileEditName')), name);
  await tester.tap(find.byKey(const ValueKey('profileEditNameOk')));
  await tester.pumpAndSettle();
}

/// Scrolls one 「これまでの歩み」 row into view and checks what it says.
Future<void> expectJourney(
  WidgetTester tester,
  String rowKey,
  String value,
) async {
  final row = find.byKey(ValueKey(rowKey));
  await scrollTo(tester, row);
  expect(
    find.descendant(of: row, matching: find.text(value)),
    findsOneWidget,
    reason: rowKey,
  );
}

AlarmSession ring({
  required String id,
  required DateTime firedAt,
  DateTime? dismissedAt,
  SessionStatus status = SessionStatus.success,
  int loss = 0,
}) => AlarmSession(
  id: id,
  alarmId: 'a1',
  firedAt: firedAt,
  dismissedAt: dismissedAt,
  status: status,
  loss: loss,
);

void main() {
  testWidgets('the launch itself is what counts a login day', (tester) async {
    // Recorded by the root widget, before anything is tapped and without the
    // profile ever being opened — see [UsageTracker].
    final container = await pumpApp(tester);

    expect(container.read(usageProvider).loginDays, 1);
    expect(container.read(usageProvider).firstOpenedAt, testNow);

    // And only once: `initState` does not run again on a rebuild.
    await tester.tap(find.byKey(const ValueKey('appHeaderAvatar')));
    await tester.pumpAndSettle();
    expect(container.read(usageProvider).loginDays, 1);
    expect(
      container.read(usageRepositoryProvider).read().loginDays,
      1,
      reason: 'the next launch has to find it',
    );
  });

  testWidgets('the avatar opens the overlay and 閉じる closes it', (
    tester,
  ) async {
    await openOverlay(tester);

    expect(find.byKey(const ValueKey('profileOverlay')), findsOneWidget);
    // アイコン → 称号 → ネームプレート → ゲージ, top to bottom.
    expect(find.byKey(const ValueKey('profileAvatar')), findsOneWidget);
    expect(find.byKey(const ValueKey('profileTitle')), findsOneWidget);
    expect(find.byKey(const ValueKey('profileNamePlate')), findsOneWidget);
    expect(find.byKey(const ValueKey('profileGauge')), findsOneWidget);
    expect(find.byKey(const ValueKey('profileEditButton')), findsOneWidget);

    await scrollTo(tester, find.byKey(const ValueKey('profileJourneyIsland')));
    expect(find.text('これまでの歩み'), findsOneWidget);
    await scrollTo(tester, find.byKey(const ValueKey('profileLinksIsland')));
    expect(find.text('連携情報'), findsOneWidget);

    // The islands this batch retired.
    expect(find.text('コレクション'), findsNothing);
    expect(find.text('プロフィール設定'), findsNothing);
    expect(
      find.byKey(const ValueKey('profileActivityPlaceholder')),
      findsNothing,
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

  testWidgets('the 称号 defaults to 寝坊の常習犯', (tester) async {
    await openOverlay(tester);
    expect(textOf(tester, 'profileTitle'), '寝坊の常習犯');
  });

  testWidgets('the rank is drawn inside the XP gauge', (tester) async {
    final container = await pumpApp(tester);
    await container.read(profileProvider.notifier).addXp(60);
    await tester.tap(find.byKey(const ValueKey('appHeaderAvatar')));
    await tester.pumpAndSettle();

    // 60 XP is level 2 (50) with 90 still owed on the 150 boundary.
    final gauge = find.byKey(const ValueKey('profileGauge'));
    expect(
      find.descendant(of: gauge, matching: find.text('Lv 2')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: gauge, matching: find.byType(LinearProgressIndicator)),
      findsOneWidget,
    );
    expect(find.text('経験値 60 / 次のLvまで 90'), findsOneWidget);
  });

  testWidgets('これまでの歩み counts the whole history', (tester) async {
    final container = await pumpApp(tester);
    final sessions = container.read(alarmSessionRepositoryProvider);
    // Two 起床成功 and two 寝坊 — 90 min / 1200 and 20 min / 300 — plus one
    // still ringing, which has no outcome and must count towards nothing.
    await sessions.save(
      ring(
        id: 's1',
        firedAt: DateTime(2026, 8, 1, 7),
        dismissedAt: DateTime(2026, 8, 1, 7, 1),
      ),
    );
    await sessions.save(
      ring(
        id: 's2',
        firedAt: DateTime(2026, 8, 2, 7),
        dismissedAt: DateTime(2026, 8, 2, 7, 1),
      ),
    );
    await sessions.save(
      ring(
        id: 's3',
        firedAt: DateTime(2026, 8, 4, 7),
        dismissedAt: DateTime(2026, 8, 4, 8, 30),
        status: SessionStatus.failed,
        loss: 1200,
      ),
    );
    await sessions.save(
      ring(
        id: 's4',
        firedAt: DateTime(2026, 8, 5, 7),
        dismissedAt: DateTime(2026, 8, 5, 7, 20),
        status: SessionStatus.failed,
        loss: 300,
      ),
    );
    await sessions.save(
      ring(
        id: 's5',
        firedAt: DateTime(2026, 8, 6, 7),
        status: SessionStatus.ringing,
        loss: 9999,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('appHeaderAvatar')));
    await tester.pumpAndSettle();

    // 開始日 is the launch this container recorded, not the oldest ring.
    await expectJourney(tester, 'journeyStartedAt', '2026/8/29');
    await expectJourney(tester, 'journeyLoginDays', '1日');
    await expectJourney(tester, 'journeyTotalPenalty', '1,500 コイン');
    await expectJourney(tester, 'journeyMaxPenalty', '1,200 コイン');
    await expectJourney(tester, 'journeySuccessRate', '50%');
    await expectJourney(tester, 'journeyOversleepCount', '2回');
    await expectJourney(tester, 'journeyTotalOversleep', '1h 50分');
    await expectJourney(tester, 'journeyMaxOversleep', '1h 30分');

    final total =
        ProfileCatalog.icons.length +
        ProfileCatalog.plateBackgrounds.length +
        ProfileCatalog.frames.length +
        ProfileCatalog.backgrounds.length +
        TitleCatalog.wordCount;
    await expectJourney(tester, 'journeyCollections', '$total / $total');
  });

  testWidgets('これまでの歩み says 「—」 before anything has happened', (
    tester,
  ) async {
    await openOverlay(tester);

    // A rate over no rings is 「—」, not 0%.
    await expectJourney(tester, 'journeySuccessRate', '—');
    await expectJourney(tester, 'journeyOversleepCount', '0回');
    await expectJourney(tester, 'journeyTotalOversleep', '0分');
    await expectJourney(tester, 'journeyTotalPenalty', '0 コイン');
  });

  testWidgets('連携情報 holds Discord, the card and mail — and no name row', (
    tester,
  ) async {
    await openOverlay(tester);

    await scrollTo(tester, find.byKey(const ValueKey('profileLinksIsland')));
    expect(find.byKey(const ValueKey('profileDiscordLinkRow')), findsOneWidget);
    await scrollTo(tester, find.byKey(const ValueKey('profileCardHostageRow')));
    expect(find.byKey(const ValueKey('profileCardHostageRow')), findsOneWidget);
    await scrollTo(tester, find.byKey(const ValueKey('profileMailRow')));
    expect(find.byKey(const ValueKey('profileMailRow')), findsOneWidget);

    // The name is edited where it is previewed, so the row that used to open a
    // screen of its own is gone.
    expect(find.byKey(const ValueKey('profileUserNameRow')), findsNothing);
    expect(find.text('あなたの名前'), findsNothing);
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
    expect(find.byKey(const ValueKey('mailFromField')), findsOneWidget);
    expect(find.byKey(const ValueKey('mailPasswordField')), findsOneWidget);
  });

  testWidgets(
    'the pencil opens the editor; what is picked there is previewed, then '
    'kept and persisted',
    (tester) async {
      final container = await openOverlay(tester);

      await tester.tap(find.byKey(const ValueKey('profileEditButton')));
      await tester.pumpAndSettle();
      // The sketch has no name field: the plate is the field.
      expect(find.byKey(const ValueKey('profileEditName')), findsNothing);
      expect(find.byKey(const ValueKey('editNameplate')), findsOneWidget);
      expect(find.byKey(const ValueKey('editPanel')), findsOneWidget);

      await renameInEditor(tester, ' 山田花子 ');

      for (final pick in const [
        ('icon', 'collectionIcon-sun'),
        ('frame', 'collectionFrame-frame_thick'),
        ('plate', 'collectionPlate-plate_dawn'),
        ('background', 'collectionBackground-bg_night'),
        ('titleA', 'titlePrefix-p_hayaoki'),
        ('titleB', 'titleConnector-c_taru'),
        ('titleC', 'titleSuffix-s_ou'),
      ]) {
        await pickInEditor(tester, pick.$1, pick.$2);
      }

      // Nothing is committed yet: the draft lives in the screen, and only the
      // preview at the top of it has moved.
      expect(
        container.read(profileProvider).iconId,
        ProfileCatalog.defaultIconId,
      );
      expect(textOf(tester, 'profileEditTitle'), '早起きたる王');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profileEditNamePlate')),
          matching: find.text('山田花子'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profileEditAvatar')),
          matching: find.text('🌞'),
        ),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();

      final profile = container.read(profileProvider);
      expect(profile.userName, '山田花子', reason: 'stored trimmed');
      expect(profile.iconId, 'sun');
      expect(profile.frameId, 'frame_thick');
      expect(profile.plateBackgroundId, 'plate_dawn');
      expect(profile.backgroundId, 'bg_night');
      expect(profile.title, '早起きたる王');

      // Back on the overlay, painted from the stored profile.
      expect(textOf(tester, 'profileTitle'), '早起きたる王');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profileNamePlate')),
          matching: find.text('山田花子'),
        ),
        findsOneWidget,
      );

      // Read back off storage through a repository of its own: what the header
      // shows has to be what the next launch would find.
      final reread = ProfileRepository(
        container.read(sharedPreferencesProvider),
      ).read();
      expect(reread.userName, '山田花子');
      expect(reread.iconId, 'sun');
      expect(reread.frameId, 'frame_thick');
      expect(reread.plateBackgroundId, 'plate_dawn');
      expect(reread.backgroundId, 'bg_night');
      expect(reread.title, '早起きたる王');

      await tester.tap(find.byKey(const ValueKey('profileOverlayClose')));
      await tester.pumpAndSettle();
      expect(headerName(tester), 'Lv1 山田花子');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('appHeaderAvatar')),
          matching: find.text('🌞'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('an unowned cosmetic cannot be picked', (tester) async {
    // Only the default icon and the three default title words granted: the
    // pickers read the owned sets, so the day something has to be earned this
    // is already the behaviour.
    final container = await openOverlay(
      tester,
      prefs: {
        'profile.ownedIconIds': [ProfileCatalog.defaultIconId],
        'profile.ownedTitleWordIds': [
          TitleCatalog.defaultPrefixId,
          TitleCatalog.defaultConnectorId,
          TitleCatalog.defaultSuffixId,
        ],
      },
    );

    await tester.tap(find.byKey(const ValueKey('profileEditButton')));
    await tester.pumpAndSettle();

    // Both are on the screen and both refuse: unowned greys out, it does not
    // disappear from the drawer.
    await pickInEditor(tester, 'icon', 'collectionIcon-sun');
    await pickInEditor(tester, 'titleA', 'titlePrefix-p_hayaoki');

    await tester.pageBack();
    await tester.pumpAndSettle();

    final profile = container.read(profileProvider);
    expect(profile.iconId, ProfileCatalog.defaultIconId);
    expect(profile.title, '寝坊の常習犯');
  });

  testWidgets('an unowned 背景 cannot be picked either', (tester) async {
    final container = await openOverlay(
      tester,
      prefs: {
        'profile.ownedBackgroundIds': [ProfileCatalog.defaultBackgroundId],
      },
    );

    await tester.tap(find.byKey(const ValueKey('profileEditButton')));
    await tester.pumpAndSettle();
    await pickInEditor(tester, 'background', 'collectionBackground-bg_dawn');
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(
      container.read(profileProvider).backgroundId,
      ProfileCatalog.defaultBackgroundId,
    );
  });

  testWidgets('the category chips swap what the panel is showing', (
    tester,
  ) async {
    await openOverlay(tester);
    await tester.tap(find.byKey(const ValueKey('profileEditButton')));
    await tester.pumpAndSettle();

    // アイコン is the drawer that opens first.
    expect(find.byKey(const ValueKey('collectionIcon-sun')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('collectionBackground-bg_night')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('editCategory-background')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('collectionBackground-bg_night')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('collectionIcon-sun')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('editCategory-titleC')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('titleSuffix-s_ou')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('collectionBackground-bg_night')),
      findsNothing,
    );
  });

  testWidgets('the panel scrolls under a preview that does not move', (
    tester,
  ) async {
    await openOverlay(tester);
    await tester.tap(find.byKey(const ValueKey('profileEditButton')));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileEditScreen), findsOneWidget);
    expect(editorPanelScrollable, findsOneWidget);

    final before = tester.getTopLeft(
      find.byKey(const ValueKey('profileEditAvatar')),
    );
    await tester.drag(editorPanelScrollable, const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('profileEditAvatar'))),
      before,
      reason: 'the preview is outside the panel’s scroll',
    );
  });

  testWidgets('the head stays put while the rest of the sheet scrolls', (
    tester,
  ) async {
    // A window short enough that 歩み and 連携情報 cannot both fit: the head has
    // to survive scrolling the list all the way down.
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await openOverlay(tester);

    final head = find.byKey(const ValueKey('profileAvatar'));
    final before = tester.getTopLeft(head);

    final list = find
        .descendant(
          of: find.byKey(const ValueKey('profileOverlay')),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(list).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();

    expect(position.pixels, greaterThan(0), reason: 'there was room to scroll');
    expect(head, findsOneWidget);
    expect(
      tester.getTopLeft(head),
      before,
      reason: 'the head is the sheet’s header, not its first row',
    );
    // And the bottom of the list really is on screen.
    expect(find.byKey(const ValueKey('profileMailRow')), findsOneWidget);
  });
}
