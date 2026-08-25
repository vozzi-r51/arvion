import 'package:flutter/material.dart';

class ArvionLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final bool showBackground;

  const ArvionLogo({
    super.key,
    this.size = 100,
    this.color,
    this.showBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: showBackground
          ? BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(size * 0.22),
            )
          : null,
      padding: showBackground ? EdgeInsets.all(size * 0.15) : EdgeInsets.zero,
      child: CustomPaint(
        size: Size(size, size),
        painter: _ArvionPainter(color: color ?? const Color(0xFF38BDF8)),
      ),
    );
  }
}

class _ArvionPainter extends CustomPainter {
  final Color color;
  _ArvionPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // --- Draw Stylized "A" ---
    final pathA = Path();
    // Left leg
    pathA.moveTo(w * 0.1, h * 0.95);
    pathA.lineTo(w * 0.42, h * 0.05);
    pathA.lineTo(w * 0.58, h * 0.05);
    pathA.lineTo(w * 0.9, h * 0.95);
    pathA.lineTo(w * 0.72, h * 0.95);
    pathA.lineTo(w * 0.5, h * 0.4); // apex point
    pathA.lineTo(w * 0.28, h * 0.95);
    pathA.close();
    canvas.drawPath(pathA, paint);

    // --- Draw Upward Growth Graph inside "A" ---
    final graphPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pathGraph = Path();
    // Starting point inside lower-left of A
    pathGraph.moveTo(w * 0.35, h * 0.75);
    pathGraph.lineTo(w * 0.48, h * 0.62); // first small peak
    pathGraph.lineTo(w * 0.55, h * 0.68); // small dip
    pathGraph.lineTo(w * 0.75, h * 0.45); // final big growth peak
    
    // Add arrow head to graph
    pathGraph.lineTo(w * 0.68, h * 0.46);
    pathGraph.moveTo(w * 0.75, h * 0.45);
    pathGraph.lineTo(w * 0.74, h * 0.53);

    canvas.drawPath(pathGraph, graphPaint);
    
    // Add a teal glow dot at the end of graph
    canvas.drawCircle(Offset(w * 0.75, h * 0.45), w * 0.04, Paint()..color = const Color(0xFF2DD4BF));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
