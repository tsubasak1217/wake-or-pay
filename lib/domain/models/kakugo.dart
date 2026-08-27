import 'package:flutter/foundation.dart';

/// What the user puts up as collateral. Only [coin] exists in the MVP.
enum HostageType { coin }

/// The bounds the editor offers, and the bounds every read is clamped to.
const minKakugoRate = 1;
const maxKakugoRate = 1000;
const minKakugoCap = 100;
const maxKakugoCap = 10000;

int normalizeKakugoRate(int rate) => rate.clamp(minKakugoRate, maxKakugoRate);
int normalizeKakugoCap(int cap) => cap.clamp(minKakugoCap, maxKakugoCap);

/// The user's pledge for one alarm: how much burns per minute, and the most
/// a single ring may ever cost.
@immutable
class Kakugo {
  const Kakugo({
    this.hostage = HostageType.coin,
    required this.ratePerMinute,
    required this.cap,
  });

  final HostageType hostage;
  final int ratePerMinute;
  final int cap;

  /// Rate presets offered in the editor. Custom values are allowed too.
  static const ratePresets = <int>[1, 10, 50, 100, 500];

  Kakugo copyWith({HostageType? hostage, int? ratePerMinute, int? cap}) =>
      Kakugo(
        hostage: hostage ?? this.hostage,
        ratePerMinute: ratePerMinute ?? this.ratePerMinute,
        cap: cap ?? this.cap,
      );

  Map<String, dynamic> toJson() => {
    'hostage': hostage.name,
    'ratePerMinute': ratePerMinute,
    'cap': cap,
  };

  factory Kakugo.fromJson(Map<String, dynamic> json) => Kakugo(
    hostage: HostageType.values.firstWhere(
      (h) => h.name == json['hostage'],
      orElse: () => HostageType.coin,
    ),
    ratePerMinute: json['ratePerMinute'] as int,
    cap: json['cap'] as int,
  );

  @override
  bool operator ==(Object other) =>
      other is Kakugo &&
      other.hostage == hostage &&
      other.ratePerMinute == ratePerMinute &&
      other.cap == cap;

  @override
  int get hashCode => Object.hash(hostage, ratePerMinute, cap);

  @override
  String toString() => 'Kakugo($hostage, $ratePerMinute/min, cap $cap)';
}
