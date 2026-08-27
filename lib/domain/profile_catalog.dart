import 'package:flutter/material.dart';

/// The cosmetics a profile can wear.
///
/// Art is a placeholder, as in `GardenCatalog`: an icon is an emoji and a plate
/// is one or two colours, so nothing here needs an asset. Colours are stored as
/// [Color] rather than as ints because every reader of this file is the widget
/// layer, and a second representation to convert between would only be a place
/// for the two to disagree.
class ProfileCatalog {
  const ProfileCatalog._();

  static const defaultIconId = 'sleepy';
  static const defaultPlateBackgroundId = 'plate_slate';
  static const defaultFrameId = 'frame_none';

  static const icons = <ProfileIconDef>[
    ProfileIconDef(id: defaultIconId, label: 'ねむい', emoji: '😪'),
    ProfileIconDef(id: 'sun', label: 'あさひ', emoji: '🌞'),
    ProfileIconDef(id: 'ojisan', label: 'おじさん', emoji: '👨'),
  ];

  static const plateBackgrounds = <PlateBackgroundDef>[
    PlateBackgroundDef(
      id: defaultPlateBackgroundId,
      label: 'スレート',
      colors: [Color(0xFF3A4250)],
    ),
    PlateBackgroundDef(
      id: 'plate_dawn',
      label: 'よあけ',
      colors: [Color(0xFF7A4B8C), Color(0xFFE9825B)],
    ),
    PlateBackgroundDef(
      id: 'plate_moss',
      label: 'こけ',
      colors: [Color(0xFF2F5D3A), Color(0xFF8FBF6A)],
    ),
  ];

  static const frames = <PlateFrameDef>[
    PlateFrameDef(
      id: defaultFrameId,
      label: 'なし',
      width: 0,
      color: Color(0x00000000),
    ),
    PlateFrameDef(
      id: 'frame_thin',
      label: '細線',
      width: 1.5,
      color: Color(0xFFD9C27A),
    ),
    PlateFrameDef(
      id: 'frame_thick',
      label: '太線',
      width: 3.5,
      color: Color(0xFFD97A7A),
    ),
  ];

  /// The full sets, used as the "owned everything" default until there is a
  /// way to earn one. Spelled out rather than derived from the lists above so
  /// they can be `const` defaults on `Profile`.
  static const allIconIds = {defaultIconId, 'sun', 'ojisan'};
  static const allPlateBackgroundIds = {
    defaultPlateBackgroundId,
    'plate_dawn',
    'plate_moss',
  };
  static const allFrameIds = {defaultFrameId, 'frame_thin', 'frame_thick'};

  /// Lookups fall back to the first entry rather than throwing: a row written
  /// by a future version — or by a build where a cosmetic was retired — must
  /// paint something instead of crashing the header.
  static ProfileIconDef iconById(String id) =>
      icons.firstWhere((e) => e.id == id, orElse: () => icons.first);

  static PlateBackgroundDef plateBackgroundById(String id) => plateBackgrounds
      .firstWhere((e) => e.id == id, orElse: () => plateBackgrounds.first);

  static PlateFrameDef frameById(String id) =>
      frames.firstWhere((e) => e.id == id, orElse: () => frames.first);
}

@immutable
class ProfileIconDef {
  const ProfileIconDef({
    required this.id,
    required this.label,
    required this.emoji,
  });

  final String id;
  final String label;
  final String emoji;
}

@immutable
class PlateBackgroundDef {
  const PlateBackgroundDef({
    required this.id,
    required this.label,
    required this.colors,
  });

  final String id;
  final String label;

  /// One colour is flat; two or more are a left-to-right gradient.
  final List<Color> colors;
}

@immutable
class PlateFrameDef {
  const PlateFrameDef({
    required this.id,
    required this.label,
    required this.width,
    required this.color,
  });

  final String id;
  final String label;

  /// 0 means no frame at all, which is the default.
  final double width;
  final Color color;
}
