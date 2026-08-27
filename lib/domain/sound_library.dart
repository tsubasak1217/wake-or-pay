import 'package:path/path.dart' as p;

/// One bundled alarm sound.
///
/// Only [id] is ever stored, so a sound can be renamed or re-synthesised
/// without migrating anything.
class SoundDef {
  const SoundDef(this.id, this.label, this.assetPath);

  final String id;
  final String label;
  final String assetPath;
}

/// The bundled library. Every file here is synthesised in-repo — see
/// `tool/synth_sounds.dart` and `assets/audio/LICENSE.md`. `bell` is the
/// original `alarm.wav`, kept under its old path so alarms saved before the
/// library existed ring with exactly the sound they always did.
const soundLibrary = <SoundDef>[
  SoundDef('bell', 'ベル', 'assets/audio/alarm.wav'),
  SoundDef('buzzer', 'ブザー', 'assets/audio/buzzer.wav'),
  SoundDef('chime', 'チャイム', 'assets/audio/chime.wav'),
  SoundDef('siren', 'サイレン', 'assets/audio/siren.wav'),
  SoundDef('birds', '小鳥', 'assets/audio/birds.wav'),
];

/// Marks a sound id as a file the user picked, rather than a library entry.
const deviceSoundPrefix = 'file:';

bool isDeviceSound(String soundId) => soundId.startsWith(deviceSoundPrefix);

String deviceSoundIdFor(String path) => '$deviceSoundPrefix$path';

String deviceSoundPathOf(String soundId) =>
    soundId.substring(deviceSoundPrefix.length);

/// null for a device file or an unknown id. Pure.
SoundDef? soundDefById(String soundId) {
  for (final sound in soundLibrary) {
    if (sound.id == soundId) return sound;
  }
  return null;
}

/// What the sound is called in the UI. A device file shows its file name.
/// Pure.
String soundLabel(String soundId) {
  if (isDeviceSound(soundId)) return p.basename(deviceSoundPathOf(soundId));
  return (soundDefById(soundId) ?? soundLibrary.first).label;
}

/// What to hand the alarm plugin: an asset path for a library sound, an
/// absolute file path for a picked one. Pure.
///
/// An id that matches nothing — a library entry dropped in a later version, a
/// hand edited row — falls back to the bell rather than to silence. A missing
/// asset would mean an alarm that does not wake anyone.
String soundPathFor(String soundId) {
  if (isDeviceSound(soundId)) return deviceSoundPathOf(soundId);
  return (soundDefById(soundId) ?? soundLibrary.first).assetPath;
}
