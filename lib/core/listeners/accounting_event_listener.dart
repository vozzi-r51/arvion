import '../audit/audit_logger.dart';
import '../events/domain_event_bus.dart';
import '../repositories/accounting_repository.dart';
import '../di/service_locator.dart';

/// Listens to domain events for decoupled cross-module reactions
/// (Audit Logging, Double-Entry General Ledger posting, etc.).
class AccountingEventListener {
  AccountingEventListener();

  final List<Function> _disposers = [];

  void register() {
    _disposers.add(
      DomainEventBus.instance.on<SaleCompletedEvent>((e) async {
        await AuditLogger.log(
          companyId: e.companyId,
          module: 'Sales',
          action: 'create',
          description: 'Sale #${e.saleId} completed: total ${e.total}',
        );

        if (sl.isRegistered<AccountingRepository>()) {
          await sl<AccountingRepository>().postSaleJournalEntry(e);
        }
      }),
    );
    _disposers.add(
      DomainEventBus.instance.on<SaleVoidedEvent>((e) async {
        await AuditLogger.log(
          companyId: e.companyId,
          module: 'Sales',
          action: 'void',
          description: 'Sale #${e.saleId} voided',
        );
      }),
    );
    _disposers.add(
      DomainEventBus.instance.on<PaymentReceivedEvent>((e) async {
        await AuditLogger.log(
          companyId: e.companyId,
          module: 'Receivables',
          action: 'payment',
          description:
              'Payment received from customer #${e.customerId}: ${e.amount}',
        );
      }),
    );
    _disposers.add(
      DomainEventBus.instance.on<StockAdjustedEvent>((e) async {
        await AuditLogger.log(
          companyId: e.companyId,
          module: 'Inventory',
          action: 'adjust',
          description:
              'Stock for product #${e.productId} changed by ${e.delta} (${e.reason})',
        );
      }),
    );
    _disposers.add(
      DomainEventBus.instance.on<ExpenseRecordedEvent>((e) async {
        await AuditLogger.log(
          companyId: e.companyId,
          module: 'Expense',
          action: 'create',
          description: 'Expense #${e.expenseId} (${e.category}): ${e.amount}',
        );
      }),
    );
  }

  void dispose() {
    for (final d in _disposers) {
      d();
    }
    _disposers.clear();
  }
}
