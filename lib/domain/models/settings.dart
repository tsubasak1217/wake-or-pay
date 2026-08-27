import 'package:flutter/foundation.dart';

import '../../app/theme.dart';

@immutable
class Settings {
  const Settings({
    this.themeId = AppThemes.defaultThemeId,
    this.unlockedThemeIds = const {AppThemes.defaultThemeId},
    this.userName = '',
  });

  final String themeId;
  final Set<String> unlockedThemeIds;

  /// The person using the app — the one who oversleeps.
  ///
  /// Empty until they say. The oversleep message is *about* them and is sent
  /// *to* somebody else, so this is the name that belongs in it; with no name
  /// the message uses a generic subject rather than naming the recipient.
  final String userName;

  Settings copyWith({
    String? themeId,
    Set<String>? unlockedThemeIds,
    String? userName,
  }) => Settings(
    themeId: themeId ?? this.themeId,
    unlockedThemeIds: unlockedThemeIds ?? this.unlockedThemeIds,
    userName: userName ?? this.userName,
  );

  Map<String, dynamic> toJson() => {
    'themeId': themeId,
    'unlockedThemeIds': (unlockedThemeIds.toList()..sort()),
    'userName': userName,
  };

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
    themeId: json['themeId'] as String,
    unlockedThemeIds: {...(json['unlockedThemeIds'] as List).cast<String>()},
    userName: json['userName'] as String? ?? '',
  );

  @override
  bool operator ==(Object other) =>
      other is Settings &&
      other.themeId == themeId &&
      other.userName == userName &&
      setEquals(other.unlockedThemeIds, unlockedThemeIds);

  @override
  int get hashCode =>
      Object.hash(themeId, userName, Object.hashAllUnordered(unlockedThemeIds));

  @override
  String toString() =>
      'Settings($themeId, unlocked $unlockedThemeIds, user "$userName")';
}
