import 'package:drift/drift.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/money_utils.dart';

part 'item_dao.g.dart';

@DriftAccessor(tables: [Items, UnitTypes, ItemCategories, StockMovements, StockBatches, ItemPriceHistory])
class ItemDao extends DatabaseAccessor<AppDatabase> with _$ItemDaoMixin {
  ItemDao(super.db);

  Stream<List<Item>> watchAllItems() {
    return (select(items)..where((t) => t.isActive.equals(true))).watch();
  }

  Future<List<Item>> getAllItems() {
    return (select(items)..where((t) => t.isActive.equals(true))).get();
  }

  Future<Item?> getItemById(int id) {
    return (select(items)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertItem(ItemsCompanion item) async {
    return transaction(() async {
      var finalItem = item;
      
      if (item.itemCode.present == false || item.itemCode.value == null || item.itemCode.value!.isEmpty) {
        final code = await generateNextItemCode();
        finalItem = item.copyWith(itemCode: Value(code));
        
        final numericCode = int.parse(code.replaceAll(RegExp(r'[^0-9]'), ''));
        await db.settingsDao.updateSettings(AppSettingsCompanion(lastItemCode: Value(numericCode)));
      }

      final purchasePaisa = item.purchasePrice.value;
      final openingStock = item.currentStock.value;
      
      finalItem = finalItem.copyWith(
        lastPurchasePrice: Value(purchasePaisa),
        averageCost: Value(purchasePaisa),
      );

      final id = await into(items).insert(finalItem);

      if (openingStock > 0) {
        await into(stockBatches).insert(StockBatchesCompanion.insert(
          itemId: id,
          quantityAdded: Value(openingStock),
          quantityRemaining: Value(openingStock),
          purchasePrice: Value(purchasePaisa),
        ));
        
        await into(stockMovements).insert(StockMovementsCompanion.insert(
          itemId: id,
          movementType: 'opening_stock',
          quantity: Value(openingStock),
          balanceAfter: Value(openingStock),
        ));
      }
      
      return id;
    });
  }

  Future<String> generateNextItemCode() async {
    final settings = await db.settingsDao.getSettings();
    int lastCode = settings?.lastItemCode ?? 0;
    
    final allItems = await getAllItems();
    for (var item in allItems) {
      if (item.itemCode != null) {
        final numericPart = int.tryParse(item.itemCode!.replaceAll(RegExp(r'[^0-9]'), ''));
        if (numericPart != null && numericPart > lastCode) {
          lastCode = numericPart;
        }
      }
    }
    
    final nextCode = lastCode + 1;
    return 'ITM-${nextCode.toString().padLeft(6, '0')}';
  }

  Future<bool> updateItem(Item item) {
    return update(items).replace(item);
  }

  Future<int> deleteItem(int id) {
    return (update(items)..where((t) => t.id.equals(id)))
        .write(const ItemsCompanion(isActive: Value(false)));
  }

  Stream<List<ItemCategory>> watchCategories() => select(itemCategories).watch();
  Stream<List<UnitType>> watchUnitTypes() => select(unitTypes).watch();

  Future<int> insertCategory(ItemCategoriesCompanion category) => into(itemCategories).insert(category);
  Future<int> insertUnitType(UnitTypesCompanion unitType) => into(unitTypes).insert(unitType);

  Future<int> deleteCategory(int id) async {
    // Optional: check if items are using this category.
    // For now, just delete. Items using it will have categoryId set to null (drift handles references).
    return (delete(itemCategories)..where((t) => t.id.equals(id))).go();
  }

  Future<void> addStockBatch({
    required int itemId,
    int? supplierId,
    int? purchaseInvoiceId,
    required double quantity,
    required int purchasePrice, 
  }) async {
    return transaction(() async {
      await into(stockBatches).insert(StockBatchesCompanion.insert(
        itemId: itemId,
        supplierId: Value(supplierId),
        purchaseInvoiceId: Value(purchaseInvoiceId),
        quantityAdded: Value(quantity),
        quantityRemaining: Value(quantity),
        purchasePrice: Value(purchasePrice),
      ));

      final item = await getItemById(itemId);
      if (item != null) {
        final mOldTotalCost = Money.fromPaisa(item.averageCost).multiplyByDouble(item.currentStock);
        final mNewBatchCost = Money.fromPaisa(purchasePrice).multiplyByDouble(quantity);
        final double newTotalStock = item.currentStock + quantity;
        final mNewTotalCost = mOldTotalCost + mNewBatchCost;
        
        final newAverageCost = newTotalStock > 0 
            ? (mNewTotalCost.toDouble() / newTotalStock * 100).round() 
            : purchasePrice;

        await (update(items)..where((t) => t.id.equals(itemId))).write(ItemsCompanion(
          currentStock: Value(newTotalStock),
          averageCost: Value(newAverageCost),
          lastPurchasePrice: Value(purchasePrice),
        ));

        await into(stockMovements).insert(StockMovementsCompanion.insert(
          itemId: itemId,
          movementType: 'purchase',
          quantity: Value(quantity),
          balanceAfter: Value(item.currentStock + quantity),
          referenceInvoiceId: Value(purchaseInvoiceId),
        ));

        if (item.purchasePrice != purchasePrice) {
          await into(itemPriceHistory).insert(ItemPriceHistoryCompanion.insert(
            itemId: itemId,
            oldPrice: Value(item.purchasePrice),
            newPrice: Value(purchasePrice),
            priceType: 'purchase',
          ));
        }
      }
    });
  }

  Future<void> addStock(int itemId, double quantity, String type, {int? referenceId}) async {
    final item = await getItemById(itemId);
    if (item == null) return;
    
    await (update(items)..where((t) => t.id.equals(itemId))).write(ItemsCompanion(
      currentStock: Value(item.currentStock + quantity),
    ));

    await into(stockMovements).insert(StockMovementsCompanion.insert(
      itemId: itemId,
      movementType: type,
      quantity: Value(quantity),
      balanceAfter: Value(item.currentStock + quantity),
      referenceInvoiceId: Value(referenceId),
    ));
  }

  Future<void> reduceStock(int itemId, double quantity, String type, {int? referenceId}) async {
    return transaction(() async {
      final item = await getItemById(itemId);
      if (item == null) return;

      // ─── ZERO-STOCK GUARD ──────────────────────────────────────────
      // Hard block: never allow stock to go below 0. If the requested
      // quantity exceeds available stock, throw so the calling invoice
      // transaction rolls back cleanly and the UI shows an error.
      if (item.currentStock < quantity) {
        throw InsufficientStockException(
          itemName: item.name,
          available: item.currentStock,
          requested: quantity,
        );
      }
      // ──────────────────────────────────────────────────────────────

      final batches = await (select(stockBatches)
            ..where((t) => t.itemId.equals(itemId) & t.quantityRemaining.isBiggerThanValue(0))
            ..orderBy([(t) => OrderingTerm.asc(t.purchaseDate)]))
          .get();

      double remainingToReduce = quantity;
      for (final batch in batches) {
        if (remainingToReduce <= 0) break;
        final reduction = batch.quantityRemaining >= remainingToReduce ? remainingToReduce : batch.quantityRemaining;
        await (update(stockBatches)..where((t) => t.id.equals(batch.id))).write(StockBatchesCompanion(
          quantityRemaining: Value(batch.quantityRemaining - reduction),
        ));
        remainingToReduce -= reduction;
      }

      final newStock = item.currentStock - quantity;
      await (update(items)..where((t) => t.id.equals(itemId))).write(ItemsCompanion(
        currentStock: Value(newStock),
      ));

      await into(stockMovements).insert(StockMovementsCompanion.insert(
        itemId: itemId,
        movementType: type,
        quantity: Value(-quantity),
        balanceAfter: Value(newStock),
        referenceInvoiceId: Value(referenceId),
      ));
    });
  }

  Future<List<StockMovement>> getStockMovements(int itemId, {int limit = 50}) {
    return (select(stockMovements)
          ..where((t) => t.itemId.equals(itemId))
          ..orderBy([(t) => OrderingTerm.desc(t.movedAt)])
          ..limit(limit))
        .get();
  }
}

class InsufficientStockException implements Exception {
  final String itemName;
  final double available;
  final double requested;
  const InsufficientStockException({
    required this.itemName,
    required this.available,
    required this.requested,
  });

  @override
  String toString() =>
      'Insufficient stock for "$itemName": available ${available.toStringAsFixed(0)}, '
      'requested ${requested.toStringAsFixed(0)}';
}
