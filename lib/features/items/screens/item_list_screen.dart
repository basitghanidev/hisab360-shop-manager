import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_strings.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';
import 'package:sentery_app/features/items/providers/item_provider.dart';

// Category filter state — 'all' or a specific category id as string
final itemCategoryFilterProvider = StateProvider<int?>((ref) => null);

class ItemListScreen extends ConsumerWidget {
  const ItemListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(filteredItemsProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final categoryFilter = ref.watch(itemCategoryFilterProvider);
    final searchController = TextEditingController(text: ref.read(itemSearchProvider));

    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(
          english: AppStrings.items,
          urdu: AppStrings.itemsRoman,
          englishStyle: AppTextStyles.navTitle,
        ),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => context.push('/items/add')),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: CupertinoSearchTextField(
                  controller: searchController,
                  placeholder: 'Search by name or code',
                  onChanged: (value) => ref.read(itemSearchProvider.notifier).state = value,
                ),
              ),
              // Category filter chips
              SizedBox(
                height: 40,
                child: categoriesAsync.when(
                  data: (categories) => ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _categoryChip(ref, null, 'All Items', categoryFilter),
                      ...categories.map((c) => _categoryChip(ref, c.id, c.name, categoryFilter)),
                    ],
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(itemsStreamProvider);
          ref.invalidate(itemCategoryFilterProvider);
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: itemsAsync.when(
          data: (items) {
            // Apply category filter on top of the existing search filter
            final filtered = categoryFilter == null
                ? items
                : items.where((i) => i.categoryId == categoryFilter).toList();

            if (filtered.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    const Text('No items found', style: AppTextStyles.body),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index];
                final isLowStock = item.currentStock <= item.lowStockLimit;

                return AppCard(
                  onTap: () => context.push('/items/${item.id}'),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: (isLowStock ? AppColors.danger : AppColors.primary).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.inventory_2, color: isLowStock ? AppColors.danger : AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: AppTextStyles.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (item.itemCode != null && item.itemCode!.isNotEmpty)
                              Text(item.itemCode!, style: AppTextStyles.caption.copyWith(color: AppColors.textLight)),
                            Row(
                              children: [
                                Text('Retail: ${CurrencyFormatter.formatPaisa(item.retailPrice)}',
                                    style: AppTextStyles.subheadline.copyWith(color: AppColors.textSecondary, fontSize: 13)),
                                const SizedBox(width: 6),
                                Text('•', style: TextStyle(color: AppColors.textLight)),
                                const SizedBox(width: 6),
                                Text('Cost: ${CurrencyFormatter.formatPaisa(item.purchasePrice)}',
                                    style: AppTextStyles.caption.copyWith(color: AppColors.textLight)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${item.currentStock}',
                              style: AppTextStyles.largeTitle.copyWith(
                                  fontSize: 20, color: isLowStock ? AppColors.danger : AppColors.success)),
                          Text(isLowStock ? 'Low Stock' : 'In Stock',
                              style: AppTextStyles.caption.copyWith(
                                  color: isLowStock ? AppColors.danger : AppColors.success, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, color: AppColors.textLight),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  Widget _categoryChip(WidgetRef ref, int? categoryId, String label, int? currentFilter) {
    final isSelected = currentFilter == categoryId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.textPrimary)),
        selected: isSelected,
        selectedColor: AppColors.primary,
        backgroundColor: Colors.grey[100],
        onSelected: (_) => ref.read(itemCategoryFilterProvider.notifier).state = categoryId,
      ),
    );
  }
}
