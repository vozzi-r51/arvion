import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/arvion_brand.dart';
import '../../core/database/db_helper.dart';
import '../../core/backup/backup_service.dart';
import '../../core/providers/localization_provider.dart';
import '../company/company_selection_screen.dart';
import '../company/company_profile_screen.dart';
import '../company/onboarding_wizard_screen.dart';
import '../../core/auth/session.dart';
import 'staff_users_screen.dart';
import 'theme_settings_screen.dart';
import '../../core/services/ux_mode_service.dart';
import 'custom_fields_screen.dart';
import 'uom_list_screen.dart';
import 'tax_codes_screen.dart';
import 'price_lists_screen.dart';
import 'regional_settings_screen.dart';
import '../auth/pin_login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shell/main_shell.dart';
import '../../core/utils/image_generator.dart';
import '../../core/widgets/arvion_logo.dart';
import '../../core/backup/google_drive_service.dart';
import '../../core/export/full_data_export_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:intl/intl.dart';
import '../../core/templates/template_messaging.dart';
import '../../core/templates/business_templates.dart';
import '../../core/business_types/business_type_catalog.dart';

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
  bool _crashReportingEnabled = true;
  String _selectedLanguage = 'en';

  // Google Drive
  GoogleSignInAccount? _driveUser;
  bool _autoUploadToDrive = false;
  bool _driveActionInProgress = false;

  // Loyalty Settings
  double _loyaltyRate = 100.0;
  double _pointValue = 1.0;

  // SMS Settings
  bool _smsEnabled = false;
  final _smsUrlCtrl = TextEditingController();
  final _smsKeyCtrl = TextEditingController();

  String _currentVersion = '1.0.0';
  UXMode _appMode = UXMode.simple;

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

    final packageInfo = await PackageInfo.fromPlatform();
    _currentVersion = packageInfo.version;

    final driveEnabled = await GoogleDriveService.isAutoUploadEnabled();
    final driveUser = await GoogleDriveService.instance.signInSilently();

    setState(() {
      _biometricSupported = supported;
      _biometricEnabled = enabled;
      _autoBackupEnabled = autoBackupEnabled;
      _lastAutoBackup = lastAutoBackup;
      _allowNegativeStock = prefs.getBool('allow_negative_stock') ?? false;
      _autoLockMinutes = prefs.getInt('auto_lock_minutes') ?? 2;
      _crashReportingEnabled = prefs.getBool('crash_reporting_enabled') ?? true;
      final lockStr = prefs.getString('accounting_lock_date');
      if (lockStr != null) {
        _accountingLockDate = DateTime.tryParse(lockStr);
      }

      _loyaltyRate = prefs.getDouble('loyalty_points_rate') ?? 100.0;
      _pointValue = prefs.getDouble('loyalty_point_value') ?? 1.0;
      _smsEnabled = prefs.getBool('sms_enabled') ?? false;
      _smsUrlCtrl.text = prefs.getString('sms_gateway_url') ?? '';
      _smsKeyCtrl.text = prefs.getString('sms_api_key') ?? '';

      _autoUploadToDrive = driveEnabled;
      _driveUser = driveUser;
    });

    final active = await DBHelper.instance.getActiveCompany();
    UXMode appMode = UXMode.simple;
    if (active != null) {
      appMode = await UXModeService.getEffectiveMode(active['id'] as int);
    }

    if (!mounted) return;
    setState(() {
      _appMode = appMode;
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

    if (_driveUser != null) {
      await GoogleDriveService.instance.signOut();
    }

    Session.clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PinLoginScreen()),
      (_) => false,
    );
  }

  Future<void> _toggleDriveConnection() async {
    setState(() => _driveActionInProgress = true);
    try {
      if (_driveUser == null) {
        final account = await GoogleDriveService.instance.signIn();
        setState(() => _driveUser = account);
      } else {
        await GoogleDriveService.instance.signOut();
        setState(() => _driveUser = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connection error: $e')));
      }
    } finally {
      if (mounted) setState(() => _driveActionInProgress = false);
    }
  }

  Future<void> _backupToDrive() async {
    setState(() => _driveActionInProgress = true);
    try {
      final zipPath = await BackupService.createBackupZip();
      await GoogleDriveService.instance.uploadBackup(zipPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup Google Drive par upload ho gaya.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload fail: $e')));
      }
    } finally {
      if (mounted) setState(() => _driveActionInProgress = false);
    }
  }

  Future<void> _restoreFromDrive() async {
    setState(() => _driveActionInProgress = true);
    try {
      final backups = await GoogleDriveService.instance.listBackups();
      if (!mounted) return;
      
      if (backups.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Drive par koi backup nahi mila.')));
        return;
      }

      final selected = await showDialog<drive.File>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Drive Backups'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: backups.length,
              itemBuilder: (ctx, i) {
                final b = backups[i];
                final date = b.createdTime != null ? DateFormat('dd MMM yyyy, HH:mm').format(b.createdTime!.toLocal()) : 'Unknown';
                return ListTile(
                  title: Text(b.name ?? 'Unknown'),
                  subtitle: Text(date),
                  onTap: () => Navigator.pop(ctx, b),
                );
              },
            ),
          ),
        ),
      );

      if (selected == null) return;

      final tempDir = await getTemporaryDirectory();
      final downloadPath = p.join(tempDir.path, selected.name!);
      
      await GoogleDriveService.instance.downloadBackup(selected.id!, downloadPath);
      
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Backup Restore Karein?'),
          content: Text('Kya aap "${selected.name}" se data restore karna chahte hain? Mojooda data delete ho jayega.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Haan, Restore Karein')),
          ],
        ),
      );

      if (confirmed != true) return;

      await BackupService.restoreFromZip(downloadPath);
      
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore Mukammal'),
          content: const Text('Naye data ke sath sahi tarah chalne ke liye app ko band karke dobara kholein.'),
          actions: [
            ElevatedButton(onPressed: () => SystemNavigator.pop(), child: const Text('App Band Karein')),
          ],
        ),
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore fail: $e')));
      }
    } finally {
      if (mounted) setState(() => _driveActionInProgress = false);
    }
  }

  Future<void> _generateLauncherIcon() async {
    final path = await ImageGenerator.generateFromWidget(
      widget: const ArvionLogo(size: 512, showBackground: false), // Transparent for adaptive
      context: context,
      fileName: 'new_app_icon',
    );
    
    if (mounted && path != null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Icon Generated'),
          content: SelectableText('Icon saved to:\n$path\n\nPlease move this file to assets/icon/app_icon.png and run launcher icons command.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() => _loading = true);
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/vozzi-r51/arvion/releases/latest'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestVersion = data['tag_name'].toString().replaceAll('v', '');
        final downloadUrl = data['html_url'];

        if (latestVersion != _currentVersion) {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Update Available!'),
              content: Text('Naya version ($latestVersion) available hai. Aapka current version $_currentVersion hai.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Baad Mein')),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (await canLaunchUrl(Uri.parse(downloadUrl))) {
                      await launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
                    }
                  },
                  child: const Text('Download Karein'),
                ),
              ],
            ),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aap pehle se latest version use kar rahe hain.')),
          );
        }
      } else {
        throw 'API Error: ${response.statusCode}';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update check fail ho gaya: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Build "Your Business Setup" showcase section
  Widget _buildBusinessSetupSection() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: DBHelper.instance.getActiveCompany(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final company = snapshot.data!;
        final businessType = company['business_category'] as String? ?? 'Business';
        final businessSubtype = company['business_subtype'] as String? ?? '';
        final templateFamilyStr = company['template_family'] as String? ?? 'retailStandard';

        // Parse template family
        TemplateFamily templateFamily = TemplateFamily.retailStandard;
        try {
          templateFamily = TemplateFamily.values.firstWhere(
            (f) => f.toString().split('.').last == templateFamilyStr,
            orElse: () => TemplateFamily.retailStandard,
          );
        } catch (_) {}

        final template = BusinessTemplates.getByFamily(templateFamily);
        final enabledFeatures = TemplateMessaging.getEnabledFeatures(templateFamily);
        final categoryIcon = _getCategoryIcon(templateFamily);

        return Card(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        categoryIcon,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YOUR BUSINESS SETUP',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            businessType,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (businessSubtype.isNotEmpty)
                            Text(
                              businessSubtype,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Enabled features
                Text(
                  'Enabled Features',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: enabledFeatures.map((feature) {
                    final emoji = TemplateMessaging.getFeatureEmoji(feature);
                    return Chip(
                      label: Text(
                        '$emoji $feature',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Change Business Type Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showChangeBusinessTypeDialog(),
                    icon: const Icon(Icons.edit),
                    label: const Text('Change Business Type'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Get icon for business category
  IconData _getCategoryIcon(TemplateFamily family) {
    switch (family) {
      case TemplateFamily.retailStandard:
        return Icons.storefront;
      case TemplateFamily.retailVariant:
        return Icons.checkroom;
      case TemplateFamily.retailCustomFields:
        return Icons.diamond;
      case TemplateFamily.serializedInventory:
        return Icons.devices;
      case TemplateFamily.retailBatchExpiry:
        return Icons.local_pharmacy;
      case TemplateFamily.foodService:
        return Icons.restaurant;
      case TemplateFamily.bookingBased:
        return Icons.hotel;
      case TemplateFamily.workshopJob:
        return Icons.directions_car;
      case TemplateFamily.farmOperations:
        return Icons.agriculture;
      case TemplateFamily.manufacturing:
        return Icons.factory;
      case TemplateFamily.projectBased:
        return Icons.construction;
      case TemplateFamily.serviceJob:
        return Icons.local_offer;
      case TemplateFamily.propertyBased:
        return Icons.home;
      case TemplateFamily.fleetBased:
        return Icons.directions_bus;
      case TemplateFamily.enrollmentBased:
        return Icons.school;
      case TemplateFamily.nonprofit:
        return Icons.favorite;
    }
  }

  /// Show dialog to change business type
  void _showChangeBusinessTypeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Business Type?'),
        content: const Text(
          'Ye aapke business type ko tabdeel kar dega aur naye defaults apply ho jaenge. '
          'Mojooda data preserve ho jayega — sirf naye settings default values update hongi.\n\n'
          'Continue karein?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Navigate to onboarding wizard
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const OnboardingWizardScreen(),
                ),
              );
            },
            child: const Text('Haan, Change Karein'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: MainShell.getMenuButton(context),
        title: const Text('Settings'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Business Setup Showcase Section
                _buildBusinessSetupSection(),

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
                            children: [
                              const Text(
                                'ARVION',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Smart Business. Simple Control.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Version $_currentVersion',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _checkForUpdates,
                                icon: const Icon(Icons.update, size: 14),
                                label: const Text('Check for Updates', style: TextStyle(fontSize: 10)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
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
                ListTile(
                  leading: const Icon(Icons.tune_outlined),
                  title: const Text('UI Mode'),
                  subtitle: Text(_appMode == UXMode.simple
                      ? 'Simple Mode (Sada & Asaan)'
                      : 'Advanced Mode (Full QuickBooks/Zoho Features)'),
                  trailing: DropdownButton<UXMode>(
                    value: _appMode,
                    items: const [
                      DropdownMenuItem(value: UXMode.simple, child: Text('Simple Mode')),
                      DropdownMenuItem(value: UXMode.advanced, child: Text('Advanced Mode')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      final active = await DBHelper.instance.getActiveCompany();
                      if (active == null) return;
                      await UXModeService.setMode(active['id'] as int, v);
                      setState(() => _appMode = v);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('UI Mode ${v == UXMode.simple ? "Simple" : "Advanced"} ho gaya.')),
                        );
                      }
                    },
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
                  child: Text('Catalog & Inventory',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: const Text('Regional, Tax & Document Settings'),
                  subtitle: const Text('Currency symbol, decimals, date format & invoice prefix'),
                  onTap: () async {
                    final active = await DBHelper.instance.getActiveCompany();
                    if (active == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => RegionalSettingsScreen(companyId: active['id'] as int)),
                    ).then((_) => _load());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.translate_outlined),
                  title: const Text('App Language'),
                  subtitle: Text(_languageName(_selectedLanguage)),
                  trailing: DropdownButton<String>(
                    value: _selectedLanguage,
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'ur', child: Text('اردو')),
                      DropdownMenuItem(value: 'ar', child: Text('العربية')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('selected_language', v);
                      final locProvider = context.read<LocalizationProvider>();
                      locProvider.setLocale(v);
                      setState(() => _selectedLanguage = v);
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.request_quote_outlined),
                  title: const Text('Multi Tax Codes'),
                  subtitle: const Text('GST, VAT, Sales Tax rates manage karein'),
                  onTap: () async {
                    final active = await DBHelper.instance.getActiveCompany();
                    if (active == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => TaxCodesScreen(companyId: active['id'] as int)),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.sell_outlined),
                  title: const Text('Price Lists (VIP / Sale / Wholesale)'),
                  subtitle: const Text('Retail, Wholesale & Custom Price lists set karein'),
                  onTap: () async {
                    final active = await DBHelper.instance.getActiveCompany();
                    if (active == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PriceListsScreen(companyId: active['id'] as int)),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.straighten_outlined),
                  title: const Text('Units of Measure (UOM)'),
                  subtitle: const Text('Kg, Gram, Dozen aur conversion rules manage karein'),
                  onTap: () async {
                    final active = await DBHelper.instance.getActiveCompany();
                    if (active == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => UomListScreen(companyId: active['id'] as int)),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.dynamic_form_outlined),
                  title: const Text('Custom Fields'),
                  subtitle: const Text('Products aur Customers ke liye naye fields banayein'),
                  onTap: () async {
                    final active = await DBHelper.instance.getActiveCompany();
                    if (active == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => CustomFieldsScreen(companyId: active['id'] as int)),
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
                    items: [
                      const DropdownMenuItem(value: 0, child: Text('Kabhi nahi')),
                      const DropdownMenuItem(value: 1, child: Text('1 min')),
                      const DropdownMenuItem(value: 2, child: Text('2 min')),
                      const DropdownMenuItem(value: 5, child: Text('5 min')),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setInt('auto_lock_minutes', v);
                      setState(() => _autoLockMinutes = v);
                    },
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.bug_report_outlined),
                  title: const Text('Crash Reports Bhejein'),
                  subtitle: const Text('App crash hone par anonymous report bheji jayegi taake hum isay fix kar sakein'),
                  value: _crashReportingEnabled,
                  onChanged: (v) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('crash_reporting_enabled', v);
                    setState(() => _crashReportingEnabled = v);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Setting save ho gayi. App restart karein.')),
                      );
                    }
                  },
                ),
                if (Session.isOwner) ...[
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text('Loyalty Program',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.star_outline, color: Colors.amber),
                    title: const Text('Points per Rs. 100 spent'),
                    subtitle: Text('Abhi: $_loyaltyRate Rs. par 1 point'),
                    trailing: SizedBox(
                      width: 60,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(isDense: true),
                        onChanged: (v) async {
                          final val = double.tryParse(v) ?? 100.0;
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setDouble('loyalty_points_rate', val);
                          setState(() => _loyaltyRate = val);
                        },
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.money, color: Colors.green),
                    title: const Text('1 Point Value (Rs.)'),
                    subtitle: Text('Abhi: 1 point = Rs. $_pointValue'),
                    trailing: SizedBox(
                      width: 60,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(isDense: true),
                        onChanged: (v) async {
                          final val = double.tryParse(v) ?? 1.0;
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setDouble('loyalty_point_value', val);
                          setState(() => _pointValue = val);
                        },
                      ),
                    ),
                  ),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text('SMS Gateway (Optional)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.sms_outlined),
                    title: const Text('SMS Reminders Enable Karein'),
                    value: _smsEnabled,
                    onChanged: (v) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('sms_enabled', v);
                      setState(() => _smsEnabled = v);
                    },
                  ),
                  if (_smsEnabled) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _smsUrlCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Gateway URL',
                          hintText: 'https://api.com/s?k={key}&t={mobile}&m={message}',
                          helperText: 'Use {key}, {mobile}, {message} placeholders',
                        ),
                        onChanged: (v) async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('sms_gateway_url', v);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextField(
                        controller: _smsKeyCtrl,
                        decoration: const InputDecoration(labelText: 'API Key'),
                        onChanged: (v) async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('sms_api_key', v);
                        },
                      ),
                    ),
                  ],
                ],
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
                ListTile(
                  leading: const Icon(Icons.table_view_outlined, color: Colors.teal),
                  title: const Text('Full Data Export (CSV)'),
                  subtitle: const Text('Products, Customers aur Sales history Excel mein le jayein'),
                  onTap: () async {
                    final active = await DBHelper.instance.getActiveCompany();
                    if (active == null) return;
                    await FullDataExportService.exportAllToCsv(active['id'] as int);
                  },
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('Google Drive Cloud Backup',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                ListTile(
                  leading: _driveActionInProgress 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(_driveUser == null ? Icons.cloud_off : Icons.cloud_done, color: _driveUser == null ? Colors.grey : Colors.blue),
                  title: Text(_driveUser == null ? 'Google Drive Connect Karein' : 'Google Drive Se Connected'),
                  subtitle: Text(_driveUser?.email ?? 'Cloud backup ke liye sign in karein'),
                  trailing: TextButton(
                    onPressed: _driveActionInProgress ? null : _toggleDriveConnection,
                    child: Text(_driveUser == null ? 'Sign In' : 'Sign Out'),
                  ),
                ),
                if (_driveUser != null) ...[
                  ListTile(
                    leading: const Icon(Icons.upload_file, color: Colors.blue),
                    title: const Text('Drive Par Backup Upload Karein'),
                    onTap: _driveActionInProgress ? null : _backupToDrive,
                  ),
                  ListTile(
                    leading: const Icon(Icons.download_for_offline, color: Colors.green),
                    title: const Text('Drive Se Restore Karein'),
                    onTap: _driveActionInProgress ? null : _restoreFromDrive,
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.sync),
                    title: const Text('Auto-upload to Drive'),
                    subtitle: const Text('Local backup ke baad automatically cloud par bhejain'),
                    value: _autoUploadToDrive,
                    onChanged: (v) async {
                      await GoogleDriveService.setAutoUploadEnabled(v);
                      setState(() => _autoUploadToDrive = v);
                    },
                  ),
                ],
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
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.architecture, color: Colors.blue),
                    title: const Text('Developer: Generate App Icon'),
                    subtitle: const Text('Render Arvion logo to PNG for launcher'),
                    onTap: _generateLauncherIcon,
                  ),
                ],
              ],
            ),
    );
  }

  String _languageName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'ur':
        return 'اردو (Urdu)';
      case 'ar':
        return 'العربية (Arabic)';
      default:
        return 'English';
    }
  }
}
