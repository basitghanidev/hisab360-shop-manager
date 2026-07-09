import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/features/items/providers/item_provider.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';
import 'package:drift/drift.dart' as drift;

class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(
          english: 'Manage Categories',
          urdu: 'Categories Badlen',
          englishStyle: AppTextStyles.navTitle,
        ),
      ),
      body: categoriesAsync.when(
        data: (categories) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: categories.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final category = categories[index];
            return ListTile(
              tileColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              title: Text(category.name, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
              subtitle: category.nameUrdu != null ? Text(category.nameUrdu!) : null,
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _showDeleteConfirmation(context, ref, category),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final nameUrduController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Category Name (English)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameUrduController,
              decoration: const InputDecoration(labelText: 'Category Name (Urdu - Optional)'),
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
                    name: nameController.text,
                    nameUrdu: drift.Value(nameUrduController.text.isEmpty ? null : nameUrduController.text),
                  ),
                );
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, ItemCategory category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Are you sure you want to delete "${category.name}"? Items linked to this category will lose their category.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ref.read(itemRepositoryProvider).deleteCategory(category.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
