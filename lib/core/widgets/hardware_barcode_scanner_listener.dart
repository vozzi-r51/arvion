import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Intercepts raw keystrokes from USB / Bluetooth Hardware Barcode Scanners.
/// Physical scanners act as HID Keyboards typing barcodes rapidly followed by 'Enter'.
class HardwareBarcodeScannerListener extends StatefulWidget {
  final Widget child;
  final ValueChanged<String> onBarcodeScanned;

  const HardwareBarcodeScannerListener({
    super.key,
    required this.child,
    required this.onBarcodeScanned,
  });

  @override
  State<HardwareBarcodeScannerListener> createState() => _HardwareBarcodeScannerListenerState();
}

class _HardwareBarcodeScannerListenerState extends State<HardwareBarcodeScannerListener> {
  final StringBuffer _buffer = StringBuffer();
  DateTime _lastKeyPressTime = DateTime.now();

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final now = DateTime.now();
      // Physical scanners type characters within 50ms intervals.
      // If delay between keypresses > 300ms, it's a human typing—reset buffer.
      if (now.difference(_lastKeyPressTime).inMilliseconds > 300) {
        _buffer.clear();
      }
      _lastKeyPressTime = now;

      if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        final barcode = _buffer.toString().trim();
        if (barcode.isNotEmpty) {
          widget.onBarcodeScanned(barcode);
          _buffer.clear();
        }
      } else if (event.character != null && event.character!.isNotEmpty) {
        _buffer.write(event.character);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    );
  }
}
