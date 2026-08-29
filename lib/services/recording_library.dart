import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// One file in `<app support>/contact_recordings/`.
@immutable
class Recording {
  const Recording({required this.path, this.recordedAt});

  final String path;

  /// When it was recorded, read out of the file name — see
  /// [recordingTimestamp]. Null when the name says nothing usable, which is
  /// the only case the list has to sort last rather than guess about.
  final DateTime? recordedAt;

  @override
  bool operator ==(Object other) =>
      other is Recording && other.path == path && other.recordedAt == recordedAt;

  @override
  int get hashCode => Object.hash(path, recordedAt);

  @override
  String toString() => 'Recording($path, $recordedAt)';
}

/// The 寝言の録音 shelf. An interface rather than a directory, so the
/// アクティビティ tab can be driven in a widget test without `path_provider`
/// underneath — the same shape [VoiceRecorder] already uses for the microphone.
abstract class RecordingLibrary {
  /// Everything on the shelf, newest first.
  Future<List<Recording>> list();

  /// Removes one file. A path that is already gone is not an error.
  Future<void> delete(String path);
}

/// `<alarmId>-<millis>.m4a` → when it was made. Pure.
///
/// The timestamp is the part after the **last** hyphen: an alarm id may contain
/// hyphens of its own, and splitting on the first one would read the id as the
/// clock. Null when there is no trailing number — a file somebody else put
/// there is still listed, just without a date.
DateTime? recordingTimestamp(String path) {
  final name = p.basenameWithoutExtension(path);
  final cut = name.lastIndexOf('-');
  if (cut < 0 || cut == name.length - 1) return null;
  final millis = int.tryParse(name.substring(cut + 1));
  if (millis == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(millis);
}

/// Newest first; a recording with no readable date sorts to the end rather
/// than to an invented position at the top.
List<Recording> sortedRecordings(Iterable<Recording> recordings) =>
    recordings.toList()
      ..sort((a, b) {
        final left = a.recordedAt;
        final right = b.recordedAt;
        if (left == null && right == null) return a.path.compareTo(b.path);
        if (left == null) return 1;
        if (right == null) return -1;
        return right.compareTo(left);
      });

class FileRecordingLibrary implements RecordingLibrary {
  const FileRecordingLibrary();

  static const directoryName = 'contact_recordings';

  Future<Directory> _directory() async => Directory(
    p.join((await getApplicationSupportDirectory()).path, directoryName),
  );

  @override
  Future<List<Recording>> list() async {
    final directory = await _directory();
    // A shelf nobody has recorded onto yet is an empty shelf, not a fault.
    if (!await directory.exists()) return const [];
    final files = await directory
        .list()
        .where((e) => e is File)
        .map((e) => e.path)
        .toList();
    return sortedRecordings([
      for (final path in files)
        Recording(path: path, recordedAt: recordingTimestamp(path)),
    ]);
  }

  @override
  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}

final recordingLibraryProvider = Provider<RecordingLibrary>(
  (ref) => const FileRecordingLibrary(),
);

/// The shelf as the screen reads it. Invalidated after a delete, which is the
/// only thing that changes it while the tab is open.
final recordingsProvider = FutureProvider<List<Recording>>(
  (ref) => ref.watch(recordingLibraryProvider).list(),
);
