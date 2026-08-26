import 'package:flutter/foundation.dart';

import '../../app/theme.dart';

@immutable
class Settings {
  const Settings({
    this.themeId = AppThemes.defaultThemeId,
    this.unlockedThemeIds = const {AppThemes.defaultThemeId},
  });

  final String themeId;
  final Set<String> unlockedThemeIds;

  Settings copyWith({String? themeId, Set<String>? unlockedThemeIds}) =>
      Settings(
        themeId: themeId ?? this.themeId,
        unlockedThemeIds: unlockedThemeIds ?? this.unlockedThemeIds,
      );

  Map<String, dynamic> toJson() => {
    'themeId': themeId,
    'unlockedThemeIds': (unlockedThemeIds.toList()..sort()),
  };

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
    themeId: json['themeId'] as String,
    unlockedThemeIds: {...(json['unlockedThemeIds'] as List).cast<String>()},
  );

  @override
  bool operator ==(Object other) =>
      other is Settings &&
      other.themeId == themeId &&
      setEquals(other.unlockedThemeIds, unlockedThemeIds);

  @override
  int get hashCode =>
      Object.hash(themeId, Object.hashAllUnordered(unlockedThemeIds));

  @override
  String toString() => 'Settings($themeId, unlocked $unlockedThemeIds)';
}
