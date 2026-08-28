import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The Discord mark, drawn in Discord's own "blurple" regardless of theme —
/// the brand guidelines allow the mark to indicate a link to Discord but
/// forbid recolouring it, so it does not follow the colour scheme.
class DiscordIcon extends StatelessWidget {
  const DiscordIcon({super.key, this.size = 24});

  final double size;

  static const blurple = Color(0xFF5865F2);

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/discord.svg',
      width: size,
      height: size,
      colorFilter: const ColorFilter.mode(blurple, BlendMode.srcIn),
      semanticsLabel: 'Discord',
    );
  }
}
