import '../repositories/customer_repository.dart';

/// High-level service for customer operations (create, payments, receivables).
class CustomerService {
  final CustomerRepository _customerRepo;

  CustomerService({required CustomerRepository customerRepository})
      : _customerRepo = customerRepository;

  /// Create a customer and emit event.
  Future<int> createCustomer(Map<String, dynamic> customer) async {
    return await _customerRepo.createCustomer(customer);
  }

  /// Get customer count for dashboards.
  Future<int> getCustomerCount(int companyId) async {
    return await _customerRepo.getCustomerCount(companyId);
  }

  /// Get all customers for a company.
  Future<List<Map<String, dynamic>>> listCustomers(int companyId) async {
    return await _customerRepo.listCustomers(companyId);
  }

  /// Get receivables (customers who owe money).
  Future<List<Map<String, dynamic>>> getReceivables(int companyId) async {
    return await _customerRepo.getReceivables(companyId);
  }

  /// Record a payment from customer — emits PaymentReceivedEvent.
  Future<void> recordPayment({
    required int customerId,
    required int companyId,
    required double amount,
  }) async {
    await _customerRepo.recordPayment(
      customerId: customerId,
      companyId: companyId,
      amount: amount,
    );
    // Event emitted by repository
  }

  /// Update customer details.
  Future<void> updateCustomer(int id, Map<String, dynamic> data) async {
    await _customerRepo.updateCustomer(id, data);
  }

  /// Delete customer (soft-delete).
  Future<void> deleteCustomer(int id) async {
    await _customerRepo.deleteCustomer(id);
  }

  /// Get customer by ID.
  Future<Map<String, dynamic>?> getCustomerById(int id) async {
    return await _customerRepo.getCustomerById(id);
  }
}
