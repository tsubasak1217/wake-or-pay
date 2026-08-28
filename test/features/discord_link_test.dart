import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/app/profile_controller.dart';
import 'package:wake_or_pay/main.dart';

import '../helpers.dart';

const _identityUrl = 'https://discord.com/api/users/@me';
const _identityBody =
    '{"id":"123456789012345678","username":"hanako",'
    '"global_name":"花子","avatar":"abc"}';

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

void main() {
  testWidgets('連携 fills in the ID and shows the name it belongs to', (
    tester,
  ) async {
    final authorizer = FakeOAuthAuthorizer(
      (url) => 'wakeorpay://discord/callback'
          '#access_token=TOK&state=${stateOf(url)}',
    );
    final container = await openOverlay(
      tester,
      extra: [
        fakeHttpClientOverride(
          FakeHttpClient(responses: {_identityUrl: _identityBody}),
        ),
        fakeOAuthAuthorizerOverride(authorizer),
      ],
    );

    await scrollTo(tester, find.byKey(const ValueKey('profileDiscordLinkRow')));
    await tester.tap(find.byKey(const ValueKey('profileDiscordLinkRow')));
    await tester.pumpAndSettle();

    expect(container.read(profileProvider).discordUserId, '123456789012345678');
    expect(container.read(profileProvider).discordUsername, '花子');
    expect(find.text('連携済み：@花子'), findsOneWidget);
    // The row above is filled in by the same act — that is the whole point of
    // the button, since typing it needs Discord's developer mode first.
    expect(find.text('123456789012345678'), findsOneWidget);
    // The overlay is a Scaffold over the tab's, and a ScaffoldMessenger
    // paints its SnackBar into every Scaffold registered with it — so this is
    // one message on two layers, not two messages.
    expect(find.text('連携しました'), findsWidgets);
    expect(authorizer.opened, hasLength(1));
  });

  testWidgets('a state mismatch changes nothing and says so', (tester) async {
    final http = FakeHttpClient(responses: {_identityUrl: _identityBody});
    final container = await openOverlay(
      tester,
      extra: [
        fakeHttpClientOverride(http),
        fakeOAuthAuthorizerOverride(
          FakeOAuthAuthorizer(
            (_) => 'wakeorpay://discord/callback'
                '#access_token=TOK&state=not-the-one',
          ),
        ),
      ],
    );

    await scrollTo(tester, find.byKey(const ValueKey('profileDiscordLinkRow')));
    await tester.tap(find.byKey(const ValueKey('profileDiscordLinkRow')));
    await tester.pumpAndSettle();

    expect(container.read(profileProvider).discordUserId, isEmpty);
    expect(container.read(profileProvider).discordUsername, isEmpty);
    expect(http.requested, isEmpty);
    expect(find.text('確認に失敗しました。アプリからもう一度お試しください'), findsWidgets);
    expect(find.byKey(const ValueKey('profileDiscordLinkRow')), findsOneWidget);
  });

  testWidgets('cancelling leaves the row exactly as it was', (tester) async {
    final container = await openOverlay(
      tester,
      extra: [
        fakeHttpClientOverride(FakeHttpClient()),
        fakeOAuthAuthorizerOverride(FakeOAuthAuthorizer.cancelled()),
      ],
    );

    await scrollTo(tester, find.byKey(const ValueKey('profileDiscordLinkRow')));
    await tester.tap(find.byKey(const ValueKey('profileDiscordLinkRow')));
    await tester.pumpAndSettle();

    expect(container.read(profileProvider).discordLinked, isFalse);
    expect(find.text('連携をやめました'), findsWidgets);
  });

  testWidgets('連携を解除 clears the ID as well as the name', (tester) async {
    final container = await openOverlay(
      tester,
      prefs: {
        'profile.discordUserId': '123456789012345678',
        'profile.discordUsername': '花子',
      },
    );

    await scrollTo(
      tester,
      find.byKey(const ValueKey('profileDiscordLinkedRow')),
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

  testWidgets('typing a different ID by hand drops the linked name', (
    tester,
  ) async {
    final container = await testContainer(
      prefs: {
        'profile.discordUserId': '111',
        'profile.discordUsername': '花子',
      },
    );
    final controller = container.read(profileProvider.notifier);

    await controller.setDiscordUserId('222');
    expect(container.read(profileProvider).discordUsername, isEmpty);
    expect(container.read(profileProvider).discordLinked, isFalse);
  });

  testWidgets('re-typing the same ID keeps the link intact', (tester) async {
    final container = await testContainer(
      prefs: {
        'profile.discordUserId': '111',
        'profile.discordUsername': '花子',
      },
    );
    await container.read(profileProvider.notifier).setDiscordUserId('<@111>');
    expect(container.read(profileProvider).discordUsername, '花子');
  });
}
