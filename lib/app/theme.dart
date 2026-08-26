import 'package:flutter/material.dart';

/// A selectable colour scheme. `price` is in reward tokens; 0 = free.
class AppTheme {
  const AppTheme({
    required this.id,
    required this.name,
    required this.description,
    required this.seed,
    required this.brightness,
    required this.price,
  });

  final String id;
  final String name;
  final String description;
  final Color seed;
  final Brightness brightness;
  final int price;

  ThemeData get themeData => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
    useMaterial3: true,
  );
}

class AppThemes {
  const AppThemes._();

  static const defaultThemeId = 'midnight';

  static const midnight = AppTheme(
    id: 'midnight',
    name: '深夜',
    description: '暗い部屋でも目に痛くない、標準のテーマ。',
    seed: Color(0xFF6C4BFF),
    brightness: Brightness.dark,
    price: 0,
  );

  static const sunrise = AppTheme(
    id: 'sunrise',
    name: '朝焼け',
    description: '起きたあとの空の色。',
    seed: Color(0xFFFF7043),
    brightness: Brightness.light,
    price: 100,
  );

  static const forest = AppTheme(
    id: 'forest',
    name: '早朝の森',
    description: '静かな緑。',
    seed: Color(0xFF2E7D32),
    brightness: Brightness.dark,
    price: 100,
  );

  static const all = <AppTheme>[midnight, sunrise, forest];

  static AppTheme byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => midnight);
}
