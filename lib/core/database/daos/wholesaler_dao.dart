import 'package:drift/drift.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/money_utils.dart';

part 'wholesaler_dao.g.dart';

@DriftAccessor(tables: [Wholesalers, WholesalerItemPrices, PriceLog, Items, LedgerEntries, Invoices])
class WholesalerDao extends DatabaseAccessor<AppDatabase> with _$WholesalerDaoMixin {
  WholesalerDao(super.db);

  Stream<List<Wholesaler>> watchAllWholesalers() {
    return (select(wholesalers)..where((t) => t.isActive.equals(true))..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  Future<List<Wholesaler>> getAllWholesalers() {
    return (select(wholesalers)..where((t) => t.isActive.equals(true))).get();
  }

  Future<Wholesaler?> getWholesalerById(int id) {
    return (select(wholesalers)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<Wholesaler?> watchWholesalerById(int id) {
    return (select(wholesalers)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Future<int> insertWholesaler(WholesalersCompanion wholesaler) {
    return into(wholesalers).insert(wholesaler);
  }

  Future<bool> updateWholesaler(Wholesaler wholesaler) {
    return update(wholesalers).replace(wholesaler);
  }

  Future<int> deleteWholesaler(int id) {
    return (update(wholesalers)..where((t) => t.id.equals(id)))
        .write(const WholesalersCompanion(isActive: Value(false)));
  }

  Future<void> updateBalance(int id, double amountChange) async {
    final w = await getWholesalerById(id);
    if (w != null) {
      final int changePaisa = Money.fromDouble(amountChange).paisa;
      await (update(wholesalers)..where((t) => t.id.equals(id)))
          .write(WholesalersCompanion(
        currentBalance: Value(w.currentBalance + changePaisa),
      ));
    }
  }

  Future<List<WholesalerItemPrice>> getCustomPrices(int wholesalerId) {
    return (select(wholesalerItemPrices)..where((t) => t.wholesalerId.equals(wholesalerId) & t.isActive.equals(true))).get();
  }

  Future<void> setCustomPrice(int wholesalerId, int itemId, double price, {String? notes}) async {
    final int pricePaisa = Money.fromDouble(price).paisa;
    await transaction(() async {
      await (update(wholesalerItemPrices)..where((t) => t.wholesalerId.equals(wholesalerId) & t.itemId.equals(itemId)))
          .write(WholesalerItemPricesCompanion(isActive: const Value(false), effectiveTo: Value(DateTime.now())));

      await into(wholesalerItemPrices).insert(WholesalerItemPricesCompanion.insert(
        wholesalerId: wholesalerId,
        itemId: itemId,
        customPrice: Value(pricePaisa),
        notes: Value(notes),
      ));

      await into(priceLog).insert(PriceLogCompanion.insert(
        wholesalerId: wholesalerId,
        itemId: itemId,
        price: Value(pricePaisa),
        reason: Value(notes),
      ));
    });
  }

  Future<List<PriceLogData>> getPriceHistory(int wholesalerId, int itemId) {
    return (select(priceLog)
      ..where((t) => t.wholesalerId.equals(wholesalerId) & t.itemId.equals(itemId))
      ..orderBy([(t) => OrderingTerm.desc(t.changedAt)]))
      .get();
  }

  Future<List<LedgerEntry>> getWholesalerLedger(int wholesalerId) {
    return (select(ledgerEntries)
      ..where((t) => t.partyType.equals('wholesaler') & t.partyId.equals(wholesalerId))
      ..orderBy([(t) => OrderingTerm.desc(t.entryDate), (t) => OrderingTerm.desc(t.id)]))
      .get();
  }

  Future<List<Invoice>> getWholesalerInvoices(int wholesalerId) {
    return (select(invoices)
      ..where((t) => t.wholesalerId.equals(wholesalerId))
      ..orderBy([(t) => OrderingTerm.desc(t.invoiceDate)]))
      .get();
  }

  Stream<List<Invoice>> watchWholesalerInvoices(int wholesalerId) {
    return (select(invoices)
      ..where((t) => t.wholesalerId.equals(wholesalerId))
      ..orderBy([(t) => OrderingTerm.desc(t.invoiceDate)]))
      .watch();
  }

  Future<void> removeCustomPrice(int wholesalerId, int itemId) async {
    await (delete(wholesalerItemPrices)
          ..where((t) => t.wholesalerId.equals(wholesalerId) & t.itemId.equals(itemId)))
        .go();
  }
}
