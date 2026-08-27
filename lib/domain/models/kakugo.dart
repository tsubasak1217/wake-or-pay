import 'package:flutter/foundation.dart';

/// What the user puts up as collateral. Only [coin] exists in the MVP.
enum HostageType { coin }

/// The bounds the editor offers, and the bounds every read is clamped to.
const minKakugoRate = 1;
const maxKakugoRate = 1000;
const minKakugoCap = 100;
const maxKakugoCap = 10000;

/// What one press of snooze costs in kakugo mode. 0 = snoozing is free even
/// under a pledge, which is the rule every row written before stage B was
/// saved under.
const minSnoozePenalty = 0;
const maxSnoozePenalty = 1000;

int normalizeKakugoRate(int rate) => rate.clamp(minKakugoRate, maxKakugoRate);
int normalizeKakugoCap(int cap) => cap.clamp(minKakugoCap, maxKakugoCap);
int normalizeSnoozePenalty(int penalty) =>
    penalty.clamp(minSnoozePenalty, maxSnoozePenalty);

/// The user's pledge for one alarm: how much burns per minute, and the most
/// a single ring may ever cost.
@immutable
class Kakugo {
  const Kakugo({
    this.hostage = HostageType.coin,
    required this.ratePerMinute,
    required this.cap,
    this.snoozePenalty = 0,
    this.snoozeResetsClock = false,
  });

  final HostageType hostage;
  final int ratePerMinute;
  final int cap;

  /// Coins burned per press of the snooze button. Snooze itself stays free and
  /// ungated — this is a punishment the user chose, not a price.
  final int snoozePenalty;

  /// false — the default and the rule pre-stage-B rows were written under —
  /// keeps billing minutes from `firedAt`, so snoozing never stops the burn.
  /// true restarts the clock (and the grace window) at each re-ring.
  final bool snoozeResetsClock;

  /// Rate presets offered in the editor. Custom values are allowed too.
  static const ratePresets = <int>[1, 10, 50, 100, 500];

  Kakugo copyWith({
    HostageType? hostage,
    int? ratePerMinute,
    int? cap,
    int? snoozePenalty,
    bool? snoozeResetsClock,
  }) => Kakugo(
    hostage: hostage ?? this.hostage,
    ratePerMinute: ratePerMinute ?? this.ratePerMinute,
    cap: cap ?? this.cap,
    snoozePenalty: snoozePenalty ?? this.snoozePenalty,
    snoozeResetsClock: snoozeResetsClock ?? this.snoozeResetsClock,
  );

  Map<String, dynamic> toJson() => {
    'hostage': hostage.name,
    'ratePerMinute': ratePerMinute,
    'cap': cap,
    'snoozePenalty': snoozePenalty,
    'snoozeResetsClock': snoozeResetsClock,
  };

  factory Kakugo.fromJson(Map<String, dynamic> json) => Kakugo(
    hostage: HostageType.values.firstWhere(
      (h) => h.name == json['hostage'],
      orElse: () => HostageType.coin,
    ),
    ratePerMinute: json['ratePerMinute'] as int,
    cap: json['cap'] as int,
    snoozePenalty: normalizeSnoozePenalty(json['snoozePenalty'] as int? ?? 0),
    snoozeResetsClock: json['snoozeResetsClock'] as bool? ?? false,
  );

  @override
  bool operator ==(Object other) =>
      other is Kakugo &&
      other.hostage == hostage &&
      other.ratePerMinute == ratePerMinute &&
      other.cap == cap &&
      other.snoozePenalty == snoozePenalty &&
      other.snoozeResetsClock == snoozeResetsClock;

  @override
  int get hashCode => Object.hash(
    hostage,
    ratePerMinute,
    cap,
    snoozePenalty,
    snoozeResetsClock,
  );

  @override
  String toString() =>
      'Kakugo($hostage, $ratePerMinute/min, cap $cap, '
      'snooze $snoozePenalty${snoozeResetsClock ? ' reset' : ''})';
}

/// What the editor puts up the first time 覚悟 is switched on.
const defaultKakugo = Kakugo(ratePerMinute: 100, cap: 1000, snoozePenalty: 50);
