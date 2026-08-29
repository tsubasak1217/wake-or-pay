import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/domain/app_update.dart';

const _apkUrl =
    'https://github.com/tsubasak1217/wake-or-pay/releases/latest/download/WakeOrPay.apk';

Map<String, dynamic> manifest({
  Object? build = 11,
  Object? versionName = '1.1.0',
  Object? apkUrl = _apkUrl,
  Object? notes = '',
}) => {
  'build': build,
  'versionName': versionName,
  'apkUrl': apkUrl,
  'publishedAt': '2026-08-29T00:00:00Z',
  'notes': notes,
};

void main() {
  group('newerThan', () {
    test('a higher build is an update, with the manifest read out of it', () {
      final update = newerThan(10, manifest(build: 11, notes: '不具合修正'));

      expect(update, isNotNull);
      expect(update!.build, 11);
      expect(update.versionName, '1.1.0');
      expect(update.apkUrl, _apkUrl);
      expect(update.notes, '不具合修正');
    });

    test('the same build is not an update', () {
      expect(newerThan(10, manifest(build: 10)), isNull);
    });

    test('an older build is not an update', () {
      expect(newerThan(10, manifest(build: 9)), isNull);
    });

    test('a build 0 install is offered everything', () {
      // What an app whose buildNumber could not be read reports. It must be
      // *offered* the update rather than told there is none.
      expect(newerThan(0, manifest(build: 1))?.build, 1);
    });

    group('malformed manifests are all "no update", never an error', () {
      test('no build field at all', () {
        expect(newerThan(10, const {'versionName': '1.1.0'}), isNull);
      });

      test('the build written as a string', () {
        expect(newerThan(10, manifest(build: '11')), isNull);
      });

      test('the build written as a double', () {
        expect(newerThan(10, manifest(build: 11.0)), isNull);
      });

      test('an empty object — a truncated upload', () {
        expect(newerThan(10, const {}), isNull);
      });

      test('no download URL', () {
        expect(newerThan(10, manifest(apkUrl: '')), isNull);
        expect(newerThan(10, manifest(apkUrl: null)), isNull);
      });

      test('a plain-http download URL', () {
        // An APK is executable code; http is a URL anybody on the wifi can
        // answer instead of GitHub.
        expect(
          newerThan(10, manifest(apkUrl: 'http://example.com/a.apk')),
          isNull,
        );
      });

      test('a URL that is not one', () {
        expect(newerThan(10, manifest(apkUrl: 'WakeOrPay.apk')), isNull);
      });
    });

    test('missing text fields fall back to empty, not to null', () {
      final update = newerThan(
        10,
        manifest(build: 11, versionName: null, notes: 42),
      );

      expect(update, isNotNull);
      expect(update!.versionName, '');
      expect(update.notes, '');
    });

    test('value equality', () {
      expect(newerThan(10, manifest()), newerThan(10, manifest()));
      expect(
        newerThan(10, manifest(build: 11)),
        isNot(newerThan(10, manifest(build: 12))),
      );
    });
  });

  group('parseBuildNumber', () {
    test('the ordinary Android versionCode', () {
      expect(parseBuildNumber('42'), 42);
      expect(parseBuildNumber(' 42 '), 42);
    });

    test('empty is 0', () {
      expect(parseBuildNumber(''), 0);
      expect(parseBuildNumber('   '), 0);
    });

    test('a dotted CFBundleVersion takes its last segment', () {
      expect(parseBuildNumber('1.0.3'), 3);
    });

    test('nonsense is 0, never an exception', () {
      expect(parseBuildNumber('latest'), 0);
      expect(parseBuildNumber('1.0.x'), 0);
    });

    test('a negative build is 0', () {
      expect(parseBuildNumber('-5'), 0);
    });
  });
}
