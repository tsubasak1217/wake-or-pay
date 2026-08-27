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
/// A fixed limit rather than a setting: the recording is attached to a message
/// somebody reads while being told to go and wake a person up, and half a
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

/// What the written message says: the app's own sentence, or the user's.
///
/// One mode for both mail and SMS since 改訂4. They carry the same body — a
/// user who has written their own words has written them once — so two modes
/// would only ever be a way for the two routes to disagree.
enum MessageMode { standard, custom }

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

/// The default mail body. The same sentence as the SMS, under a subject tag so
/// it is recognisable in an inbox.
String defaultOversleepMailMessage({
  required String userName,
  required DateTime at,
}) => '【Wake or Pay】${defaultOversleepMessage(userName: userName, at: at)}';

/// The default SMS body. No tag: an SMS has no subject line to recognise it
/// by, and 「【Wake or Pay】」 in the middle of a text message is noise.
String defaultOversleepSmsMessage({
  required String userName,
  required DateTime at,
}) => defaultOversleepMessage(userName: userName, at: at);

/// One person to tell about one alarm's oversleeping, per spec 11.4.
///
/// One per alarm. Nothing is actually sent yet — `OversleepNotifier` logs the
/// trigger instead.
///
/// The name and the two addresses are a **snapshot** of a 連絡帳 entry, kept
/// here on purpose: deleting that entry from the book leaves this alarm still
/// knowing who to call.
///
/// Since 改訂4 the phone route places a call and plays nothing — the point is
/// that the contact's own voice comes out of the speaker — so the automated
/// voice and its recording are gone, and the delay moved up to the alarm,
/// which shares it with the 寝坊の共有.
@immutable
class OversleepContact {
  const OversleepContact({
    required this.name,
    this.contactId,
    this.phone,
    this.email,
    this.phoneEnabled = false,
    this.emailEnabled = false,
    this.smsEnabled = false,
    this.messageMode = MessageMode.standard,
    this.message,
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

  /// SMS, to the same number [phoneEnabled] would ring.
  final bool smsEnabled;

  final MessageMode messageMode;

  /// The user's own words, used only under [MessageMode.custom]. One body for
  /// both mail and SMS.
  final String? message;

  bool get hasPhone => (phone ?? '').trim().isNotEmpty;

  bool get hasEmail => (email ?? '').trim().isNotEmpty;

  /// The routes that would actually be used: enabled, and reachable.
  bool get willPhone => phoneEnabled && hasPhone;

  bool get willEmail => emailEnabled && hasEmail;

  bool get willSms => smsEnabled && hasPhone;

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
    bool? smsEnabled,
    MessageMode? messageMode,
    String? message,
    bool clearMessage = false,
  }) => OversleepContact(
    contactId: clearContactId ? null : (contactId ?? this.contactId),
    name: name ?? this.name,
    phone: clearPhone ? null : (phone ?? this.phone),
    email: clearEmail ? null : (email ?? this.email),
    phoneEnabled: phoneEnabled ?? this.phoneEnabled,
    emailEnabled: emailEnabled ?? this.emailEnabled,
    smsEnabled: smsEnabled ?? this.smsEnabled,
    messageMode: messageMode ?? this.messageMode,
    message: clearMessage ? null : (message ?? this.message),
  );

  Map<String, dynamic> toJson() => {
    'contactId': contactId,
    'name': name,
    'phone': phone,
    'email': email,
    'phoneEnabled': phoneEnabled,
    'emailEnabled': emailEnabled,
    'smsEnabled': smsEnabled,
    'messageMode': messageMode.name,
    'message': message,
  };

