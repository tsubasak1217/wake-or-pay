import 'package:flutter/foundation.dart';

import 'oversleep_contact.dart';

/// The default line posted to a share target, per spec 11.6. Pure.
///
/// Shorter than the mail: the post already says who it is about on the line
/// above it (the Discord mention, or the profile name), so repeating the name
/// inside the quote would be the app talking twice. [at] is the alarm's own
/// time, filled in at trigger time.
String defaultOversleepShareMessage({required DateTime at}) =>
    '${at.hour.toString().padLeft(2, '0')}:'
    '${at.minute.toString().padLeft(2, '0')} の'
    'アラームを解除できていません。';

/// Where an overslept alarm is announced, per spec 11.6 — the group half of
/// the notification, next to [OversleepContact]'s personal half.
///
/// The webhook ids are the app-wide 共有先 list's ids, not copies: a share
/// target is a URL that either still exists or does not, and a snapshot of a
/// dead one would only post into nowhere. An id with no row behind it is
/// simply skipped when the list is read, so deleting a 共有先 never breaks an
/// alarm that pointed at it.
///
/// [xEnabled] is modelled and never offered: spec 11.1 puts X behind a row
/// that cannot be pressed. Storing the field now means the row that turns it
/// on later needs no migration.
@immutable
class OversleepShare {
  const OversleepShare({
    this.webhookIds = const {},
    this.messageMode = MessageMode.standard,
    this.message,
    this.recordingPath,
    this.recordingWaveform = const [],
    this.xEnabled = false,
  });

  final Set<String> webhookIds;

  final MessageMode messageMode;

  /// The user's own words, used only under [MessageMode.custom].
  final String? message;

  /// A recording copied into the app's own storage, so it survives the
  /// original file being deleted. Attached to the post as an audio file.
  final String? recordingPath;

  /// The loudness of [recordingPath], 0..1, one reading every
  /// [contactWaveformInterval]. Drawn behind the seek bar so the recording has
  /// a shape and not just a length.
  ///
  /// Empty is a real and ordinary value: a device that will not report the
  /// microphone level still records perfectly well, and the bar is simply
  /// drawn flat. Nothing reads this except the drawing.
  final List<double> recordingWaveform;

  /// Always false in stage C. Modelled, never offered.
  final bool xEnabled;

  bool get hasRecording => (recordingPath ?? '').trim().isNotEmpty;

  /// A share with nowhere to post is not a share. The same rule as
  /// [OversleepContact.isUsable]: a message with no destination is a message
  /// that never goes out, so it must not read back as one that would.
  bool get isUsable => webhookIds.isNotEmpty;

  OversleepShare copyWith({
    Set<String>? webhookIds,
    MessageMode? messageMode,
    String? message,
    bool clearMessage = false,
    String? recordingPath,
    bool clearRecordingPath = false,
    List<double>? recordingWaveform,
    bool? xEnabled,
  }) => OversleepShare(
    webhookIds: webhookIds ?? this.webhookIds,
    messageMode: messageMode ?? this.messageMode,
    message: clearMessage ? null : (message ?? this.message),
    recordingPath: clearRecordingPath
        ? null
        : (recordingPath ?? this.recordingPath),
    // A cleared recording takes its waveform with it: there is nothing left
    // for those bars to be the shape of.
    recordingWaveform: clearRecordingPath
        ? const []
        : (recordingWaveform ?? this.recordingWaveform),
    xEnabled: xEnabled ?? this.xEnabled,
  );

  Map<String, dynamic> toJson() => {
    // Sorted so two shares with the same targets serialise identically and a
    // save that changed nothing does not look like a change.
    'webhookIds': webhookIds.toList()..sort(),
    'messageMode': messageMode.name,
    'message': message,
    'recordingPath': recordingPath,
    // Two decimals: a bar is a few pixels tall and nobody can see the third.
    'recordingWaveform': [
      for (final sample in recordingWaveform)
        double.parse(sample.toStringAsFixed(2)),
    ],
    'xEnabled': xEnabled,
  };

  factory OversleepShare.fromJson(Map<String, dynamic> json) => OversleepShare(
    webhookIds: {
      for (final id in (json['webhookIds'] as List?) ?? const [])
        if (id is String && id.isNotEmpty) id,
    },
    messageMode:
        messageModeByName(json['messageMode'] as String?) ??
        MessageMode.standard,
    message: json['message'] as String?,
    recordingPath: json['recordingPath'] as String?,
    recordingWaveform: normalizeWaveform(
      (json['recordingWaveform'] as List?)?.map(
            (v) => (v as num?)?.toDouble() ?? 0.0,
          ) ??
          const <double>[],
    ),
    xEnabled: json['xEnabled'] as bool? ?? false,
  );

  @override
  bool operator ==(Object other) =>
      other is OversleepShare &&
      setEquals(other.webhookIds, webhookIds) &&
      other.messageMode == messageMode &&
      other.message == message &&
      other.recordingPath == recordingPath &&
      listEquals(other.recordingWaveform, recordingWaveform) &&
      other.xEnabled == xEnabled;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(webhookIds),
    messageMode,
    message,
    recordingPath,
    Object.hashAll(recordingWaveform),
    xEnabled,
  );

  @override
  String toString() =>
      'OversleepShare(${webhookIds.length} webhooks, $messageMode, '
      'recording ${recordingPath != null})';
}

/// The body posted at [at]. Pure.
///
/// [MessageMode.custom] with nothing written in it falls back to the default,
/// exactly as the contact's body does: an empty post says nothing.
String oversleepShareBodyFor(OversleepShare share, DateTime at) {
  final custom = share.message?.trim() ?? '';
  return share.messageMode == MessageMode.custom && custom.isNotEmpty
      ? custom
      : defaultOversleepShareMessage(at: at);
}
