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

/// The longest a custom recording may run.
///
/// A fixed limit rather than a setting: the recording is played down a phone
/// line to somebody who is being told to go and wake a person up, and half a
/// minute is already more than that takes. It also bounds the file, the
/// waveform, and — more to the point — how long the recorder can sit open on
/// the microphone if the user walks away from it.
const maxContactRecordingSeconds = 30;

const maxContactRecordingDuration = Duration(
  seconds: maxContactRecordingSeconds,
);

/// How many amplitude readings make up a stored waveform.
///
/// [maxContactRecordingDuration] divided by [contactWaveformInterval]: one bar
/// per quarter second, which is fine enough to look like speech and coarse
/// enough that the whole thing is a few hundred bytes of JSON.
const contactWaveformSamples = 120;

const contactWaveformInterval = Duration(milliseconds: 250);

/// Amplitudes read back off disk, made safe to draw. Pure.
///
/// Anything outside 0..1 is clamped and anything past the limit is dropped: a
/// hand edited row must not be able to paint outside the widget.
List<double> normalizeWaveform(Iterable<double> samples) => [
  for (final sample in samples.take(contactWaveformSamples))
    sample.isFinite ? sample.clamp(0.0, 1.0).toDouble() : 0.0,
];

/// What the mail says: the app's own sentence, or the user's.
enum MailMode { standard, custom }

/// What the call says: a synthesised reading of the app's sentence, or the
/// user's own recorded voice.
enum PhoneMode { auto, custom }

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}';

/// Who the message is about when the user has not told the app their name.
///
/// The message goes *to* the contact, so falling back to the contact's own
/// name would address them about themselves. A generic subject is wrong-ish;
/// naming the recipient is simply wrong.
const oversleepUserNameFallback = 'Wake or Pay の利用者';

/// The name the default message puts in the subject position: the app's user,
/// or [oversleepUserNameFallback] when they have not set one. Pure.
String oversleepSubjectName(String userName) {
  final trimmed = userName.trim();
  return trimmed.isEmpty ? oversleepUserNameFallback : trimmed;
}

/// The sentence sent when the user has not written one of their own. Pure.
///
/// The subject is the **app's user** — the one who is oversleeping — not the
/// contact, who is the one being told. [at] is filled in at trigger time, not
/// at edit time, so the stored contact never holds a stale time.
String defaultOversleepMessage({
  required String userName,
  required DateTime at,
}) =>
    '${oversleepSubjectName(userName)} さんは ${_hhmm(at)} の'
    'アラームを解除できていません。寝坊しています。';

/// The default mail body. The same sentence as the voice, under a subject tag
/// so it is recognisable in an inbox.
String defaultOversleepMailMessage({
  required String userName,
  required DateTime at,
}) => '【Wake or Pay】${defaultOversleepMessage(userName: userName, at: at)}';

/// The script the automated voice reads when there is no recording. No tag: a
/// spoken 「【Wake or Pay】」 is noise.
String defaultOversleepVoiceScript({
  required String userName,
  required DateTime at,
}) => defaultOversleepMessage(userName: userName, at: at);

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
    this.recordingWaveform = const [],
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

  /// The loudness of [recordingPath], 0..1, one reading every
  /// [contactWaveformInterval]. Drawn behind the seek bar so the recording has
  /// a shape and not just a length.
  ///
  /// Empty is a real and ordinary value: a device that will not report the
  /// microphone level still records perfectly well, and the bar is simply
  /// drawn flat. Nothing reads this except the drawing.
  final List<double> recordingWaveform;

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
    List<double>? recordingWaveform,
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
    // A cleared recording takes its waveform with it: there is nothing left
    // for those bars to be the shape of.
    recordingWaveform: clearRecordingPath
        ? const []
        : (recordingWaveform ?? this.recordingWaveform),
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
    // Two decimals: a bar is a few pixels tall and nobody can see the third.
    'recordingWaveform': [
      for (final sample in recordingWaveform)
        double.parse(sample.toStringAsFixed(2)),
    ],
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
      recordingWaveform: normalizeWaveform(
        (json['recordingWaveform'] as List?)?.map(
              (v) => (v as num?)?.toDouble() ?? 0.0,
            ) ??
            const <double>[],
      ),
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
      listEquals(other.recordingWaveform, recordingWaveform) &&
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
    Object.hashAll(recordingWaveform),
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
///
/// [userName] is only reached for by the default body; a custom one is the
/// user's own words and is used exactly as written.
String mailBodyFor(
  OversleepContact contact,
  DateTime at, {
  required String userName,
}) {
  final custom = contact.mailMessage?.trim() ?? '';
  return contact.mailMode == MailMode.custom && custom.isNotEmpty
      ? custom
      : defaultOversleepMailMessage(userName: userName, at: at);
}

/// What the call would play: the recording's path under
/// [PhoneMode.custom], and otherwise the script the voice reads. Pure.
({String? recordingPath, String? script}) callContentFor(
  OversleepContact contact,
  DateTime at, {
  required String userName,
}) {
  final path = contact.recordingPath?.trim() ?? '';
  if (contact.phoneMode == PhoneMode.custom && path.isNotEmpty) {
    return (recordingPath: path, script: null);
  }
  return (
    recordingPath: null,
    script: defaultOversleepVoiceScript(userName: userName, at: at),
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
