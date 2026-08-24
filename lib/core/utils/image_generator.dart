import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageGenerator {
  ImageGenerator._();

  static Future<String?> generateFromWidget({
    required Widget widget,
    required BuildContext context,
    required String fileName,
  }) async {
    final boundary = RenderRepaintBoundary();
    final view = View.of(context);
    
    final pipelineOwner = PipelineOwner();
    final renderView = RenderView(
      view: view,
      child: RenderPositionedBox(alignment: Alignment.center, child: boundary),
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(const Size(512, 512)),
        devicePixelRatio: view.devicePixelRatio,
      ),
    );
    
    pipelineOwner.rootNode = renderView;
    renderView.prepareInitialFrame();

    final buildOwner = BuildOwner(focusManager: FocusManager());
    final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: widget,
      ),
    ).attachToRenderTree(buildOwner);

    buildOwner.buildScope(rootElement);
    buildOwner.finalizeTree();

    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();

    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    if (byteData == null) return null;
    
    final Uint8List pngBytes = byteData.buffer.asUint8List();

    final docsDir = await getApplicationDocumentsDirectory();
    final assetsDir = Directory(p.join(docsDir.path, 'generated_assets'));
    if (!await assetsDir.exists()) {
      await assetsDir.create(recursive: true);
    }
    
    final savedPath = p.join(assetsDir.path, '$fileName.png');
    await File(savedPath).writeAsBytes(pngBytes);
    
    return savedPath;
  }
}

class GeneratorDialog extends StatefulWidget {
  final String initialText;
  final bool isStamp;
  const GeneratorDialog({super.key, required this.initialText, this.isStamp = false});

  @override
  State<GeneratorDialog> createState() => _GeneratorDialogState();
}

class _GeneratorDialogState extends State<GeneratorDialog> {
  late String _text;
  Color _color = const Color(0xFF00695C);
  bool _isCircle = true;

  @override
  void initState() {
    super.initState();
    _text = widget.initialText;
    if (widget.isStamp) {
      _color = const Color(0xFF0D47A1); // Blue for stamp usually
    }
  }

  Widget _buildPreview() {
    return Container(
      width: 200,
      height: 200,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: _isCircle ? BoxShape.circle : BoxShape.rectangle,
        border: Border.all(color: _color, width: widget.isStamp ? 4 : 8),
        borderRadius: _isCircle ? null : BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _text.split(' ').map((s) => s.isNotEmpty ? s[0] : '').join('').toUpperCase(),
            style: TextStyle(
              color: _color,
              fontSize: 60,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (widget.isStamp) ...[
            const Divider(height: 10),
            Text(
              "OFFICIAL STAMP",
              style: TextStyle(color: _color, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isStamp ? 'Generate Stamp' : 'Generate Logo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPreview(),
            const SizedBox(height: 20),
            TextField(
              decoration: const InputDecoration(labelText: 'Shop Name'),
              onChanged: (v) => setState(() => _text = v),
              controller: TextEditingController(text: _text),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Shape: '),
                ChoiceChip(
                  label: const Text('Circle'),
                  selected: _isCircle,
                  onSelected: (v) => setState(() => _isCircle = true),
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text('Square'),
                  selected: !_isCircle,
                  onSelected: (v) => setState(() => _isCircle = false),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                Colors.teal, Colors.blue, Colors.green, Colors.red, Colors.orange, Colors.black
              ].map((c) => GestureDetector(
                onTap: () => setState(() => _color = c),
                child: CircleAvatar(backgroundColor: c, radius: 15, 
                  child: _color == c ? const Icon(Icons.check, size: 16, color: Colors.white) : null),
              )).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            final path = await ImageGenerator.generateFromWidget(
              widget: _buildPreview(),
              context: context,
              fileName: '${widget.isStamp ? 'stamp' : 'logo'}_${DateTime.now().millisecondsSinceEpoch}',
            );
            if (mounted) Navigator.pop(context, path);
          },
          child: const Text('Generate & Use'),
        ),
      ],
    );
  }
}
