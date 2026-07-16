import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';
import 'package:sentery_app/features/expenses/providers/expense_provider.dart';

class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesStreamProvider);
    final categoriesAsync = ref.watch(expenseCategoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(
          english: 'Expenses',
          urdu: 'Kharchay',
          englishStyle: AppTextStyles.navTitle,
        ),
      ),
      body: expensesAsync.when(
        data: (expenses) {
          if (expenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.money_off, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('No expenses recorded yet.', style: AppTextStyles.body),
                ],
              ),
            );
          }

          return categoriesAsync.when(
            data: (categories) {
              final catMap = {for (var c in categories) c.id: c.name};
              
              // Group expenses by date
              final grouped = <String, List<dynamic>>{};
              for (final e in expenses) {
                final dateStr = DateFormat('dd MMM yyyy').format(e.date);
                grouped.putIfAbsent(dateStr, () => []).add(e);
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: grouped.length,
                itemBuilder: (context, index) {
                  final dateStr = grouped.keys.elementAt(index);
                  final dayExpenses = grouped[dateStr]!;
                  final dayTotal = dayExpenses.fold(0, (sum, e) => sum + e.amount as int);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(dateStr, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                            Text('Total: ${CurrencyFormatter.formatPaisa(dayTotal)}', 
                                style: AppTextStyles.caption.copyWith(color: AppColors.danger, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      ...dayExpenses.map((e) => AppCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.outbond_outlined, color: AppColors.danger, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(catMap[e.categoryId] ?? 'General', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                                  if (e.notes != null) Text(e.notes!, style: AppTextStyles.caption),
                                ],
                              ),
                            ),
                            Text(CurrencyFormatter.formatPaisa(e.amount), 
                                style: AppTextStyles.body.copyWith(color: AppColors.danger, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error loading categories: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/expenses/add'),
        label: const Text('Add Expense'),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.danger,
      ),
    );
  }
}
