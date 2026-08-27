import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wake_or_pay/data/database.dart';
import 'package:wake_or_pay/data/mappers.dart';
import 'package:wake_or_pay/data/providers.dart';
import 'package:wake_or_pay/domain/models.dart';
import 'package:wake_or_pay/services/legacy_recording_cleanup.dart';

import '../helpers.dart';

/// One v6 contact blob, as the retired 電話設定 wrote it.
String legacyBlob({String? recordingPath, int? triggerMinutes}) => jsonEncode({
  'name': '母',
  'phone': '090-0000-0000',
  'mailMode': 'custom',
  'mailMessage': '起きて',
  'phoneMode': 'custom',
  if (recordingPath != null) ...{
    'recordingPath': recordingPath,
    'recordingWaveform': [0.5, 0.25],
  },
  if (triggerMinutes != null) ...{
    'triggerMinutesAfterGrace': triggerMinutes,
  },
});

Future<AlarmRow> rowOf(ProviderContainer container, String id) async {
  final db = container.read(appDatabaseProvider);
  return (db.select(db.alarmRows)..where((a) => a.id.equals(id))).getSingle();
}

/// Writes one alarm row straight through drift, because the point of the
/// cleanup is what it does to a blob the current mapper would never write.
Future<void> seed(
  ProviderContainer container, {
  required String id,
  String? contactJson,
  int? triggerMinutes,
}) async {
  final db = container.read(appDatabaseProvider);
  await db
      .into(db.alarmRows)
      .insert(
        AlarmRowsCompanion.insert(
          id: id,
          hour: 6,
          minute: 30,
          wakeCheck: 'math',
          kakugoHostage: const Value('coin'),
          kakugoRatePerMinute: const Value(100),
          kakugoCap: const Value(2000),
          oversleepContact: Value(contactJson),
          oversleepTriggerMinutes: Value(triggerMinutes),
        ),
      );
}

void main() {
  group('legacyRecordingPathsIn', () {
    test('the one path a v6 blob can hold', () {
      expect(legacyRecordingPathsIn(legacyBlob(recordingPath: '/tmp/a.m4a')), [
        '/tmp/a.m4a',
      ]);
    });

    test('nothing that names no file', () {
      // A blob with no key, a blank string, no column at all, and junk: none
      // of them names a file that exists, so none of them is an error either.
      expect(legacyRecordingPathsIn(legacyBlob()), isEmpty);
      expect(legacyRecordingPathsIn(legacyBlob(recordingPath: '   ')), isEmpty);
      expect(legacyRecordingPathsIn(null), isEmpty);
      expect(legacyRecordingPathsIn(''), isEmpty);
      expect(legacyRecordingPathsIn('{ not json'), isEmpty);
      expect(legacyRecordingPathsIn('[]'), isEmpty, reason: 'not a map');
    });
  });

  group('legacyTriggerMinutesIn', () {
    test('the number a v6 row kept inside its contact blob', () {
      expect(
        legacyTriggerMinutesIn(
          jsonDecode(legacyBlob(triggerMinutes: 7)) as Map<String, dynamic>,
        ),
        7,
      );
    });

    test('absent, unreadable or not an integer gives null', () {
      expect(
        legacyTriggerMinutesIn(
          jsonDecode(legacyBlob()) as Map<String, dynamic>,
        ),
        isNull,
      );
      expect(legacyTriggerMinutesIn(null), isNull);
      expect(
        legacyTriggerMinutesIn(const {'triggerMinutesAfterGrace': 'seven'}),
        isNull,
        reason: 'a hand edited row must not become a delay',
      );
    });

    test('a hand edited number is clamped on the way in', () {
      expect(
        legacyTriggerMinutesIn(const {'triggerMinutesAfterGrace': 9999}),
        maxContactTriggerMinutes,
      );
      expect(
        legacyTriggerMinutesIn(const {'triggerMinutesAfterGrace': -5}),
        minContactTriggerMinutes,
      );
    });
  });

  group('LegacyRecordingCleanup', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('wop_legacy'));
    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    File recording() =>
        File('${dir.path}${Platform.pathSeparator}a.m4a')
          ..writeAsBytesSync(const [0, 1, 2]);

    test('the file goes, the blob is rewritten, the delay is carried', () async {
      final container = await testContainer();
      final file = recording();
      await seed(
        container,
        id: 'a1',
        contactJson: legacyBlob(recordingPath: file.path, triggerMinutes: 7),
      );

      final deleted = await container
          .read(legacyRecordingCleanupProvider)
          .run();
      expect(deleted, 1);
      expect(file.existsSync(), isFalse, reason: 'nothing left to play it on');

      final row = await rowOf(container, 'a1');
      expect(row.oversleepContact, isNot(contains('recordingPath')));
      expect(row.oversleepContact, isNot(contains('recordingWaveform')));
      expect(row.oversleepContact, isNot(contains('phoneMode')));
      expect(
        row.oversleepTriggerMinutes,
        7,
        reason: '猶予後7分 survives the blob being rewritten without it',
      );

      // The words the user wrote are the one thing that does survive.
      final alarm = (await container
          .read(alarmRepositoryProvider)
          .getById('a1'))!;
      expect(alarm.contact!.messageMode, MessageMode.custom);
      expect(alarm.contact!.message, '起きて');
      expect(alarm.oversleepTriggerMinutes, 7);
    });

    test('a second run deletes nothing and leaves the row alone', () async {
      final container = await testContainer();
      final file = recording();
      await seed(
        container,
        id: 'a1',
        contactJson: legacyBlob(recordingPath: file.path, triggerMinutes: 7),
      );

      await container.read(legacyRecordingCleanupProvider).run();
      final after = await rowOf(container, 'a1');

      expect(
        await container.read(legacyRecordingCleanupProvider).run(),
        0,
        reason: 'the first pass is what makes the sweep idempotent',
      );
      final again = await rowOf(container, 'a1');
      expect(again.oversleepContact, after.oversleepContact);
      expect(again.oversleepTriggerMinutes, after.oversleepTriggerMinutes);
    });

    test('a row with no recording still gets its delay moved across', () async {
      final container = await testContainer();
      await seed(container, id: 'a1', contactJson: legacyBlob(
        triggerMinutes: 0,
      ));

      expect(await container.read(legacyRecordingCleanupProvider).run(), 0);
      expect((await rowOf(container, 'a1')).oversleepTriggerMinutes, 0);
    });

    test('a file that is already gone is the ordinary case', () async {
      final container = await testContainer();
      await seed(
        container,
        id: 'a1',
        contactJson: legacyBlob(
          recordingPath: '${dir.path}${Platform.pathSeparator}missing.m4a',
        ),
      );

      expect(
        await container.read(legacyRecordingCleanupProvider).run(),
        0,
        reason: 'nothing deleted, and nothing thrown either',
      );
      expect(
        (await rowOf(container, 'a1')).oversleepContact,
        isNot(contains('recordingPath')),
      );
    });

    test('an alarm that never had a contact is left untouched', () async {
      final container = await testContainer();
      await seed(container, id: 'a1', triggerMinutes: 5);

      expect(await container.read(legacyRecordingCleanupProvider).run(), 0);
      final row = await rowOf(container, 'a1');
      expect(row.oversleepContact, isNull);
      expect(row.oversleepTriggerMinutes, 5, reason: 'not rewritten at all');
    });
  });
}
