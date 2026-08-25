import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

/// Wraps blue_thermal_printer for simple text-based receipt printing on a
/// paired 58mm/80mm Bluetooth thermal printer. Kept deliberately simple
/// (plain ESC/POS text lines, no bitmap/graphics) to stay reliable across
/// the many generic Bluetooth thermal printers shops actually use.
class BluetoothPrinterService {
  BluetoothPrinterService._();

  static final BlueThermalPrinter _printer = BlueThermalPrinter.instance;

  /// Requests necessary Bluetooth permissions for Android 12+ and older.
  static Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final bluetoothScan = await Permission.bluetoothScan.request();
      final bluetoothConnect = await Permission.bluetoothConnect.request();
      
      // On older Android, we might need Location too for scanning, 
      // but blue_thermal_printer mostly deals with paired (bonded) devices.
      return bluetoothScan.isGranted && bluetoothConnect.isGranted;
    }
    return true; // IOS handling can be added if needed
  }

  static Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      final hasPermission = await requestPermissions();
      if (!hasPermission) return [];
      
      return await _printer.getBondedDevices();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> connect(BluetoothDevice device) async {
    try {
      await _printer.connect(device);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> disconnect() async {
    try {
      await _printer.disconnect();
    } catch (_) {}
  }

  static Future<bool> isConnected() async {
    try {
      return await _printer.isConnected ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Prints a simple text receipt for a sale. `lines` are plain rows;
  /// pass '-' repeated for a divider, or use printLeftRight for two-column
  /// rows (item name vs price) via the `\t` convention below.
  static Future<bool> printReceipt({
    required String shopName,
    required String invoiceNumber,
    required String dateText,
    required String customerName,
    required List<({String name, String qty, String total})> items,
    required String subtotal,
    required String discount,
    required String total,
    required String paid,
    required String due,
    String? footer,
  }) async {
    try {
      if (!await isConnected()) return false;

      _printer.printCustom(shopName, 3, 1);
      _printer.printCustom('Invoice: $invoiceNumber', 1, 1);
      _printer.printCustom(dateText, 0, 1);
      _printer.printCustom('Customer: $customerName', 0, 0);
      _printer.printNewLine();
      _printer.printCustom('--------------------------------', 0, 0);

      for (final item in items) {
        _printer.printLeftRight(item.name, item.total, 1);
        _printer.printCustom('  ${item.qty}', 0, 0);
      }

      _printer.printCustom('--------------------------------', 0, 0);
      _printer.printLeftRight('Subtotal', subtotal, 0);
      _printer.printLeftRight('Discount', discount, 0);
      _printer.printLeftRight('Total', total, 1);
      _printer.printLeftRight('Paid', paid, 0);
      _printer.printLeftRight('Due', due, 0);
      _printer.printNewLine();

      if (footer != null && footer.isNotEmpty) {
        _printer.printCustom(footer, 0, 1);
      }

      _printer.printNewLine();
      _printer.printNewLine();
      _printer.paperCut();
      return true;
    } catch (_) {
      return false;
    }
  }
}
