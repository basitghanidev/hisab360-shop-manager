import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';
import 'package:sentery_app/features/items/providers/item_provider.dart';
import 'package:drift/drift.dart' as drift;

class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(
          english: 'Item Categories',
          urdu: 'Maal Ki Aqsaam',
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
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () => _confirmDelete(context, ref, category),
                ),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(context, ref),
        label: const Text('Add Category'),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final urduController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Category'),
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
                await ref.read(itemRepositoryProvider).addCategory(
                  ItemCategoriesCompanion.insert(
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

  void _confirmDelete(BuildContext context, WidgetRef ref, ItemCategory category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Are you sure you want to delete "${category.name}"? Items in this category will become uncategorized.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(itemRepositoryProvider).deleteCategory(category.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
