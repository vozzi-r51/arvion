import 'package:flutter/material.dart';

class ArvionBrandMark extends StatelessWidget {
  final double size;
  final bool showWordmark;
  final Color? color;
  final TextStyle? textStyle;

  const ArvionBrandMark({
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
        painter: _ArvionMarkPainter(color: brandColor),
      ),
    );

    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 12),
        Text('ARVION', style: wordmarkStyle),
      ],
    );
  }
}

class ArvionAppIcon extends StatelessWidget {
  final double size;
  final bool withBackground;

  const ArvionAppIcon({
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
        color: const Color(0xFF0F274D),
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
          width: size * 0.52,
          height: size * 0.52,
          child: CustomPaint(
            painter: _ArvionMarkPainter(color: Colors.white),
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
              painter: _ArvionMarkPainter(
                  color: Theme.of(context).colorScheme.primary),
            ),
          );
  }
}

class _ArvionMarkPainter extends CustomPainter {
  final Color color;

  const _ArvionMarkPainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Improved Geometric Symmetrical Falcon
    // Top-down spread wings style for better "flying" recognition
    final falcon = Path()
      ..moveTo(size.width * 0.5, size.height * 0.2) // Beak/Head
      ..lineTo(size.width * 0.6, size.height * 0.1)
      ..lineTo(size.width * 0.9, size.height * 0.3) // Wing tip R
      ..lineTo(size.width * 0.7, size.height * 0.45)
      ..lineTo(size.width * 0.8, size.height * 0.7) // Wing bottom R
      ..lineTo(size.width * 0.5, size.height * 0.55) // Tail top
      ..lineTo(size.width * 0.6, size.height * 0.9) // Tail R
      ..lineTo(size.width * 0.5, size.height * 0.8) // Tail center
      ..lineTo(size.width * 0.4, size.height * 0.9) // Tail L
      ..lineTo(size.width * 0.5, size.height * 0.55) // Tail top
      ..lineTo(size.width * 0.2, size.height * 0.7) // Wing bottom L
      ..lineTo(size.width * 0.3, size.height * 0.45)
      ..lineTo(size.width * 0.1, size.height * 0.3) // Wing tip L
      ..lineTo(size.width * 0.4, size.height * 0.1)
      ..close();

    canvas.drawPath(falcon, paint);

    // Dynamic Electric Blue highlight inside
    final accentPaint = Paint()
      ..color = color.computeLuminance() > 0.5
          ? const Color(0xFF0F274D)
          : const Color(0xFF2563EB)
      ..style = PaintingStyle.fill;

    final accent = Path()
      ..moveTo(size.width * 0.5, size.height * 0.3)
      ..lineTo(size.width * 0.6, size.height * 0.45)
      ..lineTo(size.width * 0.5, size.height * 0.4)
      ..lineTo(size.width * 0.4, size.height * 0.45)
      ..close();
    canvas.drawPath(accent, accentPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
