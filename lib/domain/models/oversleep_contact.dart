import 'package:flutter/foundation.dart';

/// How long after the grace window runs out the contact is triggered, in
/// minutes.
///
/// **0 is a real choice** since 改訂2: it means the moment the grace runs out,
/// with no further stretch of oversleeping first. The old floor of 1 minute was
/// the app deciding for the user how much rope they get.
const minContactTriggerMinutes = 0;
const maxContactTriggerMinutes = 60;

/// What a new contact starts at: a few minutes of grace-after-grace.
const defaultContactTriggerMinutes = 3;

int normalizeContactTriggerMinutes(int minutes) =>
    minutes.clamp(minContactTriggerMinutes, maxContactTriggerMinutes);

/// What the mail says: the app's own sentence, or the user's.
enum MailMode { standard, custom }

/// What the call says: a synthesised reading of the app's sentence, or the
/// user's own recorded voice.
enum PhoneMode { auto, custom }

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}';

/// The sentence sent when the user has not written one of their own. Pure.
///
/// [name] and [at] are filled in at trigger time, not at edit time, so the
/// stored contact never holds a stale time. The app has no name for its *own*
/// user, so the one name it can put in the sentence is the contact's.
String defaultOversleepMessage({required String name, required DateTime at}) =>
    '$name さんは ${_hhmm(at)} のアラームを解除できていません。寝坊しています。';

/// The default mail body. Same sentence as the voice: one message, two routes.
String defaultOversleepMailMessage({
  required String name,
  required DateTime at,
}) => defaultOversleepMessage(name: name, at: at);

/// The script the automated voice reads when there is no recording.
String defaultOversleepVoiceScript({
  required String name,
  required DateTime at,
}) => defaultOversleepMessage(name: name, at: at);

/// One person to tell about one alarm's oversleeping, per spec 5 as revised.
///
/// One per alarm. Nothing is actually sent yet — [OversleepNotifier] logs the
/// trigger instead.
///
/// The name and the two addresses are a **snapshot** of a 連絡帳 entry, kept
/// here on purpose: deleting that entry from the book leaves this alarm still
/// knowing who to call.
@immutable
class OversleepContact {
  const OversleepContact({
    required this.name,
    this.contactId,
    this.phone,
    this.email,
    this.phoneEnabled = false,
    this.emailEnabled = false,
    this.mailMode = MailMode.standard,
    this.mailMessage,
    this.phoneMode = PhoneMode.auto,
    this.recordingPath,
    this.triggerMinutesAfterGrace = defaultContactTriggerMinutes,
  });

  /// The 連絡帳 entry this was copied from, when it came from the book. null
  /// for a contact written before the book existed.
  final String? contactId;

  final String name;
  final String? phone;
  final String? email;

  /// Whether that route is used at all. A contact with no number can never
  /// have [phoneEnabled] meaningfully on — the editor greys the toggle out.
  final bool phoneEnabled;
  final bool emailEnabled;

  final MailMode mailMode;

  /// The user's own words, used only under [MailMode.custom].
  final String? mailMessage;

  final PhoneMode phoneMode;

  /// A recording copied into the app's own storage, so it survives the
  /// original file being deleted. Used only under [PhoneMode.custom].
  final String? recordingPath;

  /// 0-60. Counted from the end of the grace window, not from the ring.
  final int triggerMinutesAfterGrace;

  bool get hasPhone => (phone ?? '').trim().isNotEmpty;

  bool get hasEmail => (email ?? '').trim().isNotEmpty;

  /// The routes that would actually be used: enabled, and reachable.
  bool get willPhone => phoneEnabled && hasPhone;

  bool get willEmail => emailEnabled && hasEmail;

  /// A contact with no name is not a contact. The editor refuses to save one,
  /// and this is the same rule for anything read back off disk.
  bool get isUsable => name.trim().isNotEmpty;

  OversleepContact copyWith({
    String? contactId,
    bool clearContactId = false,
    String? name,
    String? phone,
    bool clearPhone = false,
    String? email,
    bool clearEmail = false,
    bool? phoneEnabled,
    bool? emailEnabled,
    MailMode? mailMode,
    String? mailMessage,
    bool clearMailMessage = false,
    PhoneMode? phoneMode,
    String? recordingPath,
    bool clearRecordingPath = false,
    int? triggerMinutesAfterGrace,
  }) => OversleepContact(
    contactId: clearContactId ? null : (contactId ?? this.contactId),
    name: name ?? this.name,
    phone: clearPhone ? null : (phone ?? this.phone),
    email: clearEmail ? null : (email ?? this.email),
    phoneEnabled: phoneEnabled ?? this.phoneEnabled,
    emailEnabled: emailEnabled ?? this.emailEnabled,
    mailMode: mailMode ?? this.mailMode,
    mailMessage: clearMailMessage ? null : (mailMessage ?? this.mailMessage),
    phoneMode: phoneMode ?? this.phoneMode,
    recordingPath: clearRecordingPath
        ? null
        : (recordingPath ?? this.recordingPath),
    triggerMinutesAfterGrace:
        triggerMinutesAfterGrace ?? this.triggerMinutesAfterGrace,
  );

