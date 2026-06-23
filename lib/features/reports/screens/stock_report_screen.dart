import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/core/utils/item_utils.dart';
import 'package:sentery_app/core/utils/money_utils.dart';
import 'package:sentery_app/features/items/providers/item_provider.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';

class StockReportScreen extends ConsumerWidget {
  const StockReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(itemsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(
          english: 'Stock Report',
          urdu: 'Maal Ka Hisaab',
          englishStyle: AppTextStyles.navTitle,
        ),
      ),
      body: itemsAsync.when(
        data: (items) {
          final mTotalCostValue = items.fold(Money.zero, (sum, item) => sum + Money.fromPaisa(getEffectiveCost(item)).multiplyByDouble(item.currentStock));
          final mTotalRetailValue = items.fold(Money.zero, (sum, item) => sum + Money.fromPaisa(item.retailPrice).multiplyByDouble(item.currentStock));

          return Column(
            children: [
              _buildValueHeader(mTotalCostValue.toDouble(), mTotalRetailValue.toDouble()),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final costPaisa = getEffectiveCost(item);
                    final mLineCost = Money.fromPaisa(costPaisa).multiplyByDouble(item.currentStock);
                    return AppCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                                Text('Stock: ${item.currentStock}', style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(CurrencyFormatter.formatPaisa(mLineCost.paisa), style: const TextStyle(fontSize: 14)),
                              const Text('Cost Value', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildValueHeader(double cost, double retail) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.primary.withOpacity(0.05),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Text('Total Cost Value', style: AppTextStyles.caption),
                FittedBox(child: Text(CurrencyFormatter.format(cost), style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary))),
              ],
            ),
          ),
          const SizedBox(height: 30, child: VerticalDivider()),
          Expanded(
            child: Column(
              children: [
                const Text('Total Retail Value', style: AppTextStyles.caption),
                FittedBox(child: Text(CurrencyFormatter.format(retail), style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, color: AppColors.success))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
