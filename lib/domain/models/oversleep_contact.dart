import 'package:flutter/foundation.dart';

/// How long after the grace window runs out the contact is triggered, in
/// minutes. Never 0: the point is that there is a stretch of oversleeping
/// first, so the user has a real chance to get up before anyone is told.
const minContactTriggerMinutes = 1;
const maxContactTriggerMinutes = 60;

int normalizeContactTriggerMinutes(int minutes) =>
    minutes.clamp(minContactTriggerMinutes, maxContactTriggerMinutes);

/// One person to tell about one alarm's oversleeping, per spec 5.
///
/// One per alarm. Nothing is actually sent yet — [OversleepNotifier] logs the
/// trigger instead — so this is entirely the user's own words about their own
/// contact, held on the device.
@immutable
class OversleepContact {
  const OversleepContact({
    required this.name,
    this.phone,
    this.email,
    this.triggerMinutesAfterGrace = minContactTriggerMinutes,
    this.message,
    this.recordingPath,
  });

  final String name;
  final String? phone;
  final String? email;

  /// 1-60. Counted from the end of the grace window, not from the ring.
  final int triggerMinutesAfterGrace;

  /// The body of the mail, or the script of the automated call.
  final String? message;

  /// A recording copied into the app's own storage, so it survives the
  /// original file being deleted.
  final String? recordingPath;

  /// A contact with no name is not a contact. The editor refuses to save one,
  /// and this is the same rule for anything read back off disk.
  bool get isUsable => name.trim().isNotEmpty;

  OversleepContact copyWith({
    String? name,
    String? phone,
    bool clearPhone = false,
    String? email,
    bool clearEmail = false,
    int? triggerMinutesAfterGrace,
    String? message,
    bool clearMessage = false,
    String? recordingPath,
    bool clearRecordingPath = false,
  }) => OversleepContact(
    name: name ?? this.name,
    phone: clearPhone ? null : (phone ?? this.phone),
    email: clearEmail ? null : (email ?? this.email),
    triggerMinutesAfterGrace:
        triggerMinutesAfterGrace ?? this.triggerMinutesAfterGrace,
    message: clearMessage ? null : (message ?? this.message),
    recordingPath: clearRecordingPath
        ? null
        : (recordingPath ?? this.recordingPath),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'email': email,
    'triggerMinutesAfterGrace': normalizeContactTriggerMinutes(
      triggerMinutesAfterGrace,
    ),
    'message': message,
    'recordingPath': recordingPath,
  };

  /// Like every other bound in this app, the trigger window is re-clamped on
  /// the way in: a hand edited row cannot push it past an hour or below one
  /// minute.
  factory OversleepContact.fromJson(Map<String, dynamic> json) =>
      OversleepContact(
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        triggerMinutesAfterGrace: normalizeContactTriggerMinutes(
          json['triggerMinutesAfterGrace'] as int? ?? minContactTriggerMinutes,
        ),
        message: json['message'] as String?,
        recordingPath: json['recordingPath'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is OversleepContact &&
      other.name == name &&
      other.phone == phone &&
      other.email == email &&
      other.triggerMinutesAfterGrace == triggerMinutesAfterGrace &&
      other.message == message &&
      other.recordingPath == recordingPath;

  @override
  int get hashCode => Object.hash(
    name,
    phone,
    email,
    triggerMinutesAfterGrace,
    message,
    recordingPath,
  );

  @override
  String toString() =>
      'OversleepContact($name, +${triggerMinutesAfterGrace}m after grace)';
}

/// How the app reached out — or would have, while delivery is stubbed.
enum ContactChannel { phone, email, log }

/// One record of the app deciding to contact someone about an overslept alarm.
@immutable
class ContactEvent {
  const ContactEvent({
    required this.id,
    required this.sessionId,
    required this.firedAt,
    required this.contactName,
    required this.channel,
    this.detail,
  });

  final String id;
  final String sessionId;
  final DateTime firedAt;
  final String contactName;
  final ContactChannel channel;

  /// What would have been sent, kept so the history can show it.
  final String? detail;

  @override
  bool operator ==(Object other) =>
      other is ContactEvent &&
      other.id == id &&
      other.sessionId == sessionId &&
      other.firedAt == firedAt &&
      other.contactName == contactName &&
      other.channel == channel &&
      other.detail == detail;

  @override
  int get hashCode =>
      Object.hash(id, sessionId, firedAt, contactName, channel, detail);

  @override
  String toString() => 'ContactEvent($contactName, $channel, $firedAt)';
}

ContactChannel contactChannelByName(String? name) {
  for (final channel in ContactChannel.values) {
    if (channel.name == name) return channel;
  }
  return ContactChannel.log;
}
