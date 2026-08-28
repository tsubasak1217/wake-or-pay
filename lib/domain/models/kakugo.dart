import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// What the user puts up as collateral. Only [coin] exists in the MVP.
enum HostageType { coin }

/// The bounds the editor offers, and the bounds every read is clamped to.
///
/// The rate starts at 0: a pledge whose whole punishment is that somebody gets
/// phoned is a real pledge, and forcing at least one coin a minute onto it
/// would be the app inventing a stake the user did not choose.
///
/// The editor bounds the rate by the alarm's *own* 上限金額 — no penalty may be
/// set above the most that alarm can ever cost — so [maxKakugoRate] is only the
/// ceiling of that bound, reached when the cap itself is at its maximum.
const minKakugoRate = 0;
const maxKakugoRate = maxKakugoCap;
const minKakugoCap = 100;
const maxKakugoCap = 10000;

/// What one press of snooze costs in kakugo mode. 0 = snoozing is free even
/// under a pledge, which is the rule every row written before stage B was
/// saved under.
///
/// Bounded by the alarm's own 上限金額 in the editor, exactly like the rate;
/// [maxSnoozePenalty] is the ceiling of that bound and the absolute clamp every
/// stored value is read through.
const minSnoozePenalty = 0;
const maxSnoozePenalty = maxKakugoCap;

int normalizeKakugoRate(int rate) => rate.clamp(minKakugoRate, maxKakugoRate);
int normalizeKakugoCap(int cap) => cap.clamp(minKakugoCap, maxKakugoCap);
int normalizeSnoozePenalty(int penalty) =>
    penalty.clamp(minSnoozePenalty, maxSnoozePenalty);

/// [kakugo] with its per-minute rate and snooze penalty cut down to [cap]
/// (and cap itself normalised). Pure. Used when the cap is lowered so no
/// penalty can be set above the most an alarm may cost.
Kakugo withCap(Kakugo kakugo, int cap) {
  final normalized = normalizeKakugoCap(cap);
  return kakugo.copyWith(
    cap: normalized,
    ratePerMinute: math.min(kakugo.ratePerMinute, normalized),
    snoozePenalty: math.min(kakugo.snoozePenalty, normalized),
  );
}

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
///
/// `snoozeResetsClock: true` is the **default for new alarms** (改訂5): the safe,
/// pausing mode, so snoozed time never bleeds coins while the user is up but not
/// yet paying attention — only the per-press snooze penalty applies. Continuing
/// to bill from `firedAt` through a snooze is now the deliberate opt-in.
///
/// This is only the seed for *new* alarms: the constructor default and every
/// deserialiser stay `false`, so a stored row keeps whatever it was saved with.
const defaultKakugo = Kakugo(
  ratePerMinute: 100,
  cap: 1000,
  snoozePenalty: 50,
  snoozeResetsClock: true,
);
