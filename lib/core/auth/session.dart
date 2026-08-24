/// In-memory record of who is currently using the app on this device.
/// Not persisted — every fresh PIN unlock re-establishes it. Owner has
/// full access; cashier is restricted to Dashboard + Sales (see MainShell).
class Session {
  Session._();

  static String role = 'owner'; // 'owner' or 'cashier'
  static String? staffName;

  static bool get isOwner => role == 'owner';

  static void setOwner() {
    role = 'owner';
    staffName = null;
  }

  static void setCashier(String name) {
    role = 'cashier';
    staffName = name;
  }

  static void clear() {
    role = 'owner';
    staffName = null;
  }
}
