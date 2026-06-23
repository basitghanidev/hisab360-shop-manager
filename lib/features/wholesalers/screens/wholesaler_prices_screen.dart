import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/core/utils/money_utils.dart';
import 'package:sentery_app/features/wholesalers/providers/wholesaler_provider.dart';
import 'package:sentery_app/features/items/providers/item_provider.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';
import 'package:sentery_app/core/utils/balance_label_helper.dart';
import 'package:sentery_app/core/database/app_database.dart';

final wholesalerCustomPricesProvider = FutureProvider.family<List<WholesalerItemPrice>, int>((ref, wholesalerId) {
  return ref.read(wholesalerRepositoryProvider).getCustomPrices(wholesalerId);
});

class WholesalerPricesScreen extends ConsumerWidget {
  final int id;
  const WholesalerPricesScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(itemsStreamProvider);
    final customPricesAsync = ref.watch(wholesalerCustomPricesProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(
          english: 'Custom Item Prices',
          urdu: 'Is Seller Ki Qeemat',
          englishStyle: AppTextStyles.navTitle,
        ),
      ),
      body: itemsAsync.when(
        data: (allItems) {
          return customPricesAsync.when(
            data: (customPrices) {
              if (allItems.isEmpty) {
                return const Center(child: Text('No items found. Add items first.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: allItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = allItems[index];
                  final wholesalerItemPrice = firstWhereOrNull(customPrices, (p) => p.itemId == item.id);
                  final displayPaisa = wholesalerItemPrice?.customPrice ?? item.defaultResellerPrice;
                  final isCustom = wholesalerItemPrice != null;

                  return AppCard(
                    onTap: () => _showEditPriceDialog(context, ref, item, wholesalerItemPrice),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name, style: AppTextStyles.cardTitle),
                              Text(
                                isCustom ? '✓ Custom Price Set (Khas Qeemat)' : 'Default Price (Normal Qeemat)',
                                style: AppTextStyles.caption.copyWith(
                                  color: isCustom ? AppColors.success : AppColors.textLight,
                                  fontWeight: isCustom ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.formatPaisa(displayPaisa),
                              style: AppTextStyles.body.copyWith(
                                color: isCustom ? AppColors.success : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (isCustom)
                              Text(
                                'Default: ${CurrencyFormatter.formatPaisa(item.defaultResellerPrice)}',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textLight,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error loading prices: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading items: $err')),
      ),
    );
  }

  void _showEditPriceDialog(BuildContext context, WidgetRef ref, Item item, WholesalerItemPrice? currentPrice) {
    final controller = TextEditingController(
      text: Money.fromPaisa(currentPrice?.customPrice ?? item.defaultResellerPrice).toDouble().toString(),
    );

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(item.name),
        content: Column(
          children: [
            const SizedBox(height: 8),
            const Text(
              'Is seller ke liye qeemat set karein\n(Doosron par asar nahi hoga)',
              style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              placeholder: 'Nai Qeemat Likhein',
              autofocus: true,
              prefix: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('Rs.', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Purchase: ${CurrencyFormatter.formatPaisa(item.purchasePrice)}',
                    style: const TextStyle(fontSize: 11)),
                Text('Default: ${CurrencyFormatter.formatPaisa(item.defaultResellerPrice)}',
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          if (currentPrice != null)
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                await ref.read(wholesalerRepositoryProvider).removeCustomPrice(id, item.id);
                ref.invalidate(wholesalerCustomPricesProvider(id));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Reset to Default'),
            ),
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              final newPriceDouble = double.tryParse(controller.text);
              if (newPriceDouble != null && newPriceDouble > 0) {
                await ref.read(wholesalerRepositoryProvider).setCustomPrice(id, item.id, newPriceDouble);
                ref.invalidate(wholesalerCustomPricesProvider(id));
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Qeemat'),
          ),
        ],
      ),
    );
  }
}
