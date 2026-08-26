import 'package:flutter/material.dart';

/// A professional, simplified brand mark for ARVION.
/// Designed to be recognizable at any size, from 1024x1024 to 16x16.
class ArvionLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final bool showBackground;
  final bool useStandardColors;

  const ArvionLogo({
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
              color: const Color(0xFF0F172A), // Arvion Navy
              borderRadius: BorderRadius.circular(size * 0.22),
            )
          : null,
      padding: showBackground ? EdgeInsets.all(size * 0.12) : EdgeInsets.zero,
      child: CustomPaint(
        size: Size(size, size),
        painter: _ArvionPainter(
          color: primary,
          accentColor: primary.withValues(alpha: 0.6),
          useStandardColors: useStandardColors,
        ),
      ),
    );
  }
}

class _ArvionPainter extends CustomPainter {
  final Color color;
  final Color accentColor;
  final bool useStandardColors;

  _ArvionPainter({
    required this.color,
    required this.accentColor,
    required this.useStandardColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final basePaint = Paint()
      ..color = useStandardColors ? color : color
      ..style = PaintingStyle.fill;

    final accentPaint = Paint()
      ..color = useStandardColors ? accentColor : Colors.white
      ..style = PaintingStyle.fill;

    // --- Simplified "A" Frame ---
    // A thick, bold geometric "A" without the crossbar yet
    final pathA = Path();
    pathA.moveTo(w * 0.5, 0); // Top center
    pathA.lineTo(w, h); // Bottom right
    pathA.lineTo(w * 0.75, h); // Inside bottom right
    pathA.lineTo(w * 0.5, h * 0.3); // Inside top center
    pathA.lineTo(w * 0.25, h); // Inside bottom left
    pathA.lineTo(0, h); // Bottom left
    pathA.close();
    canvas.drawPath(pathA, basePaint);

    // --- Growth "Crossbar" ---
    // A diagonal upward-sloping bar that breaks the "A"
    // This represents the "A" crossbar AND upward growth.
    final pathGrowth = Path();
    pathGraph(pathGrowth, w, h);
    pathGrowth.close();
    canvas.drawPath(pathGrowth, accentPaint);
  }

  void pathGraph(Path path, double w, double h) {
    // A thick diagonal bar sloping upwards
    path.moveTo(w * 0.2, h * 0.65);
    path.lineTo(w * 0.45, h * 0.65);
    path.lineTo(w * 0.85, h * 0.35);
    path.lineTo(w * 0.70, h * 0.25);
    path.lineTo(w * 0.35, h * 0.52);
    path.lineTo(w * 0.15, h * 0.52);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
