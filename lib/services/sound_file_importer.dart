import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/sound_library.dart';

/// Picks an audio file off the device and brings it into the app's own
/// storage.
///
/// An interface so the sound screen can be tested without a file picker.
abstract class SoundFileImporter {
  /// Returns the new sound id, or null if the user backed out.
  Future<String?> pickAndImport();
}

class FilePickerSoundImporter implements SoundFileImporter {
  const FilePickerSoundImporter();

  @override
  Future<String?> pickAndImport() async {
    // file_picker 12: a static call returning the file itself, null when the
    // user backed out.
    final picked = await FilePicker.pickFile(type: FileType.audio);
    final source = picked?.path;
    if (source == null) return null;

    // Copied, never referenced in place: the picked file may live in a cache
    // the system clears, or on a share the user deletes, and an alarm that
    // rings silently at 6am because its sound moved is a broken alarm.
    final directory = Directory(
      p.join((await getApplicationDocumentsDirectory()).path, 'sounds'),
    );
    await directory.create(recursive: true);

    // The timestamp keeps two files of the same name apart.
    final destination = p.join(
      directory.path,
      '${DateTime.now().millisecondsSinceEpoch}_${p.basename(source)}',
    );
    await File(source).copy(destination);
    return deviceSoundIdFor(destination);
  }
}

final soundFileImporterProvider = Provider<SoundFileImporter>(
  (ref) => const FilePickerSoundImporter(),
);
