import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:drift/drift.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customStatement('SELECT 1');
  });

  tearDown(() async => db.close());

  group('ACID — invoice creation is atomic', () {
    test('If invoice items fail, the invoice header is also rolled back', () async {
      final initialCount = (await db.select(db.invoices).get()).length;

      try {
        await db.transaction(() async {
          // Insert the invoice
          await db.into(db.invoices).insert(InvoicesCompanion.insert(
            invoiceNumber: 'TEST-001',
            invoiceType: 'sale_retail',
            totalAmount: const Value(50000),
            amountPaid: const Value(50000),
            amountRemaining: const Value(0),
            status: const Value('paid'),
            previousBalance: const Value(0),
            totalBalanceAfter: const Value(0),
          ));

          // Simulate a crash mid-transaction by throwing
          throw Exception('Simulated crash after invoice header, before items');
        });
      } catch (_) {} // Expected — swallow the error

      final finalCount = (await db.select(db.invoices).get()).length;
      expect(finalCount, equals(initialCount),
          reason: 'Invoice header must be rolled back if transaction fails');
    });

    test('Stock reduction and ledger entry are both committed together', () async {
      // Add a unit type
      final unitId = await db.into(db.unitTypes).insert(UnitTypesCompanion.insert(name: 'Piece'));

      // Add an item with 10 in stock
      final itemId = await db.into(db.items).insert(ItemsCompanion.insert(
        name: 'Test Item',
        unitTypeId: unitId,
        currentStock: const Value(10.0),
        purchasePrice: const Value(5000),
        retailPrice: const Value(8000),
        averageCost: const Value(5000),
      ));

      // Reduce stock by 3
      await db.itemDao.reduceStock(itemId, 3.0, 'sale', referenceId: null);

      final updatedItem = await (db.select(db.items)..where((t) => t.id.equals(itemId))).getSingle();
      expect(updatedItem.currentStock, equals(7.0),
          reason: 'Stock must be exactly 10 - 3 = 7 after sale');

      // Verify stock movement was logged
      final movements = await (db.select(db.stockMovements)
        ..where((t) => t.itemId.equals(itemId))).get();
      expect(movements.length, equals(1));
      expect(movements.first.quantity, equals(-3.0));
      expect(movements.first.balanceAfter, equals(7.0));
    });

    test('Duplicate invoice number attempt — handled by unique constraint', () async {
      await db.into(db.invoices).insert(InvoicesCompanion.insert(
        invoiceNumber: 'DUP-001',
        invoiceType: 'sale_retail',
        totalAmount: const Value(10000),
        amountPaid: const Value(10000),
        amountRemaining: const Value(0),
        status: const Value('paid'),
        previousBalance: const Value(0),
        totalBalanceAfter: const Value(0),
      ));

      expect(
        () => db.into(db.invoices).insert(InvoicesCompanion.insert(
          invoiceNumber: 'DUP-001',
          invoiceType: 'sale_retail',
          totalAmount: const Value(20000),
          amountPaid: const Value(20000),
          amountRemaining: const Value(0),
          status: const Value('paid'),
          previousBalance: const Value(0),
          totalBalanceAfter: const Value(0),
        )),
        throwsA(isA<SqliteException>()),
      );
    });
  });
}
