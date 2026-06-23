import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/features/items/providers/item_provider.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';
import 'package:sentery_app/core/database/app_database.dart';

class ItemDetailScreen extends ConsumerWidget {
  final int id;
  const ItemDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemStream = ref.watch(itemsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/items/$id/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: AppColors.danger),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: itemStream.when(
        data: (items) {
          final item = items.firstWhere((i) => i.id == id, orElse: () => throw Exception('Item not found'));
          final isLowStock = item.currentStock <= item.lowStockLimit;

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeaderCard(item, isLowStock),
                _buildPricingCard(item),
                _buildStockInfoCard(item, isLowStock),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: BilingualLabel(
                      english: 'Stock Movements',
                      urdu: 'Maal Ki Aamad o Raft',
                      englishStyle: AppTextStyles.cardTitle,
                    ),
                  ),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final movementsAsync = ref.watch(itemStockMovementsProvider(id));
                    return movementsAsync.when(
                      data: (movements) {
                        if (movements.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text('No stock movements yet'),
                            ),
                          );
                        }
                        return Column(
                          children: movements.map((m) {
                            final isIn = m.quantity > 0;
                            return ListTile(
                              leading: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: isIn ? AppColors.success : AppColors.danger),
                              title: Text(_movementLabel(m.movementType)),
                              subtitle: Text(m.movedAt.toString().split(' ')[0]),
                              trailing: Text('${isIn ? '+' : ''}${m.quantity}',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: isIn ? AppColors.success : AppColors.danger)),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, s) => Text('Error: $e'),
                    );
                  },
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  String _movementLabel(String type) {
    switch (type) {
      case 'purchase': return 'Stock In (Purchase)';
      case 'sale': return 'Stock Out (Sale)';
      case 'return_supplier': return 'Returned to Supplier';
      case 'return_wholesaler': return 'Returned by Wholesaler';
      case 'return_customer': return 'Returned by Customer';
      case 'opening_stock': return 'Opening Stock';
      default: return type;
    }
  }

  Widget _buildHeaderCard(Item item, bool isLowStock) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isLowStock ? AppColors.danger.withOpacity(0.1) : AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inventory_2,
                  color: isLowStock ? AppColors.danger : AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: AppTextStyles.largeTitle.copyWith(fontSize: 24)),
                    if (item.itemCode != null)
                      Text('Code: ${item.itemCode}', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard(Item item) {
    return AppCard(
      child: Column(
        children: [
          _buildPriceRow('Purchase Price', 'Khareed Qeemat', item.purchasePrice),
          const Divider(),
          _buildPriceRow('Wholesale Price', 'Thok Qeemat', item.defaultResellerPrice),
          const Divider(),
          _buildPriceRow('Retail Price', 'Parchoon Qeemat', item.retailPrice),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String eng, String urdu, int pricePaisa) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          BilingualLabel(english: eng, urdu: urdu, englishStyle: AppTextStyles.body),
          Text(CurrencyFormatter.formatPaisa(pricePaisa), style: AppTextStyles.cardTitle.copyWith(color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildStockInfoCard(Item item, bool isLowStock) {
    return AppCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BilingualLabel(
                english: 'Current Stock',
                urdu: 'Mojooda Maal',
                englishStyle: AppTextStyles.body,
              ),
              const SizedBox(height: 4),
              Text(
                'Low Stock Limit: ${item.lowStockLimit}',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          Text(
            '${item.currentStock}',
            style: AppTextStyles.currencyLarge.copyWith(
              color: isLowStock ? AppColors.danger : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              await ref.read(itemRepositoryProvider).deleteItem(id);
              if (context.mounted) {
                Navigator.pop(context);
                context.pop();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
