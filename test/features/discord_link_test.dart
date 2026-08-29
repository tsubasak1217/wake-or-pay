import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/app/profile_controller.dart';
import 'package:wake_or_pay/features/widgets/discord_icon.dart';
import 'package:wake_or_pay/main.dart';
import 'package:wake_or_pay/services/discord_exchange.dart';
import 'package:wake_or_pay/services/discord_oauth.dart';

import '../helpers.dart';

const _exchangeUrl = '$kDiscordExchangeEndpoint/discord/exchange';
const _identityBody =
    '{"user":{"id":"123456789012345678","username":"hanako",'
    '"global_name":"花子","avatar":"abc"}}';

/// The overlay is taller than a test viewport.
Future<void> scrollTo(WidgetTester tester, Finder target) async {
  final list = find
      .descendant(
        of: find.byKey(const ValueKey('profileOverlay')),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(target, 120, scrollable: list);
  await tester.pumpAndSettle();
}

Future<ProviderContainer> openOverlay(
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
  await tester.tap(find.byKey(const ValueKey('appHeaderAvatar')));
  await tester.pumpAndSettle();
  return container;
}

/// 連携情報 is an index now: the row says 未連携 or 連携済み and nothing else, and
/// every button this file presses lives one tap further in, on
/// [DiscordLinkScreen].
Future<ProviderContainer> openDiscordScreen(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  List<Override> extra = const [],
}) async {
  final container = await openOverlay(tester, prefs: prefs, extra: extra);
  final row = find.byKey(const ValueKey('profileDiscordRow'));
  await scrollTo(tester, row);
  await tester.tap(row);
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets(
    '連携 waits in the browser, then fills in the name it belongs to',
    (tester) async {
      final links = FakeDeepLinks();
      addTearDown(links.dispose);
      final http = FakeHttpClient(postStatus: 200, postBody: _identityBody);
      // No replyWith: the callback is emitted by hand below, only after the
      // waiting state has been asserted on — a replyWith would race the
      // emit against that assertion inside the same pump().
      final launcher = FakeDiscordAuthLauncher(links);
      final container = await openDiscordScreen(
        tester,
        extra: [
          fakeHttpClientOverride(http),
          ...fakeDiscordFlowOverrides(links, launcher),
        ],
      );

      await tester.tap(find.byKey(const ValueKey('profileDiscordLinkRow')));
      // One pump is enough to run the synchronous part of link() (which sets
      // 「開いています」) and let the fake launcher's open() resolve (which sets
      // 「承認を待っています」) — nothing else advances until the deep link
      // arrives, because nothing schedules it yet.
      await tester.pump();

      expect(find.text(kDiscordWaitingInBrowserMessage), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Disabled while busy: a second tap must not start a second flow.
      expect(
        tester
            .widget<ListTile>(
              find.byKey(const ValueKey('profileDiscordLinkRow')),
            )
            .onTap,
        isNull,
      );

      links.emit(
        'wakeorpay://discord/callback'
        '?code=CODE&state=${stateOf(launcher.opened.single)}',
      );
      await tester.pumpAndSettle();

      expect(
        container.read(profileProvider).discordUserId,
        '123456789012345678',
      );
      expect(container.read(profileProvider).discordUsername, '花子');
      // Two widgets say it now: the linked-row ListTile and the flow status
      // line both land on the same sentence once the flow finishes.
      expect(find.text('連携済み：@花子'), findsNWidgets(2));
      expect(launcher.opened, hasLength(1));
      // The code was spent at the 連携サーバー, never at Discord directly.
      expect(http.posted.single.url, _exchangeUrl);
    },
  );

  testWidgets('a state mismatch changes nothing and says so', (tester) async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final http = FakeHttpClient(postStatus: 200, postBody: _identityBody);
    final launcher = FakeDiscordAuthLauncher(
      links,
      replyWith: (_) => 'wakeorpay://discord/callback'
          '?code=CODE&state=not-the-one',
    );
    final container = await openDiscordScreen(
      tester,
      extra: [
        fakeHttpClientOverride(http),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('profileDiscordLinkRow')));
    await tester.pumpAndSettle();

    expect(container.read(profileProvider).discordUserId, isEmpty);
    expect(container.read(profileProvider).discordUsername, isEmpty);
    expect(http.posted, isEmpty);
    expect(find.text('確認に失敗しました。アプリからもう一度お試しください'), findsOneWidget);
    expect(find.byKey(const ValueKey('profileDiscordLinkRow')), findsOneWidget);
  });

  testWidgets('やめる leaves the row exactly as it was', (tester) async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    // No replyWith: the flow sits in 承認待ち until the test cancels it.
    final launcher = FakeDiscordAuthLauncher(links);
    final container = await openDiscordScreen(
      tester,
      extra: [
        fakeHttpClientOverride(FakeHttpClient()),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('profileDiscordLinkRow')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('discordFlowCancel')));
    await tester.pumpAndSettle();

    expect(container.read(profileProvider).discordLinked, isFalse);
    expect(find.text('連携をやめました'), findsOneWidget);
  });

  testWidgets('no browser says so, and nothing is opened', (
    tester,
  ) async {
    final links = FakeDeepLinks();
    addTearDown(links.dispose);
    final launcher = FakeDiscordAuthLauncher.noApp(links);
    final container = await openDiscordScreen(
      tester,
      extra: [
        fakeHttpClientOverride(FakeHttpClient()),
        ...fakeDiscordFlowOverrides(links, launcher),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('profileDiscordLinkRow')));
    await tester.pumpAndSettle();

    expect(container.read(profileProvider).discordLinked, isFalse);
    expect(find.text('ブラウザが見つかりませんでした'), findsOneWidget);
  });

  testWidgets('連携を解除 clears the ID as well as the name', (tester) async {
    final container = await openDiscordScreen(
      tester,
      prefs: {
        'profile.discordUserId': '123456789012345678',
        'profile.discordUsername': '花子',
      },
    );

    expect(find.text('連携済み：@花子'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profileDiscordUnlink')));
    await tester.pumpAndSettle();

    // Leaving the ID behind would keep mentioning an account the user just
    // said to forget.
    expect(container.read(profileProvider).discordUserId, isEmpty);
    expect(container.read(profileProvider).discordUsername, isEmpty);
    expect(find.byKey(const ValueKey('profileDiscordLinkRow')), findsOneWidget);
  });

  testWidgets('both Discord rows are marked with the Discord mark', (
    tester,
  ) async {
    await openOverlay(tester);

    // The index row in 連携情報…
    final indexRow = find.byKey(const ValueKey('profileDiscordRow'));
    await scrollTo(tester, indexRow);
    expect(
      find.descendant(of: indexRow, matching: find.byType(DiscordIcon)),
      findsOneWidget,
    );

    // …and the row behind it, on the screen that does the linking.
    await tester.tap(indexRow);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('profileDiscordLinkRow')),
        matching: find.byType(DiscordIcon),
      ),
      findsOneWidget,
    );
  });

  testWidgets('連携情報 shows the state and nothing else', (tester) async {
    await openOverlay(tester);
    await scrollTo(tester, find.byKey(const ValueKey('profileLinksIsland')));

    final island = find.byKey(const ValueKey('profileLinksIsland'));
    expect(
      find.descendant(of: island, matching: find.text('未連携')),
      findsNWidgets(3),
      reason: 'Discord, カード, メール — all three unlinked',
    );
    // The island is an index: none of the doing happens in it.
    for (final gone in const [
      '連携を解除',
      'Discord で連携',
      'メール送信設定',
      '寝坊で確定した金額を、あなたのカードに請求できるようにします。',
    ]) {
      expect(
        find.descendant(of: island, matching: find.text(gone)),
        findsNothing,
        reason: gone,
      );
    }
  });

  testWidgets('a linked account turns the index row 連携済み', (tester) async {
    await openOverlay(
      tester,
      prefs: {
        'profile.discordUserId': '123456789012345678',
        'profile.discordUsername': '花子',
      },
    );

    final row = find.byKey(const ValueKey('profileDiscordRow'));
    await scrollTo(tester, row);
    expect(
      find.descendant(of: row, matching: find.text('連携済み')),
      findsOneWidget,
    );
    // The name belongs to the screen behind it, not to the index.
    expect(
      find.descendant(of: row, matching: find.text('連携済み：@花子')),
      findsNothing,
    );
  });

  testWidgets('linking over an existing link replaces both id and name', (
    tester,
  ) async {
    final container = await testContainer(
      prefs: {
        'profile.discordUserId': '111',
        'profile.discordUsername': '花子',
      },
    );

    await container
        .read(profileProvider.notifier)
        .linkDiscordAccount(id: '<@222>', username: '太郎', avatar: 'xyz');

    final profile = container.read(profileProvider);
    // The mention wrapper is stripped on the way in, so what is stored is
    // always something a webhook can actually use.
    expect(profile.discordUserId, '222');
    expect(profile.discordUsername, '太郎');
    expect(profile.discordLinked, isTrue);
  });

  // The following used to live here and are gone with the screens behind
  // them (段階F):
  // - 「連携サーバーURL is on the overlay and takes a pasted Worker URL」 and
  //   「an http:// endpoint is refused at the field」 tested
  //   profileDiscordEndpointRow / discordEndpointField, which no longer
  //   exist — the endpoint is a build-time constant now
  //   (kDiscordExchangeEndpoint), covered by pure-function tests in
  //   discord_exchange_test.dart instead of any UI.
  // - 「typing a different ID by hand drops the linked name」 and
  //   「re-typing the same ID keeps the link intact」 tested
  //   ProfileController.setDiscordUserId, which is gone with the hand-typed
  //   ID screen. There is no longer any way to put an ID in that did not come
  //   from an authorised account, so there is nothing left for those rules to
  //   protect against.
  //
  // 段階G (この https リダイレクトへの切り替え) removed the ability to reach the
  // Discord app directly for the authorize step — see
  // UrlLauncherDiscordAuthLauncher — so 「連携 waits in the Discord app」 above
  // is now 「連携 waits in the browser」, and every callback below carries
  // ?code=… in the query rather than #access_token=… in the fragment.
}
