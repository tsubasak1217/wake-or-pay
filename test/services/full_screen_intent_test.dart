import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/services/full_screen_intent.dart';

void main() {
  group('shouldAskForFullScreenIntent', () {
    test('asks when the permission is missing and nothing is ringing', () {
      expect(
        shouldAskForFullScreenIntent(granted: false, ringing: false),
        isTrue,
      );
    });

    test('never asks when it is already granted', () {
      expect(
        shouldAskForFullScreenIntent(granted: true, ringing: false),
        isFalse,
      );
    });

    test('never asks over a ringing alarm', () {
      expect(
        shouldAskForFullScreenIntent(granted: false, ringing: true),
        isFalse,
        reason:
            'the app may have been cold-launched by the ring notification; a '
            'Settings screen on top of it hides the only way to stop the alarm',
      );
    });
  });

  group('ensureFullScreenIntent', () {
    test('a denied permission sends the user to the system toggle', () async {
      final permission = RecordingFullScreenIntentPermission(granted: false);

      expect(
        await ensureFullScreenIntent(permission, ringing: false),
        isFalse,
      );
      expect(permission.settingsOpened, 1);
    });

    test('a granted permission is left alone', () async {
      final permission = RecordingFullScreenIntentPermission();

      expect(await ensureFullScreenIntent(permission, ringing: false), isTrue);
      expect(permission.settingsOpened, 0);
    });

    test('a ring in progress is never interrupted', () async {
      final permission = RecordingFullScreenIntentPermission(granted: false);

      expect(await ensureFullScreenIntent(permission, ringing: true), isFalse);
      expect(permission.settingsOpened, 0);
    });
  });
}
