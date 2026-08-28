import 'package:flutter/material.dart';

/// Brand mark for BizManager.
///
/// A bold, modern "B" with an electric-blue upward growth-line accent
/// that visually echoes the previous mark's "growth" idea while
/// embracing the new product name. Designed to be recognisable from
/// 1024x1024 all the way down to 16x16.
class BizManagerLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final bool showBackground;
  final bool useStandardColors;

  const BizManagerLogo({
    super.key,
    this.size = 100,
    this.color,
    this.showBackground = false,
    this.useStandardColors = true,
  });

  @override
  Widget build(BuildContext context) {
    final primary = color ?? Theme.of(context).colorScheme.primary;

    return Container(
      width: size,
      height: size,
      decoration: showBackground
          ? BoxDecoration(
              color: const Color(0xFF0F172A), // BizManager Navy
              borderRadius: BorderRadius.circular(size * 0.22),
            )
          : null,
      padding: showBackground ? EdgeInsets.all(size * 0.12) : EdgeInsets.zero,
      child: CustomPaint(
        size: Size(size, size),
        painter: _BizManagerPainter(
          color: primary,
          accentColor: useStandardColors
              ? const Color(0xFF2563EB) // electric blue accent
              : primary.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _BizManagerPainter extends CustomPainter {
  final Color color;
  final Color accentColor;

  _BizManagerPainter({
    required this.color,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // --- "B" Letterform ---
    // A bold geometric "B" built from a thick vertical stem on the
    // left and two stacked D-shaped bowls on the right.
    final letterPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final pathB = Path();
    // Outer outline of the "B" — traced clockwise.
    pathB.moveTo(w * 0.18, h * 0.08);
    pathB.lineTo(w * 0.55, h * 0.08);
    pathB.cubicTo(
      w * 0.78, h * 0.08,
      w * 0.88, h * 0.22,
      w * 0.88, h * 0.36,
    );
    pathB.cubicTo(
      w * 0.88, h * 0.46,
      w * 0.82, h * 0.52,
      w * 0.74, h * 0.54,
    );
    pathB.cubicTo(
      w * 0.84, h * 0.56,
      w * 0.92, h * 0.64,
      w * 0.92, h * 0.74,
    );
    pathB.cubicTo(
      w * 0.92, h * 0.88,
      w * 0.80, h * 0.96,
      w * 0.58, h * 0.96,
    );
    pathB.lineTo(w * 0.18, h * 0.96);
    pathB.close();

    // Cut the top bowl (a smaller rounded rectangle hole).
    final topHole = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.30, h * 0.20, w * 0.74, h * 0.46),
        Radius.circular(h * 0.10),
      ));
    // Cut the bottom bowl.
    final bottomHole = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.30, h * 0.58, w * 0.76, h * 0.84),
        Radius.circular(h * 0.10),
      ));

    // Punch the two holes out of the B by using even-odd fill.
    final fullB = Path.combine(
      PathOperation.union,
      pathB,
      Path(),
    );
    final punchedTop = Path.combine(PathOperation.difference, fullB, topHole);
    final punched = Path.combine(PathOperation.difference, punchedTop, bottomHole);
    canvas.drawPath(punched, letterPaint);

    // --- Growth-line accent ---
    // A short diagonal stroke that slices up-and-to-the-right across
    // the lower half of the mark, ending in a small arrow head.
    final accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final lineStroke = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // The line itself: from inside the lower bowl, out the right
    // edge, sloping upward.
    final linePath = Path()
      ..moveTo(w * 0.42, h * 0.78)
      ..lineTo(w * 0.74, h * 0.46);
    canvas.drawPath(linePath, lineStroke);

    // Arrow head — a small filled triangle at the upper-right tip.
    final arrow = Path()
      ..moveTo(w * 0.74, h * 0.46)
      ..lineTo(w * 0.66, h * 0.48)
      ..lineTo(w * 0.74, h * 0.38)
      ..close();
    canvas.drawPath(arrow, accentPaint);
  }

  @override
  bool shouldRepaint(covariant _BizManagerPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.accentColor != accentColor;
}
