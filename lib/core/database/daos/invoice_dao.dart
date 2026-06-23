import 'package:drift/drift.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/money_utils.dart';

part 'invoice_dao.g.dart';

@DriftAccessor(tables: [Invoices, InvoiceItems, Payments, Items, StockMovements, LedgerEntries, StockBatches, Suppliers, Wholesalers, Customers])
class InvoiceDao extends DatabaseAccessor<AppDatabase> with _$InvoiceDaoMixin {
  InvoiceDao(super.db);

  static bool debugCrashOnSave = false;

  Stream<List<Invoice>> watchAllInvoices() {
    return (select(invoices)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  }

  Future<Invoice?> getInvoiceById(int id) {
    return (select(invoices)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<InvoiceItem>> getInvoiceItems(int invoiceId) {
    return (select(invoiceItems)..where((t) => t.invoiceId.equals(invoiceId))).get();
  }

  Future<List<Payment>> getInvoicePayments(int invoiceId) {
    return (select(payments)..where((t) => t.invoiceId.equals(invoiceId))).get();
  }

  Future<int> getNextSequence(String prefix) async {
    final year = DateTime.now().year;
    final pattern = '$prefix-$year-%';
    final result = await (select(invoices)..where((t) => t.invoiceNumber.like(pattern))).get();
    return result.length + 1;
  }

  Future<String> generateInvoiceNumber(String type) async {
    String prefix = '';
    if (type == 'purchase') prefix = 'PUR';
    else if (type == 'sale_wholesale') prefix = 'WS';
    else if (type == 'sale_retail') prefix = 'RS';
    else if (type.startsWith('return')) prefix = 'RET';
    else prefix = 'INV';

    final year = DateTime.now().year;
    final seq = await getNextSequence(prefix);
    return '$prefix-$year-${seq.toString().padLeft(6, '0')}';
  }

  Future<int> createInvoice({
    required InvoicesCompanion invoice,
    required List<InvoiceItemsCompanion> items,
    required List<PaymentsCompanion> initialPayments,
  }) async {
    return transaction(() async {
      var finalInvoice = invoice;
      if (invoice.invoiceNumber.present == false || invoice.invoiceNumber.value.isEmpty) {
        final num = await generateInvoiceNumber(invoice.invoiceType.value);
        finalInvoice = invoice.copyWith(invoiceNumber: Value(num));
      }

      final invoiceId = await into(invoices).insert(finalInvoice);

      if (debugCrashOnSave) {
        throw Exception('DEBUG_CRASH: Simulating app failure during transaction save.');
      }

      for (final item in items) {
        final itemWithId = item.copyWith(invoiceId: Value(invoiceId));
        
        int lineProfit = 0;
        if (finalInvoice.invoiceType.value.startsWith('sale')) {
          final mDiff = Money.fromPaisa(item.salePrice.value) - Money.fromPaisa(item.costPriceAtSale.value);
          lineProfit = mDiff.multiplyByDouble(item.quantity.value).paisa;
        }

        await into(invoiceItems).insert(itemWithId.copyWith(lineProfit: Value(lineProfit)));

        final type = finalInvoice.invoiceType.value;
        if (type == 'purchase') {
          await db.itemDao.addStockBatch(
            itemId: item.itemId.value,
            supplierId: finalInvoice.supplierId.value,
            purchaseInvoiceId: invoiceId,
            quantity: item.quantity.value,
            purchasePrice: item.salePrice.value, 
          );
        } else if (type.startsWith('sale')) {
          await db.itemDao.reduceStock(item.itemId.value, item.quantity.value, 'sale', referenceId: invoiceId);
        }
      }

      int totalPaid = 0;
      for (final p in initialPayments) {
        await into(payments).insert(p.copyWith(invoiceId: Value(invoiceId)));
        totalPaid += p.amount.value;
      }

      final total = finalInvoice.totalAmount.value;
      final remaining = total - totalPaid;
      if (remaining != 0 || totalPaid != 0) {
        await _recordToLedger(finalInvoice, invoiceId, totalPaid);
      }

      return invoiceId;
    });
  }

  Future<void> _recordToLedger(InvoicesCompanion inv, int invoiceId, int paid) async {
    final type = inv.invoiceType.value;
    final total = inv.totalAmount.value;

    if (type == 'purchase' && inv.supplierId.value != null) {
      final sId = inv.supplierId.value!;
      final s = await (select(suppliers)..where((t) => t.id.equals(sId))).getSingle();
      final newBalance = s.currentBalance + (total - paid);
      
      await into(ledgerEntries).insert(LedgerEntriesCompanion.insert(
        partyType: 'supplier',
        partyId: sId,
        entryType: 'invoice',
        debit: Value(paid),
        credit: Value(total),
        balanceAfter: Value(newBalance),
        invoiceId: Value(invoiceId),
      ));
      
      await (update(suppliers)..where((t) => t.id.equals(sId))).write(SuppliersCompanion(currentBalance: Value(newBalance)));

    } else if (type == 'sale_wholesale' && inv.wholesalerId.value != null) {
      final wId = inv.wholesalerId.value!;
      final w = await (select(wholesalers)..where((t) => t.id.equals(wId))).getSingle();
      final newBalance = w.currentBalance + (total - paid);

      await into(ledgerEntries).insert(LedgerEntriesCompanion.insert(
        partyType: 'wholesaler',
        partyId: wId,
        entryType: 'invoice',
        debit: Value(total),
        credit: Value(paid),
        balanceAfter: Value(newBalance),
        invoiceId: Value(invoiceId),
      ));
      
      await (update(wholesalers)..where((t) => t.id.equals(wId))).write(WholesalersCompanion(currentBalance: Value(newBalance)));

    } else if (type == 'sale_retail' && inv.customerId.value != null) {
      final cId = inv.customerId.value!;
      final c = await (select(customers)..where((t) => t.id.equals(cId))).getSingle();
      final newBalance = c.currentBalance + (total - paid);

      await into(ledgerEntries).insert(LedgerEntriesCompanion.insert(
        partyType: 'customer',
        partyId: cId,
        entryType: 'invoice',
        debit: Value(total),
        credit: Value(paid),
        balanceAfter: Value(newBalance),
        invoiceId: Value(invoiceId),
      ));
      
      await (update(customers)..where((t) => t.id.equals(cId))).write(CustomersCompanion(currentBalance: Value(newBalance)));
    }
  }
}
