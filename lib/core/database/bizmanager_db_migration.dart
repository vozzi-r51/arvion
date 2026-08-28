import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../services/error_reporter.dart';

/// One-shot DB file migration:
/// When updating Android package ID from `com.arvion.dukanedge` to `com.bizmanager.app`,
/// Android stores data in a new package directory.
/// This helper checks if `bizmanager.db` already exists in the new DB path.
/// If `bizmanager.db` does NOT exist, it checks well-known legacy DB locations for `dukanedge.db`:
///   - `/data/data/com.arvion.dukanedge/databases/dukanedge.db`
///   - `/data/user/0/com.arvion.dukanedge/databases/dukanedge.db`
///   - `/data/data/com.arvion.dukanedge/files/dukanedge.db`
///
/// It also checks the current database directory for legacy `dukanedge.db` (in case package wasn't changed).
///
/// If found, it safely copies `dukanedge.db` (plus `-journal`, `-wal`, `-shm` sidecars)
/// to `bizmanager.db` atomically.
class BizManagerDbMigration {
  BizManagerDbMigration._();

  static const String legacyPackageId = 'com.arvion.dukanedge';
  static const String legacyDbName = 'dukanedge.db';
  static const String newDbName = 'bizmanager.db';

  static Future<void> ensureMigrated() async {
    try {
      final dbDir = await getDatabasesPath();
      final newDbPath = join(dbDir, newDbName);
      final newDbFile = File(newDbPath);

      // Rule: Do not overwrite an existing new database!
      if (await newDbFile.exists()) {
        return;
      }

      // Check candidate locations for legacy database
      final List<String> legacyCandidates = [
        join(dbDir, legacyDbName),
        '/data/data/$legacyPackageId/databases/$legacyDbName',
        '/data/user/0/$legacyPackageId/databases/$legacyDbName',
        '/data/data/$legacyPackageId/files/$legacyDbName',
      ];

      File? legacyFileToMigrate;
      for (final candidate in legacyCandidates) {
        final f = File(candidate);
        if (await f.exists() && (await f.length()) > 0) {
          legacyFileToMigrate = f;
          break;
        }
      }

      if (legacyFileToMigrate == null) {
        // No legacy database found, fresh install
        return;
      }

      final sourcePath = legacyFileToMigrate.path;
      final tempNewDbPath = join(dbDir, '$newDbName.tmp');

      // Atomic copy: copy main DB file to temporary location first
      await legacyFileToMigrate.copy(tempNewDbPath);

      // Copy sidecar files if they exist
      for (final suffix in ['-journal', '-wal', '-shm']) {
        final sidecarSource = File('$sourcePath$suffix');
        if (await sidecarSource.exists()) {
          await sidecarSource.copy('$tempNewDbPath$suffix');
        }
      }

      // Rename temp DB file to final new DB name
      final tempNewFile = File(tempNewDbPath);
      await tempNewFile.rename(newDbPath);

      // Rename sidecar files to final names
      for (final suffix in ['-journal', '-wal', '-shm']) {
        final sidecarTemp = File('$tempNewDbPath$suffix');
        if (await sidecarTemp.exists()) {
          await sidecarTemp.rename('$newDbPath$suffix');
        }
      }

      ErrorReporter.instance.report(
        'Database migrated successfully from ${legacyFileToMigrate.path} to $newDbPath',
        module: 'Migration',
        action: 'db_migration',
      );
    } catch (e, s) {
      // Swallowed safely so startup is not blocked if migration fails
      ErrorReporter.instance.report(
        e,
        module: 'Migration',
        action: 'db_migration_failed',
        stack: s.toString(),
      );
    }
  }
}
