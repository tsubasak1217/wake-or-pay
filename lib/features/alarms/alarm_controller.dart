import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/oversleep_contact_rules.dart';
import '../../services/alarm_service.dart';

final alarmControllerProvider = Provider(AlarmController.new);

/// Every write to an alarm goes through here, so the stored alarm and the
/// platform schedule can never drift apart.
class AlarmController {
  AlarmController(this._ref);

  final Ref _ref;

  static String newId() => DateTime.now().millisecondsSinceEpoch.toString();

  Future<void> save(Alarm alarm) async {
    final fresh = await _withCurrentContact(alarm);
    await _ref.read(alarmRepositoryProvider).save(fresh);
    await _ref.read(alarmServiceProvider).schedule(fresh);
  }

  /// [alarm] with its contact snapshot brought back up to date from the 連絡帳.
  ///
  /// The snapshot exists so that deleting somebody from the book never leaves
  /// an alarm with nobody to call — but while they are still in it, the book
  /// is the truth. Refreshing on every write keeps the stored copy from
  /// drifting: a name edited a month ago is corrected the next time the alarm
  /// is touched at all, including by its own on/off switch.
  Future<Alarm> _withCurrentContact(Alarm alarm) async {
    final id = alarm.contact?.contactId;
    if (id == null) return alarm;
    final entry = await _ref.read(contactBookRepositoryProvider).getById(id);
    return entry == null ? alarm : resolveAlarmContact(alarm, [entry]);
  }

  Future<void> setEnabled(Alarm alarm, bool enabled) =>
      save(alarm.copyWith(enabled: enabled));

  Future<void> delete(Alarm alarm) async {
    await _ref.read(alarmServiceProvider).cancel(alarm);
    await _ref.read(alarmRepositoryProvider).delete(alarm.id);
  }
}
