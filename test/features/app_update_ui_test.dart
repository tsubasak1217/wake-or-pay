import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/main.dart';
import 'package:wake_or_pay/services/app_update.dart';

import '../helpers.dart';

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  UpdateSource? source,
  ApkDownloader? downloader,
  ApkInstaller? installer,
  AppVersionInfo? version,
}) async {
  final container = await testContainer(
    extra: [fakeAlarmServiceOverride()],
    updateSource: source,
    updateDownloader: downloader,
    updateInstaller: installer,
    updateVersion: version,
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

/// The home banner only appears after a check has found something. Widget
/// tests never run `main()`, so the check is driven by hand.
Future<ProviderContainer> pumpHomeWithUpdate(
  WidgetTester tester, {
  int build = 42,
  ApkDownloader? downloader,
  ApkInstaller? installer,
}) async {
  final container = await pumpApp(
    tester,
    source: FakeUpdateSource(manifest: updateManifest(build: build)),
    downloader: downloader,
    installer: installer,
    version: FakeAppVersionInfo(build: 10, versionName: '1.0.0'),
  );
  await container.read(appUpdateProvider.notifier).check();
  await tester.pumpAndSettle();
  return container;
}

/// The overlay is taller than a test viewport; the update row is at the bottom
/// of プロフィール設定.
Future<void> scrollTo(WidgetTester tester, Finder target) async {
  final list = find
      .descendant(
        of: find.byKey(const ValueKey('profileOverlay')),
        matching: find.byType(Scrollable),
      )
      .first;
  // From the top, and settled first: scrollUntilVisible walks the tree on
  // every step, and it cannot do that while the overlay is still sliding in.
  tester.state<ScrollableState>(list).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(target, 120, scrollable: list);
  await tester.pumpAndSettle();
}

void main() {
  group('home banner', () {
    testWidgets('nothing is drawn when there is no newer build', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(find.byKey(const ValueKey('updateBanner')), findsNothing);
    });

    testWidgets('an available update puts the banner on the home screen', (
      tester,
    ) async {
      await pumpHomeWithUpdate(tester, build: 42);

      expect(find.byKey(const ValueKey('updateBanner')), findsOneWidget);
      expect(find.text('新しいバージョン（build 42）があります'), findsOneWidget);
      expect(find.byKey(const ValueKey('updateInstall')), findsOneWidget);
    });

    testWidgets('更新 starts the download and shows the progress bar', (
      tester,
    ) async {
      final downloader = PausingApkDownloader(
        path: '/updates/WakeOrPay-42.apk',
      );
      final installer = FakeApkInstaller();
      await pumpHomeWithUpdate(
        tester,
        downloader: downloader,
        installer: installer,
      );

      await tester.tap(find.byKey(const ValueKey('updateInstall')));
      await tester.pump();

      // Mid-download: the bar is on screen at 40% and nothing is installed.
      expect(find.byKey(const ValueKey('updateProgress')), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byKey(const ValueKey('updateProgress')),
            )
            .value,
        closeTo(0.4, 0.001),
      );
      expect(find.text('40%'), findsOneWidget);
      expect(downloader.requested.single.build, 42);
      expect(installer.opened, isEmpty);

      downloader.finish();
      await tester.pumpAndSettle();

      expect(installer.opened, ['/updates/WakeOrPay-42.apk']);
      expect(find.byKey(const ValueKey('updateProgress')), findsNothing);
    });

    testWidgets('an installer that will not open shows the message', (
      tester,
    ) async {
      await pumpHomeWithUpdate(tester, installer: FakeApkInstaller(succeeds: false));

      await tester.tap(find.byKey(const ValueKey('updateInstall')));
      await tester.pumpAndSettle();

      final error = find.byKey(const ValueKey('updateError'));
      expect(error, findsOneWidget);
      expect(
        tester.widget<Text>(error).data,
        contains('不明なアプリのインストール'),
      );
    });

    testWidgets('あとで hides the banner', (tester) async {
      await pumpHomeWithUpdate(tester);

      await tester.tap(find.byKey(const ValueKey('updateLater')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('updateBanner')), findsNothing);
    });
  });

  group('profile row', () {
    Future<ProviderContainer> openOverlay(
      WidgetTester tester, {
      UpdateSource? source,
      AppVersionInfo? version,
    }) async {
      final container = await pumpApp(
        tester,
        source: source,
        version: version ?? FakeAppVersionInfo(build: 10, versionName: '1.0.0'),
      );
      await tester.tap(find.byKey(const ValueKey('appHeaderAvatar')));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const ValueKey('profileUpdateRow')));
      return container;
    }

    testWidgets('shows the running version and 未確認 before any check', (
      tester,
    ) async {
      await openOverlay(tester);

      expect(find.byKey(const ValueKey('profileUpdateRow')), findsOneWidget);
      expect(find.text('アプリの更新'), findsOneWidget);
      expect(find.text('1.0.0 (build 10)'), findsOneWidget);
      expect(find.text('未確認'), findsOneWidget);
    });

    testWidgets('a tap that finds nothing leaves the row saying 最新です', (
      tester,
    ) async {
      await openOverlay(tester, source: FakeUpdateSource());

      await tester.tap(find.byKey(const ValueKey('profileUpdateRow')));
      await tester.pumpAndSettle();

      // The dialog opened and says so, and the row behind it agrees.
      expect(find.byKey(const ValueKey('updateDialog')), findsOneWidget);
      expect(find.text('最新です'), findsNWidgets(2));
    });

    testWidgets('a tap that finds a build offers it, and 更新 installs', (
      tester,
    ) async {
      final container = await openOverlay(
        tester,
        source: FakeUpdateSource(manifest: updateManifest(build: 42)),
      );

      await tester.tap(find.byKey(const ValueKey('profileUpdateRow')));
      await tester.pumpAndSettle();

      expect(find.text('build 42 が利用できます'), findsOneWidget);
      expect(find.byKey(const ValueKey('updateDialogInstall')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('updateDialogInstall')));
      await tester.pumpAndSettle();

      final installer = container.read(apkInstallerProvider) as FakeApkInstaller;
      expect(installer.opened, isNotEmpty);
    });

    testWidgets('the wording sells nothing', (tester) async {
      await openOverlay(
        tester,
        source: FakeUpdateSource(manifest: updateManifest(build: 42)),
      );
      await tester.tap(find.byKey(const ValueKey('profileUpdateRow')));
      await tester.pumpAndSettle();

      for (final word in ['課金', '購入', '広告']) {
        expect(find.textContaining(word), findsNothing, reason: word);
      }
    });
  });
}
