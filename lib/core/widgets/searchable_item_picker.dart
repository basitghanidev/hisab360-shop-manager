import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_strings.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/core/utils/money_utils.dart';
import 'package:sentery_app/features/items/providers/item_provider.dart';

enum ItemPickerMode { purchase, wholesale, retail }

Future<Item?> showItemPicker(
  BuildContext context,
  WidgetRef ref, {
  ItemPickerMode mode = ItemPickerMode.retail,
  Map<int, double>? wholesalerCustomPrices,
}) async {
  return await showModalBottomSheet<Item>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: _ItemPickerSheet(ref: ref, mode: mode, wholesalerCustomPrices: wholesalerCustomPrices),
    ),
  );
}

class _ItemPickerSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  final ItemPickerMode mode;
  final Map<int, double>? wholesalerCustomPrices;
  const _ItemPickerSheet({required this.ref, required this.mode, this.wholesalerCustomPrices});

  @override
  ConsumerState<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends ConsumerState<_ItemPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allItemsAsync = ref.watch(itemsStreamProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(AppStrings.selectItem, style: AppTextStyles.cardTitle),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 8,
              ),
              child: TextField(
                controller: _searchController,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Search by name...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        })
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
              ),
            ),

            Expanded(
              child: allItemsAsync.when(
                data: (items) {
                  final filtered = _query.isEmpty
                      ? items
                      : items.where((i) =>
                          i.name.toLowerCase().contains(_query) ||
                          (i.itemCode?.toLowerCase().contains(_query) ?? false)).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text('"$_query" nahi mila', style: AppTextStyles.body),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final item = filtered[i];
                      final isLowStock = item.currentStock <= item.lowStockLimit;

                      late final int displayPaisa;
                      late final String priceLabel;
                      switch (widget.mode) {
                        case ItemPickerMode.purchase:
                          displayPaisa = item.purchasePrice;
                          priceLabel = 'Cost';
                          break;
                        case ItemPickerMode.wholesale:
                          if (widget.wholesalerCustomPrices?[item.id] != null) {
                            displayPaisa = Money.fromDouble(widget.wholesalerCustomPrices![item.id]!).paisa;
                            priceLabel = 'Custom Price';
                          } else {
                            displayPaisa = item.defaultResellerPrice;
                            priceLabel = 'Wholesale';
                          }
                          break;
                        case ItemPickerMode.retail:
                          displayPaisa = item.retailPrice;
                          priceLabel = 'Retail';
                          break;
                      }

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        title: Text(item.name, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                        subtitle: Text('Stock: ${item.currentStock}', style: AppTextStyles.caption),
                        trailing: ConstrainedBox(
                          // ListTile trailing area is typically constrained to about 72px height.
                          // Constrain explicitly so children never exceed this, preventing overflow.
                          constraints: const BoxConstraints(maxWidth: 90, maxHeight: 72),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min, // Use minimum size to prevent overflow
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  CurrencyFormatter.formatPaisa(displayPaisa),
                                  style: AppTextStyles.body.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Text(
                                priceLabel,
                                style: AppTextStyles.caption.copyWith(color: AppColors.textLight, fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isLowStock)
                                Container(
                                  margin: const EdgeInsets.only(top: 1),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Kam!', // Shortened to save space
                                    style: TextStyle(fontSize: 9, color: AppColors.danger, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        onTap: () => Navigator.pop(context, item),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        tileColor: i % 2 == 0 ? Colors.transparent : Colors.grey[50],
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
