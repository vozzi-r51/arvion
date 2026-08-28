import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../database/db_helper.dart';
import 'google_drive_service.dart';

class BackupService {
  BackupService._();

  static const _dbFileName = 'dukanedge.db';

  static Future<String> createBackupZip() async {
    await DBHelper.instance.closeDatabase();

    final dbDir = await getDatabasesPath();
    final dbFile = File(p.join(dbDir, _dbFileName));

    final docsDir = await getApplicationDocumentsDirectory();
    final companyAssetsDir = Directory(p.join(docsDir.path, 'company_assets'));
    final productImagesDir = Directory(p.join(docsDir.path, 'product_images'));

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final zipPath = p.join(tempDir.path, 'BizManager_Backup_$timestamp.zip');

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    if (await dbFile.exists()) {
      encoder.addFile(dbFile, _dbFileName);
    }
    if (await companyAssetsDir.exists()) {
      encoder.addDirectory(companyAssetsDir, includeDirName: true);
    }
    if (await productImagesDir.exists()) {
      encoder.addDirectory(productImagesDir, includeDirName: true);
    }

    encoder.close();
    await DBHelper.instance.database;

    return zipPath;
  }

  static Future<String?> saveBackupToDownloads() async {
    try {
      final zipPath = await createBackupZip();

      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null) return null;

      final targetDir =
          Directory(p.join(downloadsDir.path, 'BizManager_Backups'));
      if (!await targetDir.exists()) await targetDir.create(recursive: true);

      final fileName = p.basename(zipPath);
      final savedPath = p.join(targetDir.path, fileName);
      await File(zipPath).copy(savedPath);

      return savedPath;
    } catch (e) {
      return null;
    }
  }

  /// Lets the user pick a folder on their device (Downloads, SD card,
  /// wherever) and saves the backup .zip there directly — no share sheet.
  /// Returns the saved file path, or null if the user cancelled.
  static Future<String?> saveBackupToDevice() async {
    final zipPath = await createBackupZip();

    final folder = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Backup Kahan Save Karni Hai Woh Folder Chunein',
    );
    if (folder == null) return null; // user cancelled

    final fileName = p.basename(zipPath);
    final savedPath = p.join(folder, fileName);
    await File(zipPath).copy(savedPath);
    return savedPath;
  }

  static Future<void> restoreFromZip(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final dbDir = await getDatabasesPath();
    final docsDir = await getApplicationDocumentsDirectory();
    final dbEntry =
        archive.where((entry) => entry.name == _dbFileName).firstOrNull;
    if (dbEntry == null || !dbEntry.isFile) {
      throw const FormatException('Backup mein BizManager database nahi mila.');
    }

    final tempDir = await getTemporaryDirectory();
    final tempDbPath = p.join(tempDir.path, 'dukanedge_restore_check.db');
    final tempDbFile = File(tempDbPath);
    await tempDbFile.writeAsBytes(dbEntry.content as List<int>, flush: true);
    await _validateDatabase(tempDbPath);

    for (final entry in archive) {
      final name = entry.name;
      String targetPath;

      if (name == _dbFileName) {
        continue;
      } else if (name.startsWith('company_assets/') ||
          name.startsWith('product_images/')) {
        targetPath = p.join(docsDir.path, name);
      } else {
        continue;
      }

      final normalizedTarget = p.normalize(targetPath);
      final normalizedDocsDir = p.normalize(docsDir.path);
      if (!p.isWithin(normalizedDocsDir, normalizedTarget)) {
        throw const FormatException('Backup mein unsafe asset path mila.');
      }

      if (entry.isFile) {
        final data = entry.content as List<int>;
        final outFile = File(targetPath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(data, flush: true);
      } else {
        await Directory(targetPath).create(recursive: true);
      }
    }

    await DBHelper.instance.closeDatabase();
    await tempDbFile.copy(p.join(dbDir, _dbFileName));
    await tempDbFile.delete();
    await DBHelper.instance.database;
  }

  static Future<void> _validateDatabase(String dbPath) async {
    final database = await openDatabase(dbPath, readOnly: true);
    try {
      final integrity = await database.rawQuery('PRAGMA integrity_check');
      if (integrity.isEmpty || integrity.first.values.first != 'ok') {
        throw const FormatException('Backup database corrupt hai.');
      }

      final tables = await database.rawQuery('''
        SELECT name FROM sqlite_master
        WHERE type = 'table' AND name IN ('companies', 'journal_entries', 'journal_entry_lines')
      ''');
      if (tables.length != 3) {
        throw const FormatException('Backup BizManager database nahi hai.');
      }
    } finally {
      await database.close();
    }
  }

  static const _prefLastAutoBackup = 'last_auto_backup';
  static const _prefAutoBackupEnabled = 'auto_backup_enabled';
  static const _autoBackupIntervalDays = 7;
  static const _maxKeptAutoBackups = 5;

  static Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefAutoBackupEnabled) ?? true;
  }

  static Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoBackupEnabled, enabled);
  }

  static Future<DateTime?> getLastAutoBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_prefLastAutoBackup);
    return iso == null ? null : DateTime.tryParse(iso);
  }

  static Future<void> maybeRunAutoBackup() async {
    if (!await isAutoBackupEnabled()) return;

    final last = await getLastAutoBackupDate();
    if (last != null &&
        DateTime.now().difference(last).inDays < _autoBackupIntervalDays) {
      return;
    }

    try {
      final zipPath = await createBackupZip();
      final docsDir = await getApplicationDocumentsDirectory();
      final autoBackupDir = Directory(p.join(docsDir.path, 'auto_backups'));
      if (!await autoBackupDir.exists())
        await autoBackupDir.create(recursive: true);

      final fileName = p.basename(zipPath);
      final savedPath = p.join(autoBackupDir.path, fileName);
      await File(zipPath).copy(savedPath);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefLastAutoBackup, DateTime.now().toIso8601String());

      final files = autoBackupDir.listSync().whereType<File>().toList()
        ..sort(
            (a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      for (final file in files.skip(_maxKeptAutoBackups)) {
        await file.delete();
      }

      if (await GoogleDriveService.isAutoUploadEnabled()) {
        if (await GoogleDriveService.instance.isSignedIn()) {
          await GoogleDriveService.instance.uploadBackup(savedPath);
        }
      }
    } catch (_) {}
  }
}
