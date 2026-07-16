import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';
import 'package:sentery_app/features/expenses/providers/expense_provider.dart';
import 'package:drift/drift.dart' as drift;

class ExpenseCategoryManagementScreen extends ConsumerWidget {
  const ExpenseCategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(expenseCategoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(
          english: 'Expense Categories',
          urdu: 'Kharchay Ki Aqsaam',
          englishStyle: AppTextStyles.navTitle,
        ),
      ),
      body: categoriesAsync.when(
        data: (categories) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return AppCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(category.name, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                subtitle: category.nameUrdu != null ? Text(category.nameUrdu!) : null,
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(context, ref),
        label: const Text('Add Expense Type'),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final urduController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Expense Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Category Name (English)'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urduController,
              decoration: const InputDecoration(labelText: 'Urdu Name (Optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await ref.read(expenseDaoProvider).insertCategory(
                  ExpenseCategoriesCompanion.insert(
                    name: nameController.text.trim(),
                    nameUrdu: drift.Value(urduController.text.isNotEmpty ? urduController.text.trim() : null),
                  ),
                );
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
