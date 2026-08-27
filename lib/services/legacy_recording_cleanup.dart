import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/mappers.dart' show legacyTriggerMinutesIn;
import '../data/providers.dart';
import '../domain/models.dart';

/// The recording paths hiding in one v6 contact blob. Pure.
///
/// 改訂4 retired the automated-call island: a call now places a call and plays
/// nothing, so a recording made for it has nothing left to play on. Spec 11.4
/// says those are 読み捨て — and that the **file** goes with them, which is
/// what makes this more than a JSON change.
///
/// A list rather than a single value because a caller sweeps a whole table
/// through it and wants to concatenate; for one row it holds at most one path.
/// Unreadable JSON, an absent key, and a blank string all give nothing: none
/// of them names a file that exists.
List<String> legacyRecordingPathsIn(String? contactJson) {
  if (contactJson == null || contactJson.isEmpty) return const [];
  try {
    final map = (jsonDecode(contactJson) as Map).cast<String, dynamic>();
    final path = (map['recordingPath'] as String?)?.trim() ?? '';
    return path.isEmpty ? const [] : [path];
  } on Object {
    return const [];
  }
}

/// Deletes the recordings the retired 電話設定 left behind, once.
///
/// Runs at startup, fire and forget. It sweeps every alarm row, deletes the
/// files it finds, and **rewrites each contact blob in the new shape** — which
/// is what makes the sweep idempotent: after one pass no row has a
/// `recordingPath` in it any more, so the second pass finds nothing and writes
/// nothing.
///
/// Nothing here is allowed to be an error. A file that is already gone is the
/// ordinary case; a file that will not delete (a permission, a locked handle)
/// is a stale byte on disk and not a reason to fail an app launch. The blob is
/// rewritten either way, so a file that refuses to go is at least never
/// referenced again.
class LegacyRecordingCleanup {
  LegacyRecordingCleanup(this._db);

  final AppDatabase _db;

  /// The paths deleted by the last run, for the tests and for nothing else.
  Future<int> run() async {
    final rows = await _db.select(_db.alarmRows).get();
    var deleted = 0;

    for (final row in rows) {
      final json = row.oversleepContact;
      final paths = legacyRecordingPathsIn(json);
      final legacyTrigger = _legacyTrigger(json);
      if (paths.isEmpty && legacyTrigger == null) continue;

      for (final path in paths) {
        if (await _deleteFile(path)) deleted++;
      }

      // Rewrite in the new shape. Parsing and re-encoding through the model is
      // the whole point: whatever the old blob held, what goes back is exactly
      // what this version writes, so the next sweep sees nothing to do.
      final contact = _parse(json);
      await (_db.update(_db.alarmRows)..where((a) => a.id.equals(row.id)))
          .write(
            AlarmRowsCompanion(
              oversleepContact: Value(
                contact == null ? null : jsonEncode(contact.toJson()),
              ),
              // Carried across in the same write, so the delay a v6 row set
              // survives the blob being rewritten without it.
              oversleepTriggerMinutes: Value(
                row.oversleepTriggerMinutes ??
                    legacyTrigger ??
                    defaultContactTriggerMinutes,
              ),
            ),
          );
    }
    return deleted;
  }

  static int? _legacyTrigger(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      return legacyTriggerMinutesIn(
        (jsonDecode(json) as Map).cast<String, dynamic>(),
      );
    } on Object {
      return null;
    }
  }

  static OversleepContact? _parse(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final contact = OversleepContact.fromJson(
        (jsonDecode(json) as Map).cast<String, dynamic>(),
      );
      return contact.isUsable ? contact : null;
    } on Object {
      return null;
    }
  }

  static Future<bool> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;
      await file.delete();
      return true;
    } on Object {
      // A file that will not delete is a stale byte on disk. The blob is
      // rewritten anyway, so nothing points at it any more.
      return false;
    }
  }
}

final legacyRecordingCleanupProvider = Provider(
  (ref) => LegacyRecordingCleanup(ref.watch(appDatabaseProvider)),
);
