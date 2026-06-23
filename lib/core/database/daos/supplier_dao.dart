import 'package:drift/drift.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/money_utils.dart';

part 'supplier_dao.g.dart';

@DriftAccessor(tables: [Suppliers, Invoices, Payments, LedgerEntries])
class SupplierDao extends DatabaseAccessor<AppDatabase> with _$SupplierDaoMixin {
  SupplierDao(super.db);

  Stream<List<Supplier>> watchAllSuppliers() {
    return (select(suppliers)..where((t) => t.isActive.equals(true))..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  Future<List<Supplier>> getAllSuppliers() {
    return (select(suppliers)..where((t) => t.isActive.equals(true))).get();
  }

  Future<Supplier?> getSupplierById(int id) {
    return (select(suppliers)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<Supplier?> watchSupplierById(int id) {
    return (select(suppliers)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Future<int> insertSupplier(SuppliersCompanion supplier) {
    return into(suppliers).insert(supplier);
  }

  Future<bool> updateSupplier(Supplier supplier) {
    return update(suppliers).replace(supplier);
  }

  Future<int> deleteSupplier(int id) {
    return (update(suppliers)..where((t) => t.id.equals(id)))
        .write(const SuppliersCompanion(isActive: Value(false)));
  }

  Future<void> updateBalance(int id, double amountChange) async {
    final s = await getSupplierById(id);
    if (s != null) {
      final int changePaisa = Money.fromDouble(amountChange).paisa;
      await (update(suppliers)..where((t) => t.id.equals(id)))
          .write(SuppliersCompanion(
        currentBalance: Value(s.currentBalance + changePaisa),
      ));
    }
  }

  Future<List<LedgerEntry>> getSupplierLedger(int supplierId) {
    return (select(ledgerEntries)
      ..where((t) => t.partyType.equals('supplier') & t.partyId.equals(supplierId))
      ..orderBy([(t) => OrderingTerm.desc(t.entryDate), (t) => OrderingTerm.desc(t.id)]))
      .get();
  }

  Future<List<Invoice>> getSupplierInvoices(int supplierId) {
    return (select(invoices)
      ..where((t) => t.supplierId.equals(supplierId))
      ..orderBy([(t) => OrderingTerm.desc(t.invoiceDate)]))
      .get();
  }

  Stream<List<Invoice>> watchSupplierInvoices(int supplierId) {
    return (select(invoices)
      ..where((t) => t.supplierId.equals(supplierId))
      ..orderBy([(t) => OrderingTerm.desc(t.invoiceDate)]))
      .watch();
  }
}
