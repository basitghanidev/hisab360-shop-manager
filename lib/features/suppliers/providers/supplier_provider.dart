import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/database/database_provider.dart';
import 'package:sentery_app/core/database/daos/supplier_dao.dart';
import 'package:sentery_app/core/services/audit_service.dart';
import 'package:drift/drift.dart';

class SupplierRepository {
  final SupplierDao _dao;
  final AuditService _audit;
  SupplierRepository(this._dao, this._audit);

  Stream<List<Supplier>> watchAllSuppliers() => _dao.watchAllSuppliers();
  
  Future<List<Supplier>> getAllSuppliers() => _dao.getAllSuppliers();

  Future<Supplier?> getSupplierById(int id) => _dao.getSupplierById(id);
  Stream<Supplier?> watchSupplierById(int id) => _dao.watchSupplierById(id);

  Future<int> addSupplier(SuppliersCompanion supplier) async {
    final id = await _dao.insertSupplier(supplier);
    await _audit.logAction(action: 'create', table: 'suppliers', recordId: id, newData: {'name': supplier.name.value});
    return id;
  }

  Future<bool> updateSupplier(Supplier supplier) async {
    final old = await getSupplierById(supplier.id);
    final success = await _dao.updateSupplier(supplier);
    if (success) {
      await _audit.logAction(action: 'update', table: 'suppliers', recordId: supplier.id, oldData: old?.toJson(), newData: supplier.toJson());
    }
    return success;
  }

  Future<int> deleteSupplier(int id) async {
    final result = await _dao.deleteSupplier(id);
    await _audit.logAction(action: 'delete', table: 'suppliers', recordId: id);
    return result;
  }

  Future<void> updateBalance(int id, double amountChange) => _dao.updateBalance(id, amountChange);

  Future<List<LedgerEntry>> getSupplierLedger(int id) => _dao.getSupplierLedger(id);
  Future<List<Invoice>> getSupplierInvoices(int id) => _dao.getSupplierInvoices(id);
  Stream<List<Invoice>> watchSupplierInvoices(int id) => _dao.watchSupplierInvoices(id);
}

final supplierDaoProvider = Provider<SupplierDao>((ref) {
  return ref.watch(databaseProvider).supplierDao;
});

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return SupplierRepository(ref.watch(supplierDaoProvider), ref.watch(auditServiceProvider));
});

final suppliersStreamProvider = StreamProvider<List<Supplier>>((ref) {
  return ref.watch(supplierRepositoryProvider).watchAllSuppliers();
});

final supplierSearchProvider = StateProvider<String>((ref) => '');

final filteredSuppliersProvider = Provider<AsyncValue<List<Supplier>>>((ref) {
  final suppliersAsync = ref.watch(suppliersStreamProvider);
  final search = ref.watch(supplierSearchProvider);
  
  if (search.isEmpty) return suppliersAsync;

  return suppliersAsync.whenData((suppliers) => suppliers
    .where((s) => s.name.toLowerCase().contains(search.toLowerCase()) || 
                  (s.phone?.contains(search) ?? false))
    .toList());
});

final supplierLedgerProvider = FutureProvider.family<List<LedgerEntry>, int>((ref, id) {
  return ref.watch(supplierRepositoryProvider).getSupplierLedger(id);
});

final supplierInvoicesProvider = StreamProvider.family<List<Invoice>, int>((ref, id) {
  return ref.watch(supplierRepositoryProvider).watchSupplierInvoices(id);
});

final supplierByIdProvider = StreamProvider.family<Supplier?, int>((ref, id) {
  return ref.watch(supplierRepositoryProvider).watchSupplierById(id);
});
