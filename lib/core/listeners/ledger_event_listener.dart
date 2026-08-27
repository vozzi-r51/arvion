import '../events/domain_event_bus.dart';

/// Listens to receivable/payable events and posts double-entry journal entries.
/// This is where accounting side-effects happen — separate from the core
/// sales/purchase logic. In a real system, these would update the GL.
class LedgerEventListener {
  LedgerEventListener();

  final List<Function> _disposers = [];

  void register() {
    // When a sale completes (e.g., Invoice #123 for $1000):
    // Post: DR Accounts Receivable / CR Sales Revenue
    _disposers.add(
      DomainEventBus.instance.on<SaleCompletedEvent>((e) async {
        // TODO: Insert two journal entries
        // 1. DR: Accounts Receivable (asset) / CR: Sales Revenue (income)
        // Amount: e.total
        // Company: e.companyId
        // Reference: Sale #${e.saleId}
        //
        // Example query:
        // await db.insert('journal_entries', {
        //   'company_id': e.companyId,
        //   'account_id': arAccountId,
        //   'debit': e.total,
        //   'credit': 0,
        //   'reference': 'Sale #${e.saleId}',
        // });
        // await db.insert('journal_entries', {
        //   'company_id': e.companyId,
        //   'account_id': revenueAccountId,
        //   'debit': 0,
        //   'credit': e.total,
        //   'reference': 'Sale #${e.saleId}',
        // });
      }),
    );

    // When a purchase completes (e.g., PO #456 for $500):
    // Post: DR Inventory / CR Accounts Payable
    _disposers.add(
      DomainEventBus.instance.on<PurchaseCompletedEvent>((e) async {
        // TODO: Insert two journal entries
        // 1. DR: Inventory (asset) / CR: Accounts Payable (liability)
        // Amount: e.total
        // Company: e.companyId
        // Reference: Purchase #${e.purchaseId}
      }),
    );

    // When a customer payment is received (e.g., $1000 from customer #5):
    // Post: DR Cash / CR Accounts Receivable
    _disposers.add(
      DomainEventBus.instance.on<PaymentReceivedEvent>((e) async {
        // TODO: Insert two journal entries
        // 1. DR: Cash (asset) / CR: Accounts Receivable (asset, reduces)
        // Amount: e.amount
        // Company: e.companyId
        // Reference: Payment from Customer #${e.customerId}
      }),
    );

    // When a supplier payment is made (e.g., $500 to supplier #3):
    // Post: DR Accounts Payable / CR Cash
    _disposers.add(
      DomainEventBus.instance.on<PaymentMadeEvent>((e) async {
        // TODO: Insert two journal entries
        // 1. DR: Accounts Payable (liability, reduces) / CR: Cash (asset)
        // Amount: e.amount
        // Company: e.companyId
        // Reference: Payment to Supplier #${e.supplierId}
      }),
    );

    // When an expense is recorded (e.g., $100 office supplies):
    // Post: DR Expense Category / CR Cash
    _disposers.add(
      DomainEventBus.instance.on<ExpenseRecordedEvent>((e) async {
        // TODO: Insert two journal entries
        // 1. DR: Expense (e.g., "Office Supplies") / CR: Cash
        // Amount: e.amount
        // Category: e.category
        // Company: e.companyId
        // Reference: Expense #${e.expenseId}
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

