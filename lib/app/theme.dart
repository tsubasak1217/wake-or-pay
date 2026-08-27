import 'package:flutter/material.dart';

/// The app's own typeface, on every theme and every screen.
///
/// M PLUS Rounded 1c — a rounded gothic with a full Japanese glyph set, which
/// the platform default (Roboto falling through to the system CJK font) is not:
/// the app is Japanese throughout, and a rounded face keeps a screen about
/// burning money from reading as a bank statement. Bundled rather than fetched,
/// so it looks the same on every device and works with no network.
///
/// SIL Open Font License 1.1 — see `assets/fonts/LICENSE.md` and `OFL.txt`.
const appFontFamily = 'MPLUSRounded1c';

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
    // Set on the theme rather than on individual styles: everything that reads
    // a text style off the theme — which is everything — picks it up, including
    // the Cupertino time wheel, whose style is built from `textTheme`.
    fontFamily: appFontFamily,
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
