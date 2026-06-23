import 'package:drift/drift.dart';
import 'package:sentery_app/core/database/app_database.dart';

part 'draft_dao.g.dart';

@DriftAccessor(tables: [DraftInvoices])
class DraftDao extends DatabaseAccessor<AppDatabase> with _$DraftDaoMixin {
  DraftDao(super.db);

  Stream<List<DraftInvoice>> watchAllDrafts() {
    return (select(draftInvoices)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();
  }

  Future<DraftInvoice?> getDraftByType(String type) {
    return (select(draftInvoices)..where((t) => t.draftType.equals(type))).getSingleOrNull();
  }

  Future<int> upsertDraft(DraftInvoicesCompanion draft) async {
    final existing = await getDraftByType(draft.draftType.value);
    if (existing != null) {
      await (update(draftInvoices)..where((t) => t.id.equals(existing.id))).write(
        draft.copyWith(updatedAt: Value(DateTime.now())),
      );
      return existing.id;
    } else {
      return into(draftInvoices).insert(draft);
    }
  }

  Future<void> deleteDraft(int id) {
    return (delete(draftInvoices)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteDraftByType(String type) {
    return (delete(draftInvoices)..where((t) => t.draftType.equals(type))).go();
  }
}