  /// Reads every shape of the JSON blob this column has ever held.
  ///
  /// The pre-改訂2 shape had one `message` doing double duty as the mail body
  /// and the voice script; 改訂2 split it into `mailMode`/`mailMessage` beside
  /// a `phoneMode`/`recordingPath`. Both collapse back into the one body and
  /// the one mode this class now has.
  ///
  /// `phoneMode`, `recordingPath` and `recordingWaveform` are **read and
  /// discarded**, per spec 11.4: the automated voice is gone, so a recording
  /// made for it has nothing left to play on. The files themselves are swept
  /// up at startup by `LegacyRecordingCleanup`.
  ///
  /// `triggerMinutesAfterGrace` is likewise not a field here any more — it
  /// belongs to the alarm, which shares it with the 共有. The mapper digs it
  /// out of the raw map on the way in; see `legacyTriggerMinutesIn`.
  ///
  /// SMS defaults to **off** for an old row: nobody who wrote one was asked
  /// whether they wanted a text message, so the app must not decide they were.
  factory OversleepContact.fromJson(Map<String, dynamic> json) {
    final phone = json['phone'] as String?;
    final email = json['email'] as String?;
    final message =
        json['message'] as String? ?? json['mailMessage'] as String?;
    final hasMessage = (message ?? '').trim().isNotEmpty;

    return OversleepContact(
      contactId: json['contactId'] as String?,
      name: json['name'] as String? ?? '',
      phone: phone,
      email: email,
      phoneEnabled:
          json['phoneEnabled'] as bool? ?? (phone ?? '').trim().isNotEmpty,
      emailEnabled:
          json['emailEnabled'] as bool? ?? (email ?? '').trim().isNotEmpty,
      smsEnabled: json['smsEnabled'] as bool? ?? false,
      messageMode:
          messageModeByName(
            json['messageMode'] as String? ?? json['mailMode'] as String?,
          ) ??
          (hasMessage ? MessageMode.custom : MessageMode.standard),
      message: message,
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
      other.smsEnabled == smsEnabled &&
      other.messageMode == messageMode &&
      other.message == message;

  @override
  int get hashCode => Object.hash(
    contactId,
    name,
    phone,
    email,
    phoneEnabled,
    emailEnabled,
    smsEnabled,
    messageMode,
    message,
  );

  @override
  String toString() =>
      'OversleepContact($name, phone $phoneEnabled, sms $smsEnabled, '
      'mail $emailEnabled, $messageMode)';
}

/// null in, null out; an unknown name also gives null, so a row written by a
/// future version cannot crash a read.
MessageMode? messageModeByName(String? name) {
  if (name == null) return null;
  for (final value in MessageMode.values) {
    if (value.name == name) return value;
  }
  return null;
}

/// The custom body [contact] holds, or null when there is nothing usable
/// there — an empty custom message is the same as never having written one.
String? _customBody(OversleepContact contact) {
  if (contact.messageMode != MessageMode.custom) return null;
  final custom = contact.message?.trim() ?? '';
  return custom.isEmpty ? null : custom;
}

/// The body of the mail that would go out at [at]. Pure.
///
/// [userName] is only reached for by the default body; a custom one is the
/// user's own words and is used exactly as written.
String oversleepMailBodyFor(
  OversleepContact contact,
  DateTime at, {
  required String userName,
}) =>
    _customBody(contact) ??
    defaultOversleepMailMessage(userName: userName, at: at);

/// The body of the SMS that would go out at [at]. Pure.
///
/// The same custom words as the mail — the user wrote one message — and the
/// untagged default when they wrote none.
String oversleepSmsBodyFor(
  OversleepContact contact,
  DateTime at, {
  required String userName,
}) =>
    _customBody(contact) ??
    defaultOversleepSmsMessage(userName: userName, at: at);

/// [raw] as a dialable / textable string. Pure.
///
/// People write numbers the way they read them — 090-1234-5678, (03) 1234
/// 5678, ＋８１… — and both `SmsManager` and `ACTION_CALL` want the digits. A
/// leading `+` is the one non-digit that carries meaning, so it survives in
/// its ASCII form; everything else goes, and full-width digits fold onto
/// ASCII, because a number pasted out of a Japanese page is routinely written
/// in them.
///
/// Nothing here validates. A number that is not a number comes back short or
/// empty, and the platform is the authority on whether it can be reached.
String normalizePhoneNumber(String raw) {
  final buffer = StringBuffer();
  for (final rune in raw.trim().runes) {
    if (rune >= 0x30 && rune <= 0x39) {
      buffer.writeCharCode(rune);
    } else if (rune >= 0xFF10 && rune <= 0xFF19) {
      buffer.writeCharCode(rune - 0xFF10 + 0x30);
    } else if (buffer.isEmpty && (rune == 0x2B || rune == 0xFF0B)) {
      buffer.write('+');
    }
  }
  return buffer.toString();
}

/// The whole SMS sent to one contact about one overslept alarm. Pure.
({String to, String body}) buildOversleepSms(
  OversleepContact contact,
  DateTime at, {
  required String userName,
}) => (
  to: normalizePhoneNumber(contact.phone ?? ''),
  body: oversleepSmsBodyFor(contact, at, userName: userName),
);

/// How the app reached out — or would have, while delivery is stubbed.
enum ContactChannel { phone, sms, email, discord, log }

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

  /// Who — or what — was told. A share-only alarm files this under the same
  /// label the countdown said out loud, e.g. 「Discord 2件」.
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
