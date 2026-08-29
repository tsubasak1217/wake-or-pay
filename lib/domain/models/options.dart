import 'package:flutter/foundation.dart';

import 'kakugo.dart';

/// App-wide options — オプション, the sheet behind the ⚙ in the header.
///
/// Not settings-of-the-theme and not profile: these are the knobs that change
/// what the *app* will let you do. Today there is exactly one, and it is the
/// dangerous one.
@immutable
class Options {
  const Options({this.capCeiling = maxKakugoCap});

  /// The highest 上限金額 the 覚悟 editor will offer. Raising it is a decision
  /// the user confirms; every stored cap is still clamped to
  /// [absoluteMaxKakugoCap] and never to this.
  final int capCeiling;

  Options copyWith({int? capCeiling}) =>
      Options(capCeiling: capCeiling ?? this.capCeiling);

  @override
  bool operator ==(Object other) =>
      other is Options && other.capCeiling == capCeiling;

  @override
  int get hashCode => capCeiling.hashCode;

  @override
  String toString() => 'Options(capCeiling: $capCeiling)';
}
