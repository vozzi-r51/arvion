import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';

/// Base class for every repository. Holds a reference to the shared
/// [Database] handle that [DBHelper] provides. Subclasses use [db] to
/// run queries inside their slice of responsibility.
///
/// Repositories NEVER call each other directly — they communicate through
/// the [DomainEventBus]. If a sale write needs the accounting side-effects,
/// it emits a `SaleCompletedEvent` and an accounting listener reacts.
abstract class BaseRepository {
  Database get db => DBHelper.instance.db;

  /// Run [action] inside a transaction. Always prefer this over manual
  /// `db.transaction` calls in repositories.
  Future<T> runInTransaction<T>(Future<T> Function(Transaction txn) action) async {
    return await db.transaction(action);
  }
}
