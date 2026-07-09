import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/database/database_provider.dart';
import 'package:sentery_app/core/database/daos/item_dao.dart';
import 'package:sentery_app/core/utils/item_utils.dart';
import 'package:sentery_app/core/utils/money_utils.dart';
import 'package:sentery_app/core/services/audit_service.dart';
import 'package:drift/drift.dart';

class ItemRepository {
  final ItemDao _dao;
  final AuditService _audit;
  ItemRepository(this._dao, this._audit);

  Stream<List<Item>> watchAllItems() => _dao.watchAllItems();
  
  Future<List<Item>> getAllItems() => _dao.getAllItems();

  Future<Item?> getItemById(int id) => _dao.getItemById(id);

  Future<int> addItem(ItemsCompanion item) async {
    final id = await _dao.insertItem(item);
    await _audit.logAction(action: 'create', table: 'items', recordId: id, newData: {'name': item.name.value});
    return id;
  }

  Future<bool> updateItem(Item item) async {
    final old = await getItemById(item.id);
    final success = await _dao.updateItem(item);
    if (success) {
      await _audit.logAction(action: 'update', table: 'items', recordId: item.id, oldData: old?.toJson(), newData: item.toJson());
    }
    return success;
  }

  Future<int> deleteItem(int id) async {
    final result = await _dao.deleteItem(id);
    await _audit.logAction(action: 'delete', table: 'items', recordId: id);
    return result;
  }

  Stream<List<ItemCategory>> watchCategories() => _dao.watchCategories();
  Stream<List<UnitType>> watchUnitTypes() => _dao.watchUnitTypes();

  Future<int> addCategory(ItemCategoriesCompanion category) async {
    final id = await _dao.insertCategory(category);
    await _audit.logAction(action: 'create', table: 'item_categories', recordId: id, newData: {'name': category.name.value});
    return id;
  }

  Future<int> deleteCategory(int id) async {
    final result = await _dao.deleteCategory(id);
    await _audit.logAction(action: 'delete', table: 'item_categories', recordId: id);
    return result;
  }

  Future<void> addStockBatch({
    required int itemId,
    int? supplierId,
    int? purchaseInvoiceId,
    required double quantity,
    required int purchasePrice, 
  }) => _dao.addStockBatch(
    itemId: itemId, 
    supplierId: supplierId, 
    purchaseInvoiceId: purchaseInvoiceId, 
    quantity: quantity, 
    purchasePrice: purchasePrice,
  );
}

final itemDaoProvider = Provider<ItemDao>((ref) {
  return ref.watch(databaseProvider).itemDao;
});

final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  return ItemRepository(ref.watch(itemDaoProvider), ref.watch(auditServiceProvider));
});

final itemsStreamProvider = StreamProvider<List<Item>>((ref) {
  return ref.watch(itemRepositoryProvider).watchAllItems();
});

final itemSearchProvider = StateProvider<String>((ref) => '');

final filteredItemsProvider = Provider<AsyncValue<List<Item>>>((ref) {
  final wholesalersAsync = ref.watch(itemsStreamProvider);
  final search = ref.watch(itemSearchProvider);
  
  if (search.isEmpty) return wholesalersAsync;

  return wholesalersAsync.whenData((items) => items
    .where((i) => i.name.toLowerCase().contains(search.toLowerCase()) || 
                  (i.itemCode?.toLowerCase().contains(search.toLowerCase()) ?? false))
    .toList());
});

final categoriesStreamProvider = StreamProvider<List<ItemCategory>>((ref) {
  return ref.watch(itemRepositoryProvider).watchCategories();
});

final unitTypesStreamProvider = StreamProvider<List<UnitType>>((ref) {
  return ref.watch(itemRepositoryProvider).watchUnitTypes();
});

final unitTypeByIdProvider = FutureProvider.family<UnitType?, int>((ref, id) async {
  final db = ref.watch(databaseProvider);
  return (db.select(db.unitTypes)..where((t) => t.id.equals(id))).getSingleOrNull();
});

final unitTypesMapProvider = FutureProvider<Map<int, String>>((ref) async {
  final db = ref.watch(databaseProvider);
  final types = await db.select(db.unitTypes).get();
  return {for (final t in types) t.id: t.name};
});

final totalStockValueProvider = FutureProvider<double>((ref) async {
  final items = await ref.watch(itemRepositoryProvider).getAllItems();
  int totalPaisa = 0;
  for (final item in items) {
    totalPaisa += Money.fromPaisa(getEffectiveCost(item)).multiplyByDouble(item.currentStock).paisa;
  }
  return Money.fromPaisa(totalPaisa).toDouble();
});

final itemStockMovementsProvider = FutureProvider.family<List<StockMovement>, int>((ref, itemId) {
  return ref.watch(itemDaoProvider).getStockMovements(itemId);
});
