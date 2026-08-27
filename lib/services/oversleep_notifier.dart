import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../data/repositories/contact_event_repository.dart';
import '../domain/models.dart';
import '../domain/oversleep_contact_rules.dart';
import 'alarm_settings_builder.dart';
import 'app_notifier.dart';

/// How the app tells someone that an alarm was slept through.
///
/// An interface because the next phase replaces it wholesale: a server that
/// actually places the call or sends the mail. Everything above this line —
/// the timing, the once-per-session rule, the countdown, the speech — is
/// finished and will not move when that lands.
abstract class OversleepNotifier {
  /// Returns the event that was recorded, or null if nothing was.
  Future<ContactEvent?> notify({
    required AlarmSession session,
    required OversleepContact contact,
    required DateTime at,
  });
}

/// The implementation this phase ships: **nothing is sent**.
///
/// It writes the trigger into `contact_events` and posts a notification that
/// says, in as many words, that no message actually went out. Letting the user
/// believe a call was placed when it was not would be worse than not having
/// the feature at all.
class LoggingOversleepNotifier implements OversleepNotifier {
  LoggingOversleepNotifier(this._events, this._notifications);

  final ContactEventRepository _events;
  final AppNotifier _notifications;

  @override
  Future<ContactEvent?> notify({
    required AlarmSession session,
    required OversleepContact contact,
    required DateTime at,
  }) async {
    final event = ContactEvent(
      id: 'contact-${at.millisecondsSinceEpoch}-${session.id}',
      sessionId: session.id,
      firedAt: at,
      contactName: contact.name,
      channel: channelFor(contact),
      detail: detailFor(contact),
    );
    await _events.save(event);

    final text = contactSentNotificationText(contact.name);
    await _notifications.show(
      id: contactNotificationId(platformAlarmId(session.alarmId)),
      title: text.title,
      body: text.body,
    );
    return event;
  }
}

/// Which route the next phase would have taken. Pure.
///
/// A phone number is the loudest thing available, so it wins; an address is
/// next; with neither there is nothing to do but write it down.
ContactChannel channelFor(OversleepContact contact) {
  if ((contact.phone ?? '').trim().isNotEmpty) return ContactChannel.phone;
  if ((contact.email ?? '').trim().isNotEmpty) return ContactChannel.email;
  return ContactChannel.log;
}

/// What would have been sent, kept so the history can show it. Pure.
String? detailFor(OversleepContact contact) {
  final parts = [
    if ((contact.message ?? '').trim().isNotEmpty) contact.message!.trim(),
    if ((contact.recordingPath ?? '').isNotEmpty) '（録音あり）',
  ];
  return parts.isEmpty ? null : parts.join(' ');
}

/// Decides *whether* to fire, and fires at most once per session.
///
/// The once-per-session rule is enforced against the stored events rather than
/// a flag in memory, so a relaunch mid-ring — or the ring screen being rebuilt
/// — cannot send a second one.
class ContactDispatcher {
  ContactDispatcher(this._events, this._notifier);

  final ContactEventRepository _events;
  final OversleepNotifier _notifier;

  /// Returns the event if one was recorded now, null in every other case:
  /// nobody to contact, not due yet, or already sent for this session.
  Future<ContactEvent?> fireIfDue({
    required Alarm alarm,
    required AlarmSession session,
    required DateTime now,
  }) async {
    if (!alarm.willContact) return null;
    final contact = alarm.contact!;
    if (!contactIsDue(now, session, contact)) return null;
    if ((await _events.forSession(session.id)).isNotEmpty) return null;

    return _notifier.notify(session: session, contact: contact, at: now);
  }
}

final oversleepNotifierProvider = Provider<OversleepNotifier>(
  (ref) => LoggingOversleepNotifier(
    ref.watch(contactEventRepositoryProvider),
    ref.watch(appNotifierProvider),
  ),
);

final contactDispatcherProvider = Provider(
  (ref) => ContactDispatcher(
    ref.watch(contactEventRepositoryProvider),
    ref.watch(oversleepNotifierProvider),
  ),
);
