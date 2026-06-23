import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/database/daos/invoice_dao.dart';
import 'package:drift/drift.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('createInvoice is atomic - rolls back on failure', () async {
    // 1. Setup mock data
    await db.into(db.itemCategories).insert(ItemCategoriesCompanion.insert(name: 'Test Cat'));
    await db.into(db.unitTypes).insert(UnitTypesCompanion.insert(name: 'Piece'));
    final itemId = await db.into(db.items).insert(ItemsCompanion.insert(
      name: 'Test Item',
      unitTypeId: 1,
      purchasePrice: const Value(100),
      retailPrice: const Value(150),
      currentStock: const Value(10.0),
    ));
    
    final customerId = await db.into(db.customers).insert(CustomersCompanion.insert(
      name: 'Test Customer',
      currentBalance: const Value(0),
    ));

    final invoice = InvoicesCompanion.insert(
      invoiceNumber: 'INV-001',
      invoiceType: 'sale_retail',
      customerId: Value(customerId),
      totalAmount: const Value(150),
      amountPaid: const Value(0),
      amountRemaining: const Value(150),
    );

    final items = [
      InvoiceItemsCompanion.insert(
        invoiceId: 0,
        itemId: itemId,
        itemNameSnapshot: 'Test Item',
        quantity: const Value(1.0),
        unitTypeSnapshot: 'Piece',
        salePrice: const Value(150),
        costPriceAtSale: const Value(100),
        lineTotal: const Value(150),
      )
    ];

    // 2. Enable simulated crash
    InvoiceDao.debugCrashOnSave = true;

    // 3. Attempt to save and expect failure
    try {
      await db.invoiceDao.createInvoice(
        invoice: invoice,
        items: items,
        initialPayments: [],
      );
      fail('Should have thrown an exception');
    } catch (e) {
      expect(e.toString(), contains('DEBUG_CRASH'));
    }

    // 4. Verify database state - nothing should have changed
    final invoicesCount = (await db.select(db.invoices).get()).length;
    final ledgerCount = (await db.select(db.ledgerEntries).get()).length;
    final item = await db.itemDao.getItemById(itemId);

    expect(invoicesCount, 0, reason: 'Invoice should not have been saved');
    expect(ledgerCount, 0, reason: 'Ledger entry should not have been created');
    expect(item?.currentStock, 10.0, reason: 'Stock should not have been reduced');
    
    final customer = await db.customerDao.getCustomerById(customerId);
    expect(customer?.currentBalance, 0, reason: 'Customer balance should not have been updated');
  });
}
