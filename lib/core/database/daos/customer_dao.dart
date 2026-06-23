import 'package:drift/drift.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/money_utils.dart';

part 'customer_dao.g.dart';

@DriftAccessor(tables: [Customers, Invoices, Payments, LedgerEntries])
class CustomerDao extends DatabaseAccessor<AppDatabase> with _$CustomerDaoMixin {
  CustomerDao(super.db);

  Stream<List<Customer>> watchAllCustomers() {
    return (select(customers)..where((t) => t.isActive.equals(true))..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  Future<List<Customer>> getAllCustomers() {
    return (select(customers)..where((t) => t.isActive.equals(true))).get();
  }

  Future<Customer?> getCustomerById(int id) {
    return (select(customers)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<Customer?> watchCustomerById(int id) {
    return (select(customers)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Future<int> insertCustomer(CustomersCompanion customer) {
    return into(customers).insert(customer);
  }

  Future<bool> updateCustomer(Customer customer) {
    return update(customers).replace(customer);
  }

  Future<int> deleteCustomer(int id) {
    return (update(customers)..where((t) => t.id.equals(id)))
        .write(const CustomersCompanion(isActive: Value(false)));
  }

  Future<void> updateBalance(int id, double amountChange) async {
    final c = await getCustomerById(id);
    if (c != null) {
      final int changePaisa = Money.fromDouble(amountChange).paisa;
      await (update(customers)..where((t) => t.id.equals(id)))
          .write(CustomersCompanion(
        currentBalance: Value(c.currentBalance + changePaisa),
      ));
    }
  }

  Future<List<LedgerEntry>> getCustomerLedger(int customerId) {
    return (select(ledgerEntries)
      ..where((t) => t.partyType.equals('customer') & t.partyId.equals(customerId))
      ..orderBy([(t) => OrderingTerm.desc(t.entryDate), (t) => OrderingTerm.desc(t.id)]))
      .get();
  }

  Future<List<Invoice>> getCustomerInvoices(int customerId) {
    return (select(invoices)
      ..where((t) => t.customerId.equals(customerId))
      ..orderBy([(t) => OrderingTerm.desc(t.invoiceDate)]))
      .get();
  }

  Stream<List<Invoice>> watchCustomerInvoices(int customerId) {
    return (select(invoices)
      ..where((t) => t.customerId.equals(customerId))
      ..orderBy([(t) => OrderingTerm.desc(t.invoiceDate)]))
      .watch();
  }
}
