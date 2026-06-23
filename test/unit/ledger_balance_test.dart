import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/money_utils.dart';
import 'package:drift/drift.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Let database initialize (seeds default unit types etc.)
    await db.customStatement('SELECT 1');
  });

  tearDown(() async => db.close());

  group('Ledger — Credit minus Debit equals Net Balance', () {
    test('Fresh customer: ledger entries and currentBalance are consistent', () async {
      // Create customer with 0 opening balance
      final customerId = await db.into(db.customers).insert(
        CustomersCompanion.insert(
          name: 'Test Customer',
          currentBalance: const Value(0),
        ),
      );

      // Simulate: invoice for Rs 1500, Rs 500 paid upfront
      // debit = 1500, credit = 500 -> balanceAfter = 1000
      await db.into(db.ledgerEntries).insert(LedgerEntriesCompanion.insert(
        partyType: 'customer', partyId: customerId,
        entryType: 'invoice',
        credit: const Value(50000), 
        debit: const Value(150000), 
        balanceAfter: const Value(100000),
      ));
      await (db.update(db.customers)..where((t) => t.id.equals(customerId)))
          .write(const CustomersCompanion(currentBalance: Value(100000)));

      // Simulate: customer pays Rs 800
      // credit = 800 -> balanceAfter = 200
      await db.into(db.ledgerEntries).insert(LedgerEntriesCompanion.insert(
        partyType: 'customer', partyId: customerId,
        entryType: 'payment',
        credit: const Value(80000), debit: const Value(0),
        balanceAfter: const Value(20000),
      ));
      await (db.update(db.customers)..where((t) => t.id.equals(customerId)))
          .write(const CustomersCompanion(currentBalance: Value(20000)));

      // Fetch all ledger entries for this customer
      final entries = await (db.select(db.ledgerEntries)
        ..where((t) => t.partyId.equals(customerId) & t.partyType.equals('customer'))
        ..orderBy([(t) => OrderingTerm.desc(t.id)]))
        .get();

      final lastEntry = entries.first;
      final customer = await (db.select(db.customers)..where((t) => t.id.equals(customerId))).getSingle();
      
      expect(customer.currentBalance, equals(lastEntry.balanceAfter));
      expect(customer.currentBalance, equals(20000));
    });

    test('Outstanding totals: customer credit balance never reduces another customer debt', () async {
      await db.into(db.customers).insert(
        CustomersCompanion.insert(name: 'Owes Us', currentBalance: const Value(500000), isActive: const Value(true)));
      await db.into(db.customers).insert(
        CustomersCompanion.insert(name: 'Has Credit', currentBalance: const Value(-200000), isActive: const Value(true)));

      final total = await db.reportDao.getTotalCustomerBalance();
      expect(Money.fromDouble(total).paisa, equals(500000),
          reason: 'Total outstanding must be 500000 paisa (Rs 5000), NOT 300000 (netted with credit)');
    });

    test('Supplier credit balance does not reduce what we owe other suppliers', () async {
      await db.into(db.suppliers).insert(
        SuppliersCompanion.insert(name: 'We Owe Them', currentBalance: const Value(800000), isActive: const Value(true)));
      await db.into(db.suppliers).insert(
        SuppliersCompanion.insert(name: 'We Overpaid', currentBalance: const Value(-150000), isActive: const Value(true)));

      final total = await db.reportDao.getTotalSupplierBalance();
      expect(Money.fromDouble(total).paisa, equals(800000));
    });
  });

  group('getTodayReceived vs getTodayPaid — direction is never mixed', () {
    test('Standalone payment TO a supplier counts as Paid, never Received', () async {
      final supplierId = await db.into(db.suppliers).insert(
          SuppliersCompanion.insert(name: 'Supplier A', currentBalance: const Value(300000)));

      await db.paymentDao.recordPayment(
        method: 'cash', amount: 1000.0,
        supplierId: supplierId, partyType: 'supplier', paymentDirection: 'money_out',
      );

      final received = await db.reportDao.getTodayReceived();
      final paid = await db.reportDao.getTodayPaid();

      expect(received, equals(0.0),
          reason: 'Paying a supplier must NEVER appear as money received');
      expect(Money.fromDouble(paid).paisa, equals(100000),
          reason: 'Rs 1000 paid to supplier must show as money paid');
    });

    test('Standalone payment FROM a customer counts as Received, never Paid', () async {
      final customerId = await db.into(db.customers).insert(
          CustomersCompanion.insert(name: 'Customer A', currentBalance: const Value(200000)));

      await db.paymentDao.recordPayment(
        method: 'cash', amount: 500.0,
        customerId: customerId, partyType: 'customer', paymentDirection: 'money_in',
      );

      final received = await db.reportDao.getTodayReceived();
      final paid = await db.reportDao.getTodayPaid();

      expect(Money.fromDouble(received).paisa, equals(50000));
      expect(paid, equals(0.0));
    });

    test('Customer RETURN does NOT appear in getTodayReceived (refund is not cash received)', () async {
      final customerId = await db.into(db.customers).insert(
          CustomersCompanion.insert(name: 'Return Customer', currentBalance: const Value(100000)));

      // Simulate a return ledger entry — this is what return_dao.dart inserts
      await db.into(db.ledgerEntries).insert(LedgerEntriesCompanion.insert(
        partyType: 'customer', partyId: customerId,
        entryType: 'return',            // ← Must NOT be counted as received
        credit: const Value(30000),
        debit: const Value(0),
        balanceAfter: const Value(70000),
      ));

      final received = await db.reportDao.getTodayReceived();

      expect(received, equals(0.0),
          reason: 'A return credit for a customer is a REFUND, not cash received. '
              'getTodayReceived must exclude entryType==return entries.');
    });
  });
}
