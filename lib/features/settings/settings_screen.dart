import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/arvion_brand.dart';
import '../../core/database/db_helper.dart';
import '../../core/backup/backup_service.dart';
import '../company/company_selection_screen.dart';
import '../company/company_profile_screen.dart';
import '../../core/auth/session.dart';
import 'staff_users_screen.dart';
import 'theme_settings_screen.dart';
import '../auth/pin_login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricSupported = false;
  bool _biometricEnabled = false;
  bool _loading = true;
  bool _backupInProgress = false;
  bool _restoreInProgress = false;
  bool _autoBackupEnabled = true;
  DateTime? _lastAutoBackup;
  bool _allowNegativeStock = false;
  int _autoLockMinutes = 2;
  DateTime? _accountingLockDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final supported = await AuthService.instance.deviceSupportsBiometrics();
    final enabled = await AuthService.instance.isBiometricEnabled();
    final autoBackupEnabled = await BackupService.isAutoBackupEnabled();
    final lastAutoBackup = await BackupService.getLastAutoBackupDate();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricSupported = supported;
      _biometricEnabled = enabled;
      _autoBackupEnabled = autoBackupEnabled;
      _lastAutoBackup = lastAutoBackup;
      _allowNegativeStock = prefs.getBool('allow_negative_stock') ?? false;
      _autoLockMinutes = prefs.getInt('auto_lock_minutes') ?? 2;
      final lockStr = prefs.getString('accounting_lock_date');
      if (lockStr != null) {
        _accountingLockDate = DateTime.tryParse(lockStr);
      }
      _loading = false;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final confirmed = await AuthService.instance.authenticateWithBiometrics();
      if (!confirmed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fingerprint confirm nahi hui')),
          );
        }
        return;
      }
    }
    await AuthService.instance.setBiometricEnabled(value);
    setState(() => _biometricEnabled = value);
  }

  Future<void> _createBackup(bool directSave) async {
    setState(() => _backupInProgress = true);
    try {
      if (directSave) {
        final path = await BackupService.saveBackupToDownloads();
        if (mounted) {
          if (path != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Backup save ho gaya: $path')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Backup save nahi ho saka. Storage permission check karein.')),
            );
          }
        }
      } else {
        final zipPath = await BackupService.createBackupZip();
        if (!mounted) return;
        await Share.shareXFiles(
          [XFile(zipPath)],
          text: 'DukanEdge Backup',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup fail ho gaya: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _backupInProgress = false);
    }
  }

  Future<void> _restoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Data Restore Karein?'),
        content: const Text(
            'Ye aapka mojooda data overwrite kar dega. Ye action wapis nahi ho sakta. Continue karein?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore Karein',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _restoreInProgress = true);
    try {
      await BackupService.restoreFromZip(path);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore Mukammal'),
          content: const Text(
              'Data restore ho gaya. Naye data ke sath sahi tarah chalne ke liye app ko band karke dobara kholein.'),
          actions: [
            ElevatedButton(
              onPressed: () => SystemNavigator.pop(),
              child: const Text('App Band Karein'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore fail ho gaya: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _restoreInProgress = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out karein?'),
        content: const Text(
            'Current session band ho jayegi aur PIN screen khul jayegi.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    Session.clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PinLoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.settings_outlined, size: 54, color: Colors.grey),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'ARVION',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Smart Business. Simple Control.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Version 1.0.0',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Developed by ARVION Technologies',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('Security',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                if (_biometricSupported)
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint),
                    title: const Text('Fingerprint Login'),
                    subtitle:
                        const Text('PIN ke sath fingerprint bhi use karein'),
                    value: _biometricEnabled,
                    onChanged: _toggleBiometric,
                  )
                else
                  const ListTile(
                    leading: Icon(Icons.fingerprint, color: Colors.grey),
                    title: Text('Fingerprint is device par available nahi'),
                  ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('Appearance',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark Mode'),
                  value: themeProvider.themeMode == ThemeMode.dark,
                  onChanged: (_) => themeProvider.toggle(),
                ),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Theme & Brand Color'),
                  subtitle: const Text(
                      'App ka color aur light/dark mode customize karein'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const ThemeSettingsScreen()),
                  ),
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('Company',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Company Profile Edit Karein'),
                  onTap: () async {
                    final active = await DBHelper.instance.getActiveCompany();
                    if (active == null || !context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CompanyProfileScreen(
                          companyId: active['id'] as int,
                        ),
                      ),
                    );
                  },
                ),
                if (Session.isOwner)
                  ListTile(
                    leading: const Icon(Icons.people_outline),
                    title: const Text('Cashier / Staff PINs'),
                    onTap: () async {
                      final active = await DBHelper.instance.getActiveCompany();
                      if (active == null || !context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              StaffUsersScreen(companyId: active['id'] as int),
                        ),
                      );
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.swap_horiz),
                  title: const Text('Company Switch Karein'),
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const CompanySelectionScreen(),
                      ),
                    );
                  },
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('Sales Rules',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.inventory_2_outlined),
                  title: const Text('Negative Stock Allow Karein'),
                  subtitle: const Text(
                      'On karne par available se zyada quantity bhi sell ho sakti hai'),
                  value: _allowNegativeStock,
                  onChanged: (v) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('allow_negative_stock', v);
                    setState(() => _allowNegativeStock = v);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lock_clock_outlined),
                  title: const Text('Auto-Lock Timeout'),
                  subtitle: Text(_autoLockMinutes == 0
                      ? 'Kabhi nahi (auto-lock band)'
                      : '$_autoLockMinutes minute background mein rehne ke baad'),
                  trailing: DropdownButton<int>(
                    value: _autoLockMinutes,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Kabhi nahi')),
                      DropdownMenuItem(value: 1, child: Text('1 min')),
                      DropdownMenuItem(value: 2, child: Text('2 min')),
                      DropdownMenuItem(value: 5, child: Text('5 min')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setInt('auto_lock_minutes', v);
                      setState(() => _autoLockMinutes = v);
                    },
                  ),
                ),
                if (Session.isOwner) ...[
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text('Accounting Control',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: Colors.orange),
                    title: const Text('Accounting Period Lock'),
                    subtitle: Text(_accountingLockDate == null
                        ? 'Koi lock nahi laga. Sabi transactions open hain.'
                        : 'Transactions before ${_accountingLockDate!.toIso8601String().substring(0, 10)} are LOCKED.'),
                    trailing: TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _accountingLockDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          helpText: 'Sabi purani transactions ko lock karein',
                        );
                        if (picked != null) {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('accounting_lock_date', picked.toIso8601String());
                          setState(() => _accountingLockDate = picked);
                        }
                      },
                      child: Text(_accountingLockDate == null ? 'Set Lock' : 'Update'),
                    ),
                  ),
                  if (_accountingLockDate != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextButton(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('accounting_lock_date');
                          setState(() => _accountingLockDate = null);
                        },
                        child: const Text('Remove Lock', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                ],
                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('Data',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.schedule),
                  title: const Text('Auto-Backup (har 7 din)'),
                  subtitle: Text(_lastAutoBackup == null
                      ? 'Abhi tak koi auto-backup nahi hua'
                      : 'Last auto-backup: ${_lastAutoBackup!.toIso8601String().substring(0, 10)}'),
                  value: _autoBackupEnabled,
                  onChanged: (v) async {
                    await BackupService.setAutoBackupEnabled(v);
                    setState(() => _autoBackupEnabled = v);
                  },
                ),
                ListTile(
                  leading: _backupInProgress
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.backup_outlined),
                  title: const Text('Backup Share Karein'),
                  subtitle: const Text(
                      'Data + images ka zip bhejain aur share karein'),
                  onTap: _backupInProgress ? null : () => _createBackup(false),
                ),
                ListTile(
                  leading: const Icon(Icons.sd_storage_outlined),
                  title: const Text('Backup Device Mein Save Karein'),
                  subtitle: const Text(
                      'Share ke bagair seedha kisi folder mein save karein'),
                  onTap: _backupInProgress
                      ? null
                      : () async {
                          setState(() => _backupInProgress = true);
                          try {
                            final path =
                                await BackupService.saveBackupToDevice();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(path == null
                                    ? 'Cancel kar diya gaya'
                                    : 'Backup save ho gayi: $path'),
                              ),
                            );
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Backup fail ho gaya: $e')),
                              );
                            }
                          } finally {
                            if (mounted)
                              setState(() => _backupInProgress = false);
                          }
                        },
                ),
                ListTile(
                  leading: _restoreInProgress
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restore_outlined),
                  title: const Text('Backup Restore Karein'),
                  subtitle:
                      const Text('Pehle ki zip file se data wapis layein'),
                  onTap: _restoreInProgress ? null : _restoreBackup,
                ),
                if (Session.isOwner) ...[
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text('Session',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text('Sign out'),
                    subtitle: const Text(
                        'App ko lock karke PIN screen par wapas jayein'),
                    onTap: _signOut,
                  ),
                ],
              ],
            ),
    );
  }
}
