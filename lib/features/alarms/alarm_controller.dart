import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../services/alarm_service.dart';

final alarmControllerProvider = Provider(AlarmController.new);

/// Every write to an alarm goes through here, so the stored alarm and the
/// platform schedule can never drift apart.
class AlarmController {
  AlarmController(this._ref);

  final Ref _ref;

  static String newId() => DateTime.now().millisecondsSinceEpoch.toString();

  Future<void> save(Alarm alarm) async {
    await _ref.read(alarmRepositoryProvider).save(alarm);
    await _ref.read(alarmServiceProvider).schedule(alarm);
  }

  Future<void> setEnabled(Alarm alarm, bool enabled) =>
      save(alarm.copyWith(enabled: enabled));

  Future<void> delete(Alarm alarm) async {
    await _ref.read(alarmServiceProvider).cancel(alarm);
    await _ref.read(alarmRepositoryProvider).delete(alarm.id);
  }
}
