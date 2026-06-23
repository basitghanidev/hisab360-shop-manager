import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/database/database_provider.dart';
import 'package:sentery_app/core/database/daos/customer_dao.dart';
import 'package:sentery_app/core/services/audit_service.dart';
import 'package:drift/drift.dart';

class CustomerRepository {
  final CustomerDao _dao;
  final AuditService _audit;
  CustomerRepository(this._dao, this._audit);

  Stream<List<Customer>> watchAllCustomers() => _dao.watchAllCustomers();
  
  Future<List<Customer>> getAllCustomers() => _dao.getAllCustomers();

  Future<Customer?> getCustomerById(int id) => _dao.getCustomerById(id);
  Stream<Customer?> watchCustomerById(int id) => _dao.watchCustomerById(id);

  Future<int> addCustomer(CustomersCompanion customer) async {
    final id = await _dao.insertCustomer(customer);
    await _audit.logAction(action: 'create', table: 'customers', recordId: id, newData: {'name': customer.name.value});
    return id;
  }

  Future<bool> updateCustomer(Customer customer) async {
    final old = await getCustomerById(customer.id);
    final success = await _dao.updateCustomer(customer);
    if (success) {
      await _audit.logAction(action: 'update', table: 'customers', recordId: customer.id, oldData: old?.toJson(), newData: customer.toJson());
    }
    return success;
  }

  Future<int> deleteCustomer(int id) async {
    final result = await _dao.deleteCustomer(id);
    await _audit.logAction(action: 'delete', table: 'customers', recordId: id);
    return result;
  }

  Future<void> updateBalance(int id, double amountChange) => _dao.updateBalance(id, amountChange);

  Future<List<LedgerEntry>> getCustomerLedger(int id) => _dao.getCustomerLedger(id);
  Future<List<Invoice>> getCustomerInvoices(int id) => _dao.getCustomerInvoices(id);
  Stream<List<Invoice>> watchCustomerInvoices(int id) => _dao.watchCustomerInvoices(id);
}

final customerDaoProvider = Provider<CustomerDao>((ref) {
  return ref.watch(databaseProvider).customerDao;
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.watch(customerDaoProvider), ref.watch(auditServiceProvider));
});

final customersStreamProvider = StreamProvider<List<Customer>>((ref) {
  return ref.watch(customerRepositoryProvider).watchAllCustomers();
});

final customerSearchProvider = StateProvider<String>((ref) => '');

final filteredCustomersProvider = Provider<AsyncValue<List<Customer>>>((ref) {
  final customersAsync = ref.watch(customersStreamProvider);
  final search = ref.watch(customerSearchProvider);
  
  if (search.isEmpty) return customersAsync;

  return customersAsync.whenData((customers) => customers
    .where((c) => c.name.toLowerCase().contains(search.toLowerCase()) || 
                  (c.phone?.contains(search) ?? false))
    .toList());
});

final customerLedgerProvider = FutureProvider.family<List<LedgerEntry>, int>((ref, id) {
  return ref.watch(customerRepositoryProvider).getCustomerLedger(id);
});

final customerInvoicesProvider = StreamProvider.family<List<Invoice>, int>((ref, id) {
  return ref.watch(customerRepositoryProvider).watchCustomerInvoices(id);
});

final customerByIdProvider = StreamProvider.family<Customer?, int>((ref, id) {
  return ref.watch(customerRepositoryProvider).watchCustomerById(id);
});
