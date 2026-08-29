import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/services/app_update.dart';
import 'package:wake_or_pay/services/distribution.dart';

import '../helpers.dart';

void main() {
  group('check', () {
    test('a newer published build becomes an available update', () async {
      final source = FakeUpdateSource(manifest: updateManifest(build: 42));
      final container = await testContainer(
        updateSource: source,
        updateVersion: FakeAppVersionInfo(build: 10, versionName: '1.0.0'),
      );

      await container.read(appUpdateProvider.notifier).check();

      final state = container.read(appUpdateProvider);
      expect(state.available?.build, 42);
      expect(state.checking, isFalse);
      expect(state.error, isNull);
      expect(state.showBanner, isTrue);
      expect(state.currentLabel, '1.0.0 (build 10)');
    });

    test('the published build already installed is not an update', () async {
      final container = await testContainer(
        updateSource: FakeUpdateSource(manifest: updateManifest(build: 10)),
        updateVersion: FakeAppVersionInfo(build: 10),
      );

      await container.read(appUpdateProvider.notifier).check();

      final state = container.read(appUpdateProvider);
      expect(state.available, isNull);
      expect(state.error, isNull);
      // Checked and found nothing is not 未確認: the row must say 最新です.
      expect(state.lastCheckedAt, isNotNull);
    });

    test('a source that answers nothing is silent, not an error', () async {
      final source = FakeUpdateSource(); // offline / 404 / bad JSON
      final container = await testContainer(updateSource: source);

      await container.read(appUpdateProvider.notifier).check();

      final state = container.read(appUpdateProvider);
      expect(source.fetches, 1);
      expect(state.available, isNull);
      expect(state.error, isNull);
      expect(state.checking, isFalse);
    });

    test('the second check inside 12 h does not reach the source', () async {
      final source = FakeUpdateSource(manifest: updateManifest(build: 42));
      final container = await testContainer(updateSource: source);
      final service = container.read(appUpdateProvider.notifier);

      await service.check();
      await service.check();

      // The clock is pinned, so the second call is the same instant.
      expect(source.fetches, 1);
    });

    test('a manual check ignores the throttle', () async {
      final source = FakeUpdateSource(manifest: updateManifest(build: 42));
      final container = await testContainer(updateSource: source);
      final service = container.read(appUpdateProvider.notifier);

      await service.check();
      await service.check(force: true);

      expect(source.fetches, 2);
    });

    test('a check stamped 13 h ago is stale enough to run', () async {
      final source = FakeUpdateSource(manifest: updateManifest(build: 42));
      final container = await testContainer(
        prefs: {
          kUpdateLastCheckedKey: testNow
              .subtract(const Duration(hours: 13))
              .toIso8601String(),
        },
        updateSource: source,
      );

      await container.read(appUpdateProvider.notifier).checkOnStart();

      expect(source.fetches, 1);
      expect(container.read(appUpdateProvider).available?.build, 42);
    });

    test('a check stamped an hour ago is not', () async {
      final source = FakeUpdateSource(manifest: updateManifest(build: 42));
      final container = await testContainer(
        prefs: {
          kUpdateLastCheckedKey: testNow
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
        },
        updateSource: source,
      );

      await container.read(appUpdateProvider.notifier).checkOnStart();

      expect(source.fetches, 0);
    });

    test('the time of the check is persisted for the next app start', () async {
      final container = await testContainer(
        updateSource: FakeUpdateSource(manifest: updateManifest(build: 42)),
      );

      await container.read(appUpdateProvider.notifier).check();

      expect(
        container
            .read(sharedPreferencesProvider)
            .getString(kUpdateLastCheckedKey),
        testNow.toIso8601String(),
      );
    });
  });

  group('downloadAndInstall', () {
    test('progress reaches 1.0, then the installer gets the path', () async {
      final downloader = FakeApkDownloader(path: '/updates/WakeOrPay-42.apk');
      final installer = FakeApkInstaller();
      final container = await testContainer(
        updateSource: FakeUpdateSource(manifest: updateManifest(build: 42)),
        updateDownloader: downloader,
        updateInstaller: installer,
      );
      final service = container.read(appUpdateProvider.notifier);
      await service.check();

      await service.downloadAndInstall();

      expect(downloader.requested.single.build, 42);
      expect(
        downloader.requested.single.url,
        'https://github.com/tsubasak1217/wake-or-pay/releases/latest/download/WakeOrPay.apk',
      );
      expect(installer.opened, ['/updates/WakeOrPay-42.apk']);
      final state = container.read(appUpdateProvider);
      expect(state.progress, 1.0);
      expect(state.downloading, isFalse);
      expect(state.error, isNull);
    });

    test('a failed download says so and installs nothing', () async {
      final installer = FakeApkInstaller();
      final container = await testContainer(
        updateSource: FakeUpdateSource(manifest: updateManifest(build: 42)),
        updateDownloader: FakeApkDownloader(path: null),
        updateInstaller: installer,
      );
      final service = container.read(appUpdateProvider.notifier);
      await service.check();

      await service.downloadAndInstall();

      expect(installer.opened, isEmpty);
      final state = container.read(appUpdateProvider);
      expect(state.error, kUpdateDownloadFailed);
      expect(state.downloading, isFalse);
    });

    test('an installer that will not open names the permission', () async {
      final container = await testContainer(
        updateSource: FakeUpdateSource(manifest: updateManifest(build: 42)),
        updateInstaller: FakeApkInstaller(succeeds: false),
      );
      final service = container.read(appUpdateProvider.notifier);
      await service.check();

      await service.downloadAndInstall();

      final state = container.read(appUpdateProvider);
      expect(state.error, kUpdateInstallBlocked);
      expect(state.error, contains('不明なアプリのインストール'));
      expect(state.downloading, isFalse);
    });

    test('with nothing available it does nothing at all', () async {
      final downloader = FakeApkDownloader();
      final container = await testContainer(updateDownloader: downloader);

      await container.read(appUpdateProvider.notifier).downloadAndInstall();

      expect(downloader.requested, isEmpty);
      expect(container.read(appUpdateProvider).downloading, isFalse);
    });
  });

  group('dismiss', () {
    test('あとで hides the banner but keeps the update', () async {
      final container = await testContainer(
        updateSource: FakeUpdateSource(manifest: updateManifest(build: 42)),
      );
      final service = container.read(appUpdateProvider.notifier);
      await service.check();

      service.dismiss();

      final state = container.read(appUpdateProvider);
      expect(state.available?.build, 42);
      expect(state.showBanner, isFalse);
    });

    test('a newer build than the dismissed one comes back', () async {
      final source = FakeUpdateSource(manifest: updateManifest(build: 42));
      final container = await testContainer(updateSource: source);
      final service = container.read(appUpdateProvider.notifier);
      await service.check();
      service.dismiss();

      source.manifest = updateManifest(build: 43);
      await service.check(force: true);

      expect(container.read(appUpdateProvider).showBanner, isTrue);
    });

    test('the same build stays dismissed across a re-check', () async {
      final source = FakeUpdateSource(manifest: updateManifest(build: 42));
      final container = await testContainer(updateSource: source);
      final service = container.read(appUpdateProvider.notifier);
      await service.check();
      service.dismiss();

      await service.check(force: true);

      expect(container.read(appUpdateProvider).showBanner, isFalse);
    });
  });

  group('GitHubUpdateSource', () {
    test('a non-200 is null, not an exception', () async {
      // The fake answers 404 for any URL it does not know, which is what a
      // release with no version.json yet looks like.
      final source = GitHubUpdateSource(FakeHttpClient());

      expect(await source.fetchManifest(), isNull);
    });

    test('an offline client is null, not an exception', () async {
      final source = GitHubUpdateSource(FakeHttpClient(throws: true));

      expect(await source.fetchManifest(), isNull);
    });

    test('a body that is not JSON is null', () async {
      final source = GitHubUpdateSource(
        FakeHttpClient(responses: {kUpdateManifestUrl: '<!doctype html>'}),
      );

      expect(await source.fetchManifest(), isNull);
    });

    test('a real manifest is decoded', () async {
      final source = GitHubUpdateSource(
        FakeHttpClient(
          responses: {
            kUpdateManifestUrl:
                '{"build":42,"versionName":"1.0.0",'
                '"apkUrl":"https://example.com/a.apk",'
                '"publishedAt":"2026-08-29T00:00:00Z","notes":""}',
          },
        ),
      );

      expect((await source.fetchManifest())?['build'], 42);
    });
  });

  test('PlayUpdateSource never offers an APK', () async {
    expect(await const PlayUpdateSource().fetchManifest(), isNull);
  });
}
