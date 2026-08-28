import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:bizmanager/core/events/domain_event_bus.dart';
import 'package:bizmanager/core/repositories/sales_repository.dart';
import 'package:bizmanager/core/repositories/purchase_repository.dart';
import 'package:bizmanager/core/repositories/inventory_repository.dart';
import 'package:bizmanager/core/repositories/accounting_repository.dart';
import 'package:bizmanager/core/repositories/customer_repository.dart';
import 'package:bizmanager/core/repositories/hr_repository.dart';

class FakeSalesRepository extends SalesRepository {
  bool createSaleCalled = false;

  @override
  Future<int> createSale({
    required Map<String, dynamic> sale,
    required List<Map<String, dynamic>> items,
    int? costCenterId,
  }) async {
    createSaleCalled = true;
    DomainEventBus.instance.emit(SaleCompletedEvent(
      saleId: 999,
      companyId: sale['company_id'] as int? ?? 1,
      total: (sale['total'] as num?)?.toDouble() ?? 500.0,
    ));
    return 999;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Domain Event Bus & Event Dispatching Tests', () {
    test('DomainEventBus dispatches events to registered listeners with timestamp', () async {
      final bus = DomainEventBus.instance;
      SaleCompletedEvent? receivedEvent;

      final unsubscribe = bus.on<SaleCompletedEvent>((e) {
        receivedEvent = e;
      });

      bus.emit(const SaleCompletedEvent(
        saleId: 101,
        companyId: 1,
        total: 1250.0,
      ));

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.saleId, equals(101));
      expect(receivedEvent!.total, equals(1250.0));
      expect(receivedEvent!.occurredAt, isNotNull);

      unsubscribe();
    });

    test('Listener exceptions are isolated and do not break event dispatching', () {
      final bus = DomainEventBus.instance;
      bool healthyListenerCalled = false;

      bus.on<PurchaseCompletedEvent>((e) {
        throw FormatException('Simulated listener error');
      });

      bus.on<PurchaseCompletedEvent>((e) {
        healthyListenerCalled = true;
      });

      expect(
        () => bus.emit(const PurchaseCompletedEvent(
          purchaseId: 202,
          companyId: 1,
          total: 800.0,
        )),
        returnsNormally,
      );

      expect(healthyListenerCalled, isTrue);
    });
  });

  group('Service Locator & Repository Dependency Injection Tests', () {
    test('GetIt service locator allows swapping repositories with fakes for testing', () async {
      final sl = GetIt.instance;

      if (sl.isRegistered<SalesRepository>()) {
        sl.unregister<SalesRepository>();
      }

      final fakeRepo = FakeSalesRepository();
      sl.registerSingleton<SalesRepository>(fakeRepo);

      final repo = sl<SalesRepository>();
      expect(repo, isA<FakeSalesRepository>());

      bool eventHandled = false;
      DomainEventBus.instance.on<SaleCompletedEvent>((e) {
        eventHandled = true;
      });

      final saleId = await repo.createSale(
        sale: {'company_id': 1, 'total': 500.0},
        items: [],
      );

      expect(saleId, equals(999));
      expect(fakeRepo.createSaleCalled, isTrue);
      expect(eventHandled, isTrue);
    });
  });

  group('Repositories Instantiation & Domain Boundaries', () {
    test('Domain repositories initialize correctly', () {
      expect(PurchaseRepository(), isNotNull);
      expect(InventoryRepository(), isNotNull);
      expect(AccountingRepository(), isNotNull);
      expect(CustomerRepository(), isNotNull);
      expect(HrRepository(), isNotNull);
    });
  });
}
