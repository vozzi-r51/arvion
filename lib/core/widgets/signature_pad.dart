import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Controller that lets a parent screen clear the pad and export what was
/// drawn as PNG bytes, without the pad needing to know about save logic.
class SignaturePadController {
  _SignaturePadState? _state;

  void _attach(_SignaturePadState state) => _state = state;

  void clear() => _state?._clear();

  bool get isEmpty => _state?._isEmpty ?? true;

  Future<Uint8List?> exportPng() async => _state?._exportPng();
}

class SignaturePad extends StatefulWidget {
  final SignaturePadController controller;
  const SignaturePad({super.key, required this.controller});

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final GlobalKey _boundaryKey = GlobalKey();
  final List<Offset?> _points = [];

  bool get _isEmpty => _points.where((p) => p != null).isEmpty;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
  }

  void _clear() => setState(() => _points.clear());

  Future<Uint8List?> _exportPng() async {
    if (_isEmpty) return null;
    final boundary = _boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _boundaryKey,
      child: Container(
        color: Colors.white,
        child: GestureDetector(
          onPanUpdate: (details) {
            final box = context.findRenderObject() as RenderBox;
            setState(
                () => _points.add(box.globalToLocal(details.globalPosition)));
          },
          onPanEnd: (_) => setState(() => _points.add(null)),
          child: CustomPaint(
            painter: _SignaturePainter(_points),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      if (p1 != null && p2 != null) {
        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
