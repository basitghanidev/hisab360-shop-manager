import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/database/database_provider.dart';
import 'package:sentery_app/core/database/daos/return_dao.dart';
import 'package:sentery_app/core/services/audit_service.dart';
import 'package:drift/drift.dart';

class ReturnRepository {
  final ReturnDao _dao;
  final AuditService _audit;
  ReturnRepository(this._dao, this._audit);

  Future<int> createReturnInvoice({
    required InvoicesCompanion returnInvoice,
    required List<InvoiceItemsCompanion> returnedItems,
    int amountPaidToday = 0,
    String? paymentMethod,
  }) async {
    final id = await _dao.createReturnInvoice(
      returnInvoice: returnInvoice,
      returnedItems: returnedItems,
      amountPaidToday: amountPaidToday,
      paymentMethod: paymentMethod,
    );
    await _audit.logAction(action: 'create_return', table: 'invoices', recordId: id, newData: {'type': returnInvoice.invoiceType.value});
    return id;
  }
}

final returnDaoProvider = Provider<ReturnDao>((ref) {
  return ref.watch(databaseProvider).returnDao;
});

final returnRepositoryProvider = Provider<ReturnRepository>((ref) {
  return ReturnRepository(ref.watch(returnDaoProvider), ref.watch(auditServiceProvider));
});
