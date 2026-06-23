import 'package:drift/drift.dart';
import 'package:sentery_app/core/database/app_database.dart';

part 'audit_dao.g.dart';

@DriftAccessor(tables: [AuditLogs])
class AuditDao extends DatabaseAccessor<AppDatabase> with _$AuditDaoMixin {
  AuditDao(super.db);

  Future<int> log(String action, String table, int id, {String? oldVal, String? newVal}) {
    return into(auditLogs).insert(AuditLogsCompanion.insert(
      actionName: action,
      targetTable: table, // Updated column name
      recordId: id,
      oldValue: Value(oldVal),
      newValue: Value(newVal),
    ));
  }

  Future<List<AuditLog>> getLogs({int limit = 100}) {
    return (select(auditLogs)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])..limit(limit)).get();
  }
}
