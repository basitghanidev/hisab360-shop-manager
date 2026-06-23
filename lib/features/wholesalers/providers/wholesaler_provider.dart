import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/database/database_provider.dart';
import 'package:sentery_app/core/database/daos/wholesaler_dao.dart';
import 'package:sentery_app/core/services/audit_service.dart';
import 'package:drift/drift.dart';

class WholesalerRepository {
  final WholesalerDao _dao;
  final AuditService _audit;
  WholesalerRepository(this._dao, this._audit);

  Stream<List<Wholesaler>> watchAllWholesalers() => _dao.watchAllWholesalers();
  
  Future<List<Wholesaler>> getAllWholesalers() => _dao.getAllWholesalers();

  Future<Wholesaler?> getWholesalerById(int id) => _dao.getWholesalerById(id);
  Stream<Wholesaler?> watchWholesalerById(int id) => _dao.watchWholesalerById(id);

  Future<int> addWholesaler(WholesalersCompanion wholesaler) async {
    final id = await _dao.insertWholesaler(wholesaler);
    await _audit.logAction(action: 'create', table: 'wholesalers', recordId: id, newData: {'name': wholesaler.name.value});
    return id;
  }

  Future<bool> updateWholesaler(Wholesaler wholesaler) async {
    final old = await getWholesalerById(wholesaler.id);
    final success = await _dao.updateWholesaler(wholesaler);
    if (success) {
      await _audit.logAction(action: 'update', table: 'wholesalers', recordId: wholesaler.id, oldData: old?.toJson(), newData: wholesaler.toJson());
    }
    return success;
  }

  Future<int> deleteWholesaler(int id) async {
    final result = await _dao.deleteWholesaler(id);
    await _audit.logAction(action: 'delete', table: 'wholesalers', recordId: id);
    return result;
  }

  Future<List<WholesalerItemPrice>> getCustomPrices(int wholesalerId) => _dao.getCustomPrices(wholesalerId);

  Future<void> setCustomPrice(int wholesalerId, int itemId, double price, {String? notes}) async {
    await _dao.setCustomPrice(wholesalerId, itemId, price, notes: notes);
    await _audit.logAction(action: 'price_change', table: 'wholesaler_item_prices', recordId: wholesalerId, newData: {'itemId': itemId, 'price': price});
  }

  Future<List<PriceLogData>> getPriceHistory(int wholesalerId, int itemId) => 
    _dao.getPriceHistory(wholesalerId, itemId);

  Future<List<LedgerEntry>> getWholesalerLedger(int id) => _dao.getWholesalerLedger(id);
  Future<List<Invoice>> getWholesalerInvoices(int id) => _dao.getWholesalerInvoices(id);
  Stream<List<Invoice>> watchWholesalerInvoices(int id) => _dao.watchWholesalerInvoices(id);

  Future<void> removeCustomPrice(int wholesalerId, int itemId) async {
    await (_dao.removeCustomPrice(wholesalerId, itemId));
  }
}

final wholesalerDaoProvider = Provider<WholesalerDao>((ref) {
  return ref.watch(databaseProvider).wholesalerDao;
});

final wholesalerRepositoryProvider = Provider<WholesalerRepository>((ref) {
  return WholesalerRepository(ref.watch(wholesalerDaoProvider), ref.watch(auditServiceProvider));
});

final wholesalersStreamProvider = StreamProvider<List<Wholesaler>>((ref) {
  return ref.watch(wholesalerRepositoryProvider).watchAllWholesalers();
});

final wholesalerSearchProvider = StateProvider<String>((ref) => '');

final filteredWholesalersProvider = Provider<AsyncValue<List<Wholesaler>>>((ref) {
  final wholesalersAsync = ref.watch(wholesalersStreamProvider);
  final search = ref.watch(wholesalerSearchProvider);
  
  if (search.isEmpty) return wholesalersAsync;

  return wholesalersAsync.whenData((wholesalers) => wholesalers
    .where((w) => w.name.toLowerCase().contains(search.toLowerCase()) || 
                  (w.phone?.contains(search) ?? false))
    .toList());
});

final wholesalerLedgerProvider = FutureProvider.family<List<LedgerEntry>, int>((ref, id) {
  return ref.watch(wholesalerRepositoryProvider).getWholesalerLedger(id);
});

final wholesalerInvoicesProvider = StreamProvider.family<List<Invoice>, int>((ref, id) {
  return ref.watch(wholesalerRepositoryProvider).watchWholesalerInvoices(id);
});

final wholesalerByIdProvider = StreamProvider.family<Wholesaler?, int>((ref, id) {
  return ref.watch(wholesalerRepositoryProvider).watchWholesalerById(id);
});
