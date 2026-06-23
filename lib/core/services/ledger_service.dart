import 'package:drift/drift.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/money_utils.dart';

class LedgerService {
  final AppDatabase _db;

  LedgerService(this._db);

  Future<void> addEntry({
    required String partyType,
    required int partyId,
    required String entryType,
    required double debit, // double from UI
    required double credit, // double from UI
    int? invoiceId,
    int? paymentId,
    String? notes,
    DateTime? entryDate,
  }) async {
    await _db.transaction(() async {
      final int debitPaisa = Money.fromDouble(debit).paisa;
      final int creditPaisa = Money.fromDouble(credit).paisa;
      
      int currentBalance = await getPartyBalancePaisa(partyType, partyId);

      int newBalance;
      if (partyType == 'supplier') {
        newBalance = currentBalance + creditPaisa - debitPaisa;
      } else {
        newBalance = currentBalance + debitPaisa - creditPaisa;
      }

      await _db.into(_db.ledgerEntries).insert(LedgerEntriesCompanion.insert(
            partyType: partyType,
            partyId: partyId,
            entryType: entryType,
            debit: Value(debitPaisa),
            credit: Value(creditPaisa),
            balanceAfter: Value(newBalance),
            invoiceId: Value(invoiceId),
            paymentId: Value(paymentId),
            notes: Value(notes),
            entryDate: Value(entryDate ?? DateTime.now()),
          ));

      if (partyType == 'customer') {
        await (_db.update(_db.customers)..where((t) => t.id.equals(partyId)))
            .write(CustomersCompanion(currentBalance: Value(newBalance)));
      } else if (partyType == 'wholesaler') {
        await (_db.update(_db.wholesalers)..where((t) => t.id.equals(partyId)))
            .write(WholesalersCompanion(currentBalance: Value(newBalance)));
      } else if (partyType == 'supplier') {
        await (_db.update(_db.suppliers)..where((t) => t.id.equals(partyId)))
            .write(SuppliersCompanion(currentBalance: Value(newBalance)));
      }
    });
  }

  Future<int> getPartyBalancePaisa(String partyType, int partyId) async {
    if (partyType == 'customer') {
      final p = await (_db.select(_db.customers)..where((t) => t.id.equals(partyId))).getSingleOrNull();
      return p?.currentBalance ?? 0;
    } else if (partyType == 'wholesaler') {
      final p = await (_db.select(_db.wholesalers)..where((t) => t.id.equals(partyId))).getSingleOrNull();
      return p?.currentBalance ?? 0;
    } else if (partyType == 'supplier') {
      final p = await (_db.select(_db.suppliers)..where((t) => t.id.equals(partyId))).getSingleOrNull();
      return p?.currentBalance ?? 0;
    }
    return 0;
  }

  Future<double> getPartyBalance(String partyType, int partyId) async {
    final int paisa = await getPartyBalancePaisa(partyType, partyId);
    return Money.fromPaisa(paisa).toDouble();
  }

  Future<void> recalculatePartyBalance(String partyType, int partyId) async {
    final entries = await (_db.select(_db.ledgerEntries)
          ..where((t) => t.partyType.equals(partyType) & t.partyId.equals(partyId))
          ..orderBy([(t) => OrderingTerm(expression: t.entryDate, mode: OrderingMode.asc), (t) => OrderingTerm(expression: t.id, mode: OrderingMode.asc)]))
        .get();

    int runningBalance = 0;
    
    await _db.transaction(() async {
      for (var entry in entries) {
        if (partyType == 'supplier') {
          runningBalance += (entry.credit - entry.debit);
        } else {
          runningBalance += (entry.debit - entry.credit);
        }

        await (_db.update(_db.ledgerEntries)..where((t) => t.id.equals(entry.id)))
            .write(LedgerEntriesCompanion(balanceAfter: Value(runningBalance)));
      }

      if (partyType == 'customer') {
        await (_db.update(_db.customers)..where((t) => t.id.equals(partyId)))
            .write(CustomersCompanion(currentBalance: Value(runningBalance)));
      } else if (partyType == 'wholesaler') {
        await (_db.update(_db.wholesalers)..where((t) => t.id.equals(partyId)))
            .write(WholesalersCompanion(currentBalance: Value(runningBalance)));
      } else if (partyType == 'supplier') {
        await (_db.update(_db.suppliers)..where((t) => t.id.equals(partyId)))
            .write(SuppliersCompanion(currentBalance: Value(runningBalance)));
      }
    });
  }
}
