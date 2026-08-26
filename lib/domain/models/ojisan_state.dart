import 'package:flutter/foundation.dart';

@immutable
class OjisanState {
  const OjisanState({this.totalOversleeps = 0, this.totalEarned = 0});

  /// Number of sessions that ended as failed.
  final int totalOversleeps;

  /// Coins burned across all sessions.
  final int totalEarned;

  OjisanState copyWith({int? totalOversleeps, int? totalEarned}) => OjisanState(
    totalOversleeps: totalOversleeps ?? this.totalOversleeps,
    totalEarned: totalEarned ?? this.totalEarned,
  );

  Map<String, dynamic> toJson() => {
    'totalOversleeps': totalOversleeps,
    'totalEarned': totalEarned,
  };

  factory OjisanState.fromJson(Map<String, dynamic> json) => OjisanState(
    totalOversleeps: json['totalOversleeps'] as int,
    totalEarned: json['totalEarned'] as int,
  );

  @override
  bool operator ==(Object other) =>
      other is OjisanState &&
      other.totalOversleeps == totalOversleeps &&
      other.totalEarned == totalEarned;

  @override
  int get hashCode => Object.hash(totalOversleeps, totalEarned);

  @override
  String toString() =>
      'OjisanState(oversleeps $totalOversleeps, earned $totalEarned)';
}
