import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The Discord mark on a rounded blurple tile, regardless of theme.
///
/// A white mark on a blurple square is one of Discord's own approved
/// presentations (see https://discord.com/branding) — it does not recolour
/// the mark itself, only sets it against a filled backdrop, which keeps it
/// legible against the app's background instead of the bare mark's low
/// contrast.
class DiscordIcon extends StatelessWidget {
  const DiscordIcon({super.key, this.size = 28});

  final double size;

  static const blurple = Color(0xFF5865F2);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: blurple,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      padding: EdgeInsets.all(size * 0.16),
      child: SvgPicture.asset(
        'assets/icons/discord.svg',
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        semanticsLabel: 'Discord',
      ),
    );
  }
}
