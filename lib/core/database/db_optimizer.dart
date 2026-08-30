import 'package:sqflite/sqflite.dart';

class DBOptimizer {
  /// Applies high-throughput enterprise PRAGMA configurations to SQLite.
  static Future<void> tunePerformance(Database db) async {
    try {
      // 1. Enable Write-Ahead Logging for non-blocking concurrent reads and writes
      await db.execute('PRAGMA journal_mode = WAL;');

      // 2. Set synchronous mode to NORMAL (safe in WAL mode, significantly faster writes)
      await db.execute('PRAGMA synchronous = NORMAL;');

      // 3. Allocate 64MB memory cache for active query index pages
      await db.execute('PRAGMA cache_size = -64000;');

      // 4. Store temporary tables and indices in RAM
      await db.execute('PRAGMA temp_store = MEMORY;');

      // 5. Enable memory-mapped I/O (up to 256MB)
      await db.execute('PRAGMA mmap_size = 268435456;');

      // 6. Hard-enforce foreign key constraints
      await db.execute('PRAGMA foreign_keys = ON;');
    } catch (_) {
      // Graceful fallback for in-memory / FFI test environments
    }
  }
}
