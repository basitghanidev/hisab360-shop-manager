import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/features/reports/providers/report_provider.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';

class LowStockScreen extends ConsumerWidget {
  const LowStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowStockAsync = ref.watch(lowStockItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(
          english: 'Low Stock Alert',
          urdu: 'Kam Maal Ki List',
          englishStyle: AppTextStyles.navTitle,
        ),
      ),
      body: lowStockAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('All items are in stock!'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return AppCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                        Text('Minimum Level: ${item.lowStockLimit}', style: AppTextStyles.caption),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${item.currentStock}', style: AppTextStyles.body.copyWith(color: AppColors.danger, fontWeight: FontWeight.bold)),
                        const Text('Available', style: AppTextStyles.caption),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
