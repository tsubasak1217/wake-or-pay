import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/domain/sound_library.dart';
import 'package:wake_or_pay/services/sound_file_importer.dart';
import 'package:wake_or_pay/services/sound_preview_player.dart';

import 'alarms_test.dart' show inSubScreen, pumpHome;

/// Records what it was asked to do instead of making a noise.
class FakePreviewPlayer implements SoundPreviewPlayer {
  final calls = <String>[];

  @override
  Future<void> play(String soundId) async => calls.add('play:$soundId');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> dispose() async => calls.add('dispose');
}

class FakeImporter implements SoundFileImporter {
  FakeImporter(this.result);

  final String? result;
  var calls = 0;

  @override
  Future<String?> pickAndImport() async {
    calls++;
    return result;
  }
}

void main() {
  testWidgets('every bundled sound is listed and can be previewed', (
    tester,
  ) async {
    final player = FakePreviewPlayer();
    await pumpHome(
      tester,
      coins: 0,
      extra: [soundPreviewPlayerProvider.overrideWithValue(player)],
    );
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await inSubScreen(tester, 'サウンド', () async {
      expect(soundLibrary, hasLength(greaterThanOrEqualTo(5)));
      for (final sound in soundLibrary) {
        expect(find.text(sound.label), findsOneWidget, reason: sound.id);
      }

      // Play one, then stop it with the same button.
      await tester.tap(find.byKey(const ValueKey('preview-siren')));
      await tester.pumpAndSettle();
      expect(player.calls, ['play:siren']);
      await tester.tap(find.byKey(const ValueKey('preview-siren')));
      await tester.pumpAndSettle();
      expect(player.calls, ['play:siren', 'stop']);

      // Choosing is a separate act from previewing.
      await tester.tap(find.text('チャイム'));
      await tester.pumpAndSettle();
    });

    expect(find.text('チャイム'), findsOneWidget, reason: 'shown on the row');
    // Leaving the screen silences the preview.
    expect(player.calls.last, 'stop');
  });

  testWidgets('a sound picked off the device is selected and saved', (
    tester,
  ) async {
    final importer = FakeImporter(
      deviceSoundIdFor(r'C:\app\sounds\1700000000_morning.mp3'),
    );
    final container = await pumpHome(
      tester,
      extra: [
        soundPreviewPlayerProvider.overrideWithValue(FakePreviewPlayer()),
        soundFileImporterProvider.overrideWithValue(importer),
      ],
    );
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await inSubScreen(tester, 'サウンド', () async {
      await tester.tap(find.byKey(const ValueKey('pickDeviceSound')));
      await tester.pumpAndSettle();
      expect(importer.calls, 1);
      expect(find.text('morning.mp3'), findsOneWidget);
      expect(find.text('この端末から選んだ音'), findsOneWidget);
    });

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final saved =
        (await container.read(alarmRepositoryProvider).getAll()).single;
    expect(saved.soundId, importer.result);
    expect(isDeviceSound(saved.soundId), isTrue);
  });

  testWidgets('backing out of the picker leaves the sound alone', (
    tester,
  ) async {
    final container = await pumpHome(
      tester,
      extra: [
        soundPreviewPlayerProvider.overrideWithValue(FakePreviewPlayer()),
        soundFileImporterProvider.overrideWithValue(FakeImporter(null)),
      ],
    );
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await inSubScreen(tester, 'サウンド', () async {
      await tester.tap(find.byKey(const ValueKey('pickDeviceSound')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sound-device')), findsNothing);
    });

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(
      (await container.read(alarmRepositoryProvider).getAll()).single.soundId,
      defaultSoundId,
    );
  });
}
