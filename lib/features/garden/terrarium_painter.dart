import 'package:flutter/material.dart';

/// Corner radius of the jar, as a fraction of its width. Shared with the clip
/// the board wraps its contents in, so the two never disagree.
const jarCornerFactor = 0.17;

/// The glass jar: a rounded capsule with a soil layer at the bottom and one
/// highlight down the left shoulder. Placeholder art — a real illustration
/// replaces this painter without touching anything that lays items out.
class TerrariumPainter extends CustomPainter {
  const TerrariumPainter({
    required this.glass,
    required this.rim,
    required this.soil,
    required this.soilTop,
  });

  final Color glass;
  final Color rim;
  final Color soil;

  /// Distance from the top of the jar to the surface of the soil.
  final double soilTop;

  RRect _body(Size size) => RRect.fromRectAndRadius(
    Offset.zero & size,
    Radius.circular(size.width * jarCornerFactor),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final body = _body(size);

    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [glass.withValues(alpha: 0.55), glass.withValues(alpha: 0.2)],
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipRRect(body);

    final top = soilTop.clamp(0.0, size.height);
    canvas.drawRect(
      Rect.fromLTRB(0, top, size.width, size.height),
      Paint()..color = soil,
    );
    // A lighter band along the surface so the ground reads as ground.
    canvas.drawRect(
      Rect.fromLTRB(0, top, size.width, top + size.height * 0.012),
      Paint()
        ..color = Color.alphaBlend(Colors.white.withValues(alpha: 0.3), soil),
    );

    // Light on the upper left shoulder.
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.12, size.height * 0.30)
        ..quadraticBezierTo(
          size.width * 0.10,
          size.height * 0.10,
          size.width * 0.30,
          size.height * 0.05,
        )
        ..lineTo(size.width * 0.38, size.height * 0.08)
        ..quadraticBezierTo(
          size.width * 0.18,
          size.height * 0.14,
          size.width * 0.19,
          size.height * 0.31,
        )
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );

    canvas.restore();

    canvas.drawRRect(
      body.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = rim,
    );
  }

  @override
  bool shouldRepaint(TerrariumPainter old) =>
      old.glass != glass ||
      old.rim != rim ||
      old.soil != soil ||
      old.soilTop != soilTop;
}
