import 'dart:async';
import 'package:get_it/get_it.dart';

/// Marker interface for all domain events. Every event the system emits
/// must extend this class. Examples: SaleCompletedEvent, PaymentReceivedEvent,
/// StockAdjustedEvent, CustomerCreatedEvent.
sealed class DomainEvent {
  const DomainEvent();
  DateTime get occurredAt => DateTime.now();
}

/// A lightweight in-process event bus. Listeners are async; events are
/// dispatched fan-out. The bus does NOT block the publisher — a slow
/// listener cannot delay a sale write.
///
/// Usage:
///   DomainEventBus.instance.on<SaleCompletedEvent>((e) async {
///     await accountingRepo.postSale(e.saleId);
///   });
///   DomainEventBus.instance.emit(SaleCompletedEvent(...));
class DomainEventBus {
  DomainEventBus._();
  static final DomainEventBus instance = DomainEventBus._();

  final Map<Type, List<Function>> _listeners = {};

  /// Register a listener for a specific event type. Returns a function
  /// that, when called, removes the listener (use in dispose() to avoid leaks).
  void Function() on<T extends DomainEvent>(
      FutureOr<void> Function(T) handler) {
    _listeners.putIfAbsent(T, () => []);
    _listeners[T]!.add(handler);
    return () {
      _listeners[T]?.remove(handler);
    };
  }

  /// Emit an event to all registered listeners. Errors are caught and
  /// logged so one bad listener cannot break the others.
  void emit<T extends DomainEvent>(T event) {
    final listeners = _listeners[T];
    if (listeners == null || listeners.isEmpty) return;
    // Copy the list so listeners can safely remove themselves during dispatch.
    final snapshot = List.of(listeners);
    for (final fn in snapshot) {
      try {
        final result = (fn as FutureOr<void> Function(T))(event);
        if (result is Future<void>) {
          result.catchError((e, _) {
            // ignore: avoid_print
            print('⚠️  Event listener for $T threw: $e');
          });
        }
      } catch (e) {
        // ignore: avoid_print
        print('⚠️  Event listener for $T threw: $e');
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Concrete events. These are the "messages" that flow through the system.
// New modules can subscribe to existing events or define their own.
// ---------------------------------------------------------------------------

class SaleCompletedEvent extends DomainEvent {
  final int saleId;
  final int companyId;
  final double total;
  final int? customerId;
  const SaleCompletedEvent({
    required this.saleId,
    required this.companyId,
    required this.total,
    this.customerId,
  });
}

class SaleVoidedEvent extends DomainEvent {
  final int saleId;
  final int companyId;
  const SaleVoidedEvent({required this.saleId, required this.companyId});
}

class PurchaseCompletedEvent extends DomainEvent {
  final int purchaseId;
  final int companyId;
  final double total;
  final int? supplierId;
  const PurchaseCompletedEvent({
    required this.purchaseId,
    required this.companyId,
    required this.total,
    this.supplierId,
  });
}

class PaymentReceivedEvent extends DomainEvent {
  final int customerId;
  final int companyId;
  final double amount;
  const PaymentReceivedEvent({
    required this.customerId,
    required this.companyId,
    required this.amount,
  });
}

class PaymentMadeEvent extends DomainEvent {
  final int supplierId;
  final int companyId;
  final double amount;
  const PaymentMadeEvent({
    required this.supplierId,
    required this.companyId,
    required this.amount,
  });
}

class StockAdjustedEvent extends DomainEvent {
  final int productId;
  final int companyId;
  final double delta;
  final String reason; // 'sale' | 'purchase' | 'manual' | 'return' | 'transfer'
  const StockAdjustedEvent({
    required this.productId,
    required this.companyId,
    required this.delta,
    required this.reason,
  });
}

class ExpenseRecordedEvent extends DomainEvent {
  final int expenseId;
  final int companyId;
  final double amount;
  final String category;
  const ExpenseRecordedEvent({
    required this.expenseId,
    required this.companyId,
    required this.amount,
    required this.category,
  });
}

class CustomerCreatedEvent extends DomainEvent {
  final int customerId;
  final int companyId;
  const CustomerCreatedEvent(
      {required this.customerId, required this.companyId});
}

class SupplierCreatedEvent extends DomainEvent {
  final int supplierId;
  final int companyId;
  const SupplierCreatedEvent(
      {required this.supplierId, required this.companyId});
}

class ProductCreatedEvent extends DomainEvent {
  final int productId;
  final int companyId;
  const ProductCreatedEvent({required this.productId, required this.companyId});
}

/// Convenience accessor for `final bus = sl<DomainEventBus>();` callers.
DomainEventBus get domainEvents => GetIt.instance<DomainEventBus>();
