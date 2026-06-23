import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/database/daos/report_dao.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/features/reports/providers/report_provider.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';

final selectedYearProvider = StateProvider<int>((ref) => DateTime.now().year);

class YearlyReportScreen extends ConsumerWidget {
  const YearlyReportScreen({super.key});

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(selectedYearProvider);
    final breakdownAsync = ref.watch(yearlyBreakdownProvider(year));

    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(english: 'Yearly Report', urdu: 'Salana Hisaab', englishStyle: AppTextStyles.navTitle),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left),
                    onPressed: () => ref.read(selectedYearProvider.notifier).state = year - 1),
                Text('$year', style: AppTextStyles.cardTitle),
                IconButton(icon: const Icon(Icons.chevron_right),
                    onPressed: year >= DateTime.now().year ? null : () => ref.read(selectedYearProvider.notifier).state = year + 1),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: breakdownAsync.when(
              data: (months) {
                final totalSales = months.fold(0.0, (s, m) => s + m.sales);
                final totalPurchases = months.fold(0.0, (s, m) => s + m.purchases);
                final totalProfit = months.fold(0.0, (s, m) => s + m.profit);
                final bestMonth = months.isEmpty ? null : months.reduce((a, b) => a.sales > b.sales ? a : b);

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(child: _summaryCard('Total Sales', totalSales, AppColors.primary)),
                        const SizedBox(width: 12),
                        Expanded(child: _summaryCard('Total Profit', totalProfit, AppColors.success)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _summaryCard('Total Purchases', totalPurchases, AppColors.accent, fullWidth: true),
                    if (bestMonth != null) ...[
                      const SizedBox(height: 12),
                      AppCard(
                        color: AppColors.success.withOpacity(0.08),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: AppColors.success),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Best month: ${_months[bestMonth.month - 1]} — ${CurrencyFormatter.format(bestMonth.sales)} in sales',
                                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Text('MONTH BY MONTH', style: AppTextStyles.caption),
                    const SizedBox(height: 8),
                    ...months.map((m) => AppCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(width: 40, child: Text(_months[m.month - 1], style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold))),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sales: ${CurrencyFormatter.format(m.sales)}', style: AppTextStyles.caption),
                                Text('Purchases: ${CurrencyFormatter.format(m.purchases)}', style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                          Text(CurrencyFormatter.format(m.profit),
                              style: TextStyle(fontWeight: FontWeight.bold, color: m.profit >= 0 ? AppColors.success : AppColors.danger)),
                        ],
                      ),
                    )),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, double value, Color color, {bool fullWidth = false}) {
    return AppCard(
      child: Column(
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 6),
          Text(CurrencyFormatter.format(value), style: AppTextStyles.largeTitle.copyWith(color: color, fontSize: fullWidth ? 24 : 20)),
        ],
      ),
    );
  }
}
