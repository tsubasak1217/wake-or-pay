import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// What the user puts up as collateral: the in-app coins, or the card
/// registered in プロフィール › クレジットカードを人質にする.
///
/// **1 コイン = 1 円.** Every kakugo amount — the rate, the snooze penalty, the
/// cap — is stored as one integer and read as coins or as yen depending on this
/// enum alone. Nothing converts, because there is nothing to convert: the
/// numbers the editor writes are the numbers the card is charged.
enum HostageType {
  /// Nothing is at stake. 連絡だけの覚悟: the alarm still judges the morning and
  /// still tells whoever it was told to tell, and the loss is always 0.
  none,
  coin,
  card;

  /// What the 人質 row shows.
  String get label => switch (this) {
    HostageType.none => 'なし',
    HostageType.coin => 'コイン',
    HostageType.card => 'クレジットカード',
  };

  /// The unit every amount under this pledge is read in. [none] has no amounts
  /// to read — every row that would use a unit is hidden — so it answers
  /// コイン rather than inventing a word for a number nobody sees.
  String get unit => switch (this) {
    HostageType.none || HostageType.coin => 'コイン',
    HostageType.card => '円',
  };

  /// Whether oversleeping under this 人質 can cost anything at all.
  bool get burns => this != HostageType.none;
}

/// The bounds the editor offers, and the bounds every read is clamped to.
///
/// The rate starts at 10, not at 0. 「連絡だけの覚悟」 — a pledge whose whole
/// punishment is that somebody gets told — is now said by choosing
/// [HostageType.none], not by setting a price of nothing against a hostage that
/// would still be named. A rate below this in stored data is exactly that older
/// spelling, and is read back as [HostageType.none]; see [Kakugo.fromJson].
///
/// The editor bounds the rate by the alarm's *own* 上限金額 — no penalty may be
/// set above the most that alarm can ever cost — so [maxKakugoRate] is only the
/// ceiling of that bound, reached when the cap itself is at its maximum.
const minKakugoRate = 10;
const maxKakugoRate = absoluteMaxKakugoCap;
const minKakugoCap = 100;

/// The ceiling the editor offers **out of the box**, and the default of
/// `Options.capCeiling` — オプション › 危険な設定 › 上限金額の最大値 can raise it.
const maxKakugoCap = 10000;

/// The hard ceiling no stored cap may ever exceed, whatever the setting says.
///
/// Deliberately *not* the user's setting: [normalizeKakugoCap] is what every
/// read goes through, so clamping to the setting would silently rewrite an
/// alarm saved under a higher ceiling the moment the ceiling came back down.
/// The setting bounds what the editor lets you *choose*; this bounds what the
/// app will ever *believe*.
const absoluteMaxKakugoCap = 1000000;

/// 上限金額の最大値 as the store and the screen agree to hold it: any integer the
/// user types, brought inside `[1, absoluteMaxKakugoCap]`.
///
/// The floor is 1, not [minKakugoCap]: the field is free input, and a typed 1 is
/// a legible answer that must not be silently inflated. Keeping the editor's
/// slider sane is [effectiveCapCeiling]'s job, not this one's.
int normalizeCapCeiling(int v) => v.clamp(1, absoluteMaxKakugoCap);

/// The ceiling one alarm's 上限金額 may be edited up to: the user's [setting],
/// the editor's own floor, or the cap the alarm already carries — whichever is
/// largest.
///
/// Pure. An alarm saved when the ceiling was 100,000 keeps showing and editing
/// its 50,000 cap after the ceiling is lowered back to 10,000 — the editor
/// never drags a saved pledge down on its own. [minKakugoCap] is in the max()
/// because the setting is free input: a user who types 1 must not hand the
/// slider a max below its own min.
int effectiveCapCeiling(int setting, int currentCap) => math.max(
  math.max(normalizeCapCeiling(setting), minKakugoCap),
  currentCap,
);

/// What one press of snooze costs in kakugo mode. 0 = snoozing is free even
/// under a pledge, which is the rule every row written before stage B was
/// saved under.
///
/// Bounded by the alarm's own 上限金額 in the editor, exactly like the rate;
/// [maxSnoozePenalty] is the ceiling of that bound and the absolute clamp every
/// stored value is read through.
const minSnoozePenalty = 0;
const maxSnoozePenalty = absoluteMaxKakugoCap;

int normalizeKakugoRate(int rate) => rate.clamp(minKakugoRate, maxKakugoRate);

/// The 人質 a stored pledge reads back as, from the name that was written down
/// and the rate it was written beside. Pure — and the **one** place both
/// [Kakugo.fromJson] and the Drift mapper get this answer from.
///
/// * A missing or unrecognised name reads as [HostageType.coin]: every row
///   written before カード人質 existed was written when coins were the only
///   thing that could burn, and that is the rule it was saved under.
/// * A rate below [minKakugoRate] reads as [HostageType.none] whatever the name
///   says. 「0 コイン/分」 was how 連絡だけの覚悟 used to be written down; rounding
///   it up to 10 would start burning coins nobody pledged.
HostageType hostageFor(String? name, int ratePerMinute) {
  if (ratePerMinute < minKakugoRate) return HostageType.none;
  return HostageType.values.firstWhere(
    (h) => h.name == name,
    orElse: () => HostageType.coin,
  );
}
/// Clamped to [absoluteMaxKakugoCap], never to the user's ceiling setting —
/// see the note on that constant.
int normalizeKakugoCap(int cap) => cap.clamp(minKakugoCap, absoluteMaxKakugoCap);
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
    hostage: hostageFor(
      json['hostage'] as String?,
      json['ratePerMinute'] as int,
    ),
    // Kept as written, never rounded up to [minKakugoRate]: a rate below the
    // bound is what makes [hostageFor] read the row as 人質なし, and a pledge
    // that costs nothing must not be turned into one that costs ten a minute.
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
/// `hostage: none` is likewise the default for **new** pledges: switching 覚悟
/// on puts nothing at stake until the user says what the stake is. The numbers
/// below are seeded anyway, so choosing コイン or クレジットカード one row down
/// arrives at a pledge that already reads sensibly instead of at zeroes.
///
/// This is only the seed for *new* alarms: the constructor default and every
/// deserialiser stay `false` (and `coin`), so a stored row keeps whatever it
/// was saved with.
const defaultKakugo = Kakugo(
  hostage: HostageType.none,
  ratePerMinute: 100,
  cap: 1000,
  snoozePenalty: 50,
  snoozeResetsClock: true,
);
