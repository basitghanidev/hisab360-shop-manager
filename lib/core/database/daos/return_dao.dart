import 'package:drift/drift.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/money_utils.dart';

part 'return_dao.g.dart';

@DriftAccessor(tables: [Invoices, InvoiceItems, Items, StockMovements, Suppliers, Wholesalers, Customers, LedgerEntries, StockBatches])
class ReturnDao extends DatabaseAccessor<AppDatabase> with _$ReturnDaoMixin {
  ReturnDao(super.db);

  Future<int> createReturnInvoice({
    required InvoicesCompanion returnInvoice,
    required List<InvoiceItemsCompanion> returnedItems,
    int amountPaidToday = 0,
    String? paymentMethod,
  }) async {
    return transaction(() async {
      final type = returnInvoice.invoiceType.value;
      final year = DateTime.now().year;
      final seq = (await (select(invoices)..where((t) => t.invoiceNumber.like('RET-$year-%'))).get()).length + 1;
      final invoiceNumber = 'RET-$year-${seq.toString().padLeft(6, '0')}';
      
      final finalReturnInvoice = returnInvoice.copyWith(
        invoiceNumber: Value(invoiceNumber),
        amountPaid: Value(amountPaidToday),
        amountRemaining: Value(returnInvoice.totalAmount.value - amountPaidToday),
        status: Value(amountPaidToday >= returnInvoice.totalAmount.value ? 'paid' : 'returned'),
      );

      final invoiceId = await into(invoices).insert(finalReturnInvoice);

      for (final item in returnedItems) {
        final itemWithId = item.copyWith(invoiceId: Value(invoiceId));
        await into(invoiceItems).insert(itemWithId);

        final isOut = type == 'return_supplier';
        
        if (isOut) {
          await db.itemDao.reduceStock(item.itemId.value, item.quantity.value, type, referenceId: invoiceId);
        } else {
          await db.itemDao.addStockBatch(
            itemId: item.itemId.value,
            quantity: item.quantity.value,
            purchasePrice: item.costPriceAtSale.value, 
            purchaseInvoiceId: invoiceId,
          );
        }
      }

      // Record internal payment if any amount was paid back to customer/supplier
      int paymentId = 0;
      if (amountPaidToday > 0) {
        paymentId = await into(payments).insert(PaymentsCompanion.insert(
          invoiceId: Value(invoiceId),
          paymentMethod: paymentMethod ?? 'cash',
          amount: Value(amountPaidToday),
          paymentDate: Value(DateTime.now()),
          paymentDirection: Value(type == 'return_supplier' ? 'money_in' : 'money_out'),
          partyId: Value(finalReturnInvoice.supplierId.value ?? finalReturnInvoice.wholesalerId.value ?? finalReturnInvoice.customerId.value),
          partyType: Value(type == 'return_supplier' ? 'supplier' : (type == 'return_wholesaler' ? 'wholesaler' : 'customer')),
        ));
      }

      final totalReturnAmount = finalReturnInvoice.totalAmount.value;
      final unpaidReturnAmount = totalReturnAmount - amountPaidToday;

      if (type == 'return_supplier' && finalReturnInvoice.supplierId.value != null) {
        final sId = finalReturnInvoice.supplierId.value!;
        final s = await (select(suppliers)..where((t) => t.id.equals(sId))).getSingle();
        // If we return items to supplier, they owe us money.
        // Balance increases if we haven't received cash yet.
        // supplier: positive = we owe them, negative = they owe us.
        // So balance decreases by unpaid amount.
        final newBalance = s.currentBalance - unpaidReturnAmount; 

        await into(ledgerEntries).insert(LedgerEntriesCompanion.insert(
          partyType: 'supplier',
          partyId: sId,
          entryType: 'return',
          debit: const Value(0),
          credit: Value(totalReturnAmount),
          balanceAfter: Value(newBalance),
          invoiceId: Value(invoiceId),
          paymentId: amountPaidToday > 0 ? Value(paymentId) : const Value.absent(),
        ));
        await (update(suppliers)..where((t) => t.id.equals(sId))).write(SuppliersCompanion(currentBalance: Value(newBalance)));

      } else if (type == 'return_wholesaler' && finalReturnInvoice.wholesalerId.value != null) {
        final wId = finalReturnInvoice.wholesalerId.value!;
        final w = await (select(wholesalers)..where((t) => t.id.equals(wId))).getSingle();
        // Return from wholesaler: we owe them money.
        // customer/wholesaler: positive = they owe us, negative = we owe them.
        // So balance decreases by unpaid amount.
        final newBalance = w.currentBalance - unpaidReturnAmount; 

        await into(ledgerEntries).insert(LedgerEntriesCompanion.insert(
          partyType: 'wholesaler',
          partyId: wId,
          entryType: 'return',
          debit: const Value(0),
          credit: Value(totalReturnAmount),
          balanceAfter: Value(newBalance),
          invoiceId: Value(invoiceId),
          paymentId: amountPaidToday > 0 ? Value(paymentId) : const Value.absent(),
        ));
        await (update(wholesalers)..where((t) => t.id.equals(wId))).write(WholesalersCompanion(currentBalance: Value(newBalance)));

      } else if (type == 'return_customer' && finalReturnInvoice.customerId.value != null) {
        final cId = finalReturnInvoice.customerId.value!;
        final c = await (select(customers)..where((t) => t.id.equals(cId))).getSingle();
        final newBalance = c.currentBalance - unpaidReturnAmount;

        await into(ledgerEntries).insert(LedgerEntriesCompanion.insert(
          partyType: 'customer',
          partyId: cId,
          entryType: 'return',
          debit: const Value(0),
          credit: Value(totalReturnAmount),
          balanceAfter: Value(newBalance),
          invoiceId: Value(invoiceId),
          paymentId: amountPaidToday > 0 ? Value(paymentId) : const Value.absent(),
        ));
        await (update(customers)..where((t) => t.id.equals(cId))).write(CustomersCompanion(currentBalance: Value(newBalance)));
      }

      return invoiceId;
    });
  }
}