  Map<String, dynamic> toJson() => {
    'contactId': contactId,
    'name': name,
    'phone': phone,
    'email': email,
    'phoneEnabled': phoneEnabled,
    'emailEnabled': emailEnabled,
    'mailMode': mailMode.name,
    'mailMessage': mailMessage,
    'phoneMode': phoneMode.name,
    'recordingPath': recordingPath,
    'triggerMinutesAfterGrace': normalizeContactTriggerMinutes(
      triggerMinutesAfterGrace,
    ),
  };

  /// Reads both shapes of the JSON blob.
  ///
  /// The pre-改訂2 shape had one `message` doing double duty as the mail body
  /// and the voice script, and a `recordingPath` that replaced the script when
  /// present. Those become **custom** mail and a **custom** recording, which is
  /// what they meant; the routes are switched on for whichever address exists,
  /// which is what the old app would have done with them.
  ///
  /// Like every other bound in this app the trigger window is re-clamped on the
  /// way in, so a hand edited row cannot push it past an hour.
  factory OversleepContact.fromJson(Map<String, dynamic> json) {
    final phone = json['phone'] as String?;
    final email = json['email'] as String?;
    final mailMessage =
        json['mailMessage'] as String? ?? json['message'] as String?;
    final recordingPath = json['recordingPath'] as String?;
    final hasMail = (mailMessage ?? '').trim().isNotEmpty;
    final hasRecording = (recordingPath ?? '').trim().isNotEmpty;

    return OversleepContact(
      contactId: json['contactId'] as String?,
      name: json['name'] as String? ?? '',
      phone: phone,
      email: email,
      phoneEnabled:
          json['phoneEnabled'] as bool? ?? (phone ?? '').trim().isNotEmpty,
      emailEnabled:
          json['emailEnabled'] as bool? ?? (email ?? '').trim().isNotEmpty,
      mailMode:
          _byName(MailMode.values, json['mailMode'] as String?) ??
          (hasMail ? MailMode.custom : MailMode.standard),
      mailMessage: mailMessage,
      phoneMode:
          _byName(PhoneMode.values, json['phoneMode'] as String?) ??
          (hasRecording ? PhoneMode.custom : PhoneMode.auto),
      recordingPath: recordingPath,
      triggerMinutesAfterGrace: normalizeContactTriggerMinutes(
        json['triggerMinutesAfterGrace'] as int? ??
            defaultContactTriggerMinutes,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OversleepContact &&
      other.contactId == contactId &&
      other.name == name &&
      other.phone == phone &&
      other.email == email &&
      other.phoneEnabled == phoneEnabled &&
      other.emailEnabled == emailEnabled &&
      other.mailMode == mailMode &&
      other.mailMessage == mailMessage &&
      other.phoneMode == phoneMode &&
      other.recordingPath == recordingPath &&
      other.triggerMinutesAfterGrace == triggerMinutesAfterGrace;

  @override
  int get hashCode => Object.hash(
    contactId,
    name,
    phone,
    email,
    phoneEnabled,
    emailEnabled,
    mailMode,
    mailMessage,
    phoneMode,
    recordingPath,
    triggerMinutesAfterGrace,
  );

  @override
  String toString() =>
      'OversleepContact($name, +${triggerMinutesAfterGrace}m after grace, '
      'phone $phoneEnabled/$phoneMode, mail $emailEnabled/$mailMode)';
}

/// null in, null out; an unknown name also gives null, so a row written by a
/// future version cannot crash a read.
T? _byName<T extends Enum>(List<T> values, String? name) {
  if (name == null) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

/// The body of the mail that would go out at [at]. Pure.
String mailBodyFor(OversleepContact contact, DateTime at) {
  final custom = contact.mailMessage?.trim() ?? '';
  return contact.mailMode == MailMode.custom && custom.isNotEmpty
      ? custom
      : defaultOversleepMailMessage(name: contact.name, at: at);
}

/// What the call would play: the recording's path under
/// [PhoneMode.custom], and otherwise the script the voice reads. Pure.
({String? recordingPath, String? script}) callContentFor(
  OversleepContact contact,
  DateTime at,
) {
  final path = contact.recordingPath?.trim() ?? '';
  if (contact.phoneMode == PhoneMode.custom && path.isNotEmpty) {
    return (recordingPath: path, script: null);
  }
  return (
    recordingPath: null,
    script: defaultOversleepVoiceScript(name: contact.name, at: at),
  );
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
