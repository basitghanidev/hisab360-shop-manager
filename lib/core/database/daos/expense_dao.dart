import 'package:drift/drift.dart';
import 'package:sentery_app/core/database/app_database.dart';

part 'expense_dao.g.dart';

@DriftAccessor(tables: [Expenses, ExpenseCategories])
class ExpenseDao extends DatabaseAccessor<AppDatabase> with _$ExpenseDaoMixin {
  ExpenseDao(super.db);

  Stream<List<Expense>> watchAllExpenses() {
    return (select(expenses)..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();
  }

  Future<int> insertExpense(ExpensesCompanion entry) => into(expenses).insert(entry);

  Future<bool> updateExpense(Expense entry) => update(expenses).replace(entry);

  Future<int> deleteExpense(int id) => (delete(expenses)..where((t) => t.id.equals(id))).go();

  Stream<List<ExpenseCategory>> watchCategories() => select(expenseCategories).watch();
  
  Future<int> insertCategory(ExpenseCategoriesCompanion category) => into(expenseCategories).insert(category);
}
