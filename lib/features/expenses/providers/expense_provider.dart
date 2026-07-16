import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/database/database_provider.dart';

final expenseDaoProvider = Provider((ref) => ref.watch(databaseProvider).expenseDao);

final expensesStreamProvider = StreamProvider<List<Expense>>((ref) {
  return ref.watch(expenseDaoProvider).watchAllExpenses();
});

final expenseCategoriesStreamProvider = StreamProvider<List<ExpenseCategory>>((ref) {
  return ref.watch(expenseDaoProvider).watchCategories();
});
