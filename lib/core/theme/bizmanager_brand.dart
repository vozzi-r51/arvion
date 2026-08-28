import 'package:flutter/material.dart';

/// Brand mark + wordmark for BizManager. Used in headers, about
/// cards, and the splash screen.
class BizManagerBrandMark extends StatelessWidget {
  final double size;
  final bool showWordmark;
  final Color? color;
  final TextStyle? textStyle;

  const BizManagerBrandMark({
    super.key,
    this.size = 40,
    this.showWordmark = true,
    this.color,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final brandColor = color ?? Theme.of(context).colorScheme.primary;
    final wordmarkStyle = textStyle ??
        Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.onSurface,
            );

    final mark = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BizManagerMarkPainter(color: brandColor),
      ),
    );

    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 12),
        Text('BizManager', style: wordmarkStyle),
      ],
    );
  }
}

/// Rounded-square app icon style. Renders the mark inside a
/// navy-tinted container with a soft shadow.
class BizManagerAppIcon extends StatelessWidget {
  final double size;
  final bool withBackground;

  const BizManagerAppIcon({
    super.key,
    this.size = 90,
    this.withBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.26),
        color: const Color(0xFF0F172A),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            offset: Offset(0, 12),
            blurRadius: 22,
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.62,
          height: size * 0.62,
          child: CustomPaint(
            painter: _BizManagerMarkPainter(color: Colors.white),
          ),
        ),
      ),
    );

    return withBackground
        ? bg
        : SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _BizManagerMarkPainter(
                  color: Theme.of(context).colorScheme.primary),
            ),
          );
  }
}

/// CustomPainter that draws the "B" + growth-line logo. The accent
/// colour is fixed to electric blue for consistency, but the main
/// letterform uses the colour passed in.
class _BizManagerMarkPainter extends CustomPainter {
  final Color color;

  const _BizManagerMarkPainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final letterPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // B outer outline
    final pathB = Path()
      ..moveTo(w * 0.18, h * 0.08)
      ..lineTo(w * 0.55, h * 0.08)
      ..cubicTo(
        w * 0.78, h * 0.08,
        w * 0.88, h * 0.22,
        w * 0.88, h * 0.36,
      )
      ..cubicTo(
        w * 0.88, h * 0.46,
        w * 0.82, h * 0.52,
        w * 0.74, h * 0.54,
      )
      ..cubicTo(
        w * 0.84, h * 0.56,
        w * 0.92, h * 0.64,
        w * 0.92, h * 0.74,
      )
      ..cubicTo(
        w * 0.92, h * 0.88,
        w * 0.80, h * 0.96,
        w * 0.58, h * 0.96,
      )
      ..lineTo(w * 0.18, h * 0.96)
      ..close();

    final topHole = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.30, h * 0.20, w * 0.74, h * 0.46),
        Radius.circular(h * 0.10),
      ));
    final bottomHole = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.30, h * 0.58, w * 0.76, h * 0.84),
        Radius.circular(h * 0.10),
      ));

    final punchedTop = Path.combine(PathOperation.difference, pathB, topHole);
    final punched =
        Path.combine(PathOperation.difference, punchedTop, bottomHole);
    canvas.drawPath(punched, letterPaint);

    // Accent: upward growth line
    final lineStroke = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final linePath = Path()
      ..moveTo(w * 0.42, h * 0.78)
      ..lineTo(w * 0.74, h * 0.46);
    canvas.drawPath(linePath, lineStroke);

    final arrow = Path()
      ..moveTo(w * 0.74, h * 0.46)
      ..lineTo(w * 0.66, h * 0.48)
      ..lineTo(w * 0.74, h * 0.38)
      ..close();
    canvas.drawPath(arrow, lineStroke);
  }

  @override
  bool shouldRepaint(covariant _BizManagerMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
