import 'package:drift/drift.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/money_utils.dart';

part 'payment_dao.g.dart';

@DriftAccessor(tables: [Payments, Invoices, Suppliers, Wholesalers, Customers, LedgerEntries])
class PaymentDao extends DatabaseAccessor<AppDatabase> with _$PaymentDaoMixin {
  PaymentDao(super.db);

  Future<int> recordPayment({
    required String method,
    required double amount,
    int? supplierId,
    int? wholesalerId,
    int? customerId,
    int? invoiceId,
    String? onlineMethod,
    String? transId,
    String? senderName,
    String? accountNumber,
    String? notes,
    required String paymentDirection, 
    required String partyType,
  }) async {
    return transaction(() async {
      final int amountPaisa = Money.fromDouble(amount).paisa;

      final paymentId = await into(payments).insert(PaymentsCompanion.insert(
        invoiceId: Value(invoiceId), 
        paymentMethod: method,
        amount: Value(amountPaisa),
        onlineMethod: Value(onlineMethod),
        transactionId: Value(transId),
        senderName: Value(senderName),
        accountNumber: Value(accountNumber),
        notes: Value(notes),
        paymentDirection: Value(paymentDirection),
        partyId: Value(supplierId ?? wholesalerId ?? customerId),
        partyType: Value(partyType),
      ));

      Invoice? linkedInv;
      int previousRemaining = 0;
      if (invoiceId != null) {
        linkedInv = await (select(invoices)..where((t) => t.id.equals(invoiceId))).getSingle();
        previousRemaining = linkedInv.amountRemaining;
        final newPaid = linkedInv.amountPaid + amountPaisa;
        final newRemaining = linkedInv.totalAmount - newPaid;
        final newStatus = newRemaining <= 0 ? 'paid' : 'partial';
        
        await (update(invoices)..where((t) => t.id.equals(invoiceId))).write(InvoicesCompanion(
          amountPaid: Value(newPaid),
          amountRemaining: Value(newRemaining),
          status: Value(newStatus),
        ));
      }

      int partyBalance = 0;
      String partyName = 'Unknown';
      int change = 0;
      
      if (partyType == 'supplier' && supplierId != null) {
        final s = await (select(suppliers)..where((t) => t.id.equals(supplierId))).getSingle();
        partyName = s.name;
        change = paymentDirection == 'money_out' ? -amountPaisa : amountPaisa;
        partyBalance = s.currentBalance + change;
        
        await into(ledgerEntries).insert(LedgerEntriesCompanion.insert(
          partyType: 'supplier',
          partyId: supplierId,
          entryType: 'payment',
          debit: Value(paymentDirection == 'money_out' ? amountPaisa : 0),
          credit: Value(paymentDirection == 'money_in' ? amountPaisa : 0),
          balanceAfter: Value(partyBalance),
          invoiceId: Value(invoiceId),
          paymentId: Value(paymentId),
          notes: Value(notes),
        ));
        await (update(suppliers)..where((t) => t.id.equals(supplierId))).write(SuppliersCompanion(currentBalance: Value(partyBalance)));

      } else if (partyType == 'wholesaler' && wholesalerId != null) {
        final w = await (select(wholesalers)..where((t) => t.id.equals(wholesalerId))).getSingle();
        partyName = w.name;
        change = paymentDirection == 'money_in' ? -amountPaisa : amountPaisa;
        partyBalance = w.currentBalance + change;

        await into(ledgerEntries).insert(LedgerEntriesCompanion.insert(
          partyType: 'wholesaler',
          partyId: wholesalerId,
          entryType: 'payment',
          debit: Value(paymentDirection == 'money_out' ? amountPaisa : 0),
          credit: Value(paymentDirection == 'money_in' ? amountPaisa : 0),
          balanceAfter: Value(partyBalance),
          invoiceId: Value(invoiceId),
          paymentId: Value(paymentId),
          notes: Value(notes),
        ));
        await (update(wholesalers)..where((t) => t.id.equals(wholesalerId))).write(WholesalersCompanion(currentBalance: Value(partyBalance)));

      } else if (partyType == 'customer' && customerId != null) {
        final c = await (select(customers)..where((t) => t.id.equals(customerId))).getSingle();
        partyName = c.name;
        change = paymentDirection == 'money_in' ? -amountPaisa : amountPaisa;
        partyBalance = c.currentBalance + change;

        await into(ledgerEntries).insert(LedgerEntriesCompanion.insert(
          partyType: 'customer',
          partyId: customerId,
          entryType: 'payment',
          debit: Value(paymentDirection == 'money_out' ? amountPaisa : 0),
          credit: Value(paymentDirection == 'money_in' ? amountPaisa : 0),
          balanceAfter: Value(partyBalance),
          invoiceId: Value(invoiceId),
          paymentId: Value(paymentId),
          notes: Value(notes),
        ));
        await (update(customers)..where((t) => t.id.equals(customerId))).write(CustomersCompanion(currentBalance: Value(partyBalance)));
      }

      final receiptNumber = await _generateReceiptNumber();
      final invType = '${partyType}_payment_receipt';

      String receiptNotes;
      if (invoiceId != null && linkedInv != null) {
        final newRemaining = previousRemaining - amountPaisa;
        receiptNotes =
            'Previous Bill: ${linkedInv.invoiceNumber}\n'
            'Remaining Before: ${Money.fromPaisa(previousRemaining)}\n'
            'Paid Today: ${Money.fromPaisa(amountPaisa)}\n'
            'Remaining After: ${Money.fromPaisa(newRemaining)}';
      } else {
        receiptNotes = notes ?? 'Standalone payment (not linked to a specific bill)';
      }

      await into(invoices).insert(InvoicesCompanion.insert(
        invoiceNumber: receiptNumber,
        invoiceType: invType,
        totalAmount: Value(amountPaisa),
        amountPaid: Value(amountPaisa),
        amountRemaining: const Value(0),
        status: const Value('paid'),
        
        partyNameSnapshot: Value(partyName),
        partyTypeSnapshot: Value(partyType),
        
        previousBalance: Value(partyBalance - change), 
        totalBalanceAfter: Value(partyBalance),
        
        paymentMethod: Value(method),
        onlineMethod: Value(onlineMethod),
        transactionId: Value(transId),
        accountNumber: Value(accountNumber),
        senderName: Value(senderName),
        
        linkedInvoiceId: Value(invoiceId),
        linkedInvoiceNumberSnapshot: Value(linkedInv?.invoiceNumber),
        receiptPreviousRemaining: Value(previousRemaining),
        receiptPaidToday: Value(amountPaisa),
        receiptFinalRemaining: Value(previousRemaining - amountPaisa),
        
        notes: Value(receiptNotes),
        customerId: Value(customerId),
        wholesalerId: Value(wholesalerId),
        supplierId: Value(supplierId),
      ));

      return paymentId;
    });
  }

  Future<String> _generateReceiptNumber() async {
    final year = DateTime.now().year;
    final pattern = 'PAY-$year-%';
    final result = await (select(invoices)..where((t) => t.invoiceNumber.like(pattern))).get();
    final seq = result.length + 1;
    return 'PAY-$year-${seq.toString().padLeft(6, '0')}';
  }
}
