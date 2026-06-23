import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/services/ledger_service.dart';

import 'package:sentery_app/core/services/draft_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final ledgerServiceProvider = Provider<LedgerService>((ref) {
  return LedgerService(ref.watch(databaseProvider));
});

final draftServiceProvider = Provider<DraftService>((ref) {
  return DraftService(ref.watch(databaseProvider).draftDao);
});
