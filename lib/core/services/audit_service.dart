import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/database/database_provider.dart';
import 'package:sentery_app/core/database/daos/audit_dao.dart';

class AuditService {
  final AuditDao _dao;
  AuditService(this._dao);

  Future<void> logAction({
    required String action,
    required String table,
    required int recordId,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
  }) async {
    await _dao.log(
      action,
      table,
      recordId,
      oldVal: oldData != null ? jsonEncode(oldData) : null,
      newVal: newData != null ? jsonEncode(newData) : null,
    );
  }

  Future<List<dynamic>> getLogs() => _dao.getLogs();
}

final auditDaoProvider = Provider<AuditDao>((ref) {
  return ref.watch(databaseProvider).auditDao;
});

final auditServiceProvider = Provider<AuditService>((ref) {
  return AuditService(ref.watch(auditDaoProvider));
});
