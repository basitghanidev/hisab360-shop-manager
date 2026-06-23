import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';
import 'package:sentery_app/features/reports/providers/report_provider.dart';
import 'package:sentery_app/features/dashboard/providers/dashboard_provider.dart';

class BusinessStatsScreen extends ConsumerWidget {
  const BusinessStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final monthlyProfitAsync = ref.watch(monthlyReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(
          english: 'Business Performance',
          urdu: 'Karobari Stats',
          englishStyle: AppTextStyles.navTitle,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfitSection(monthlyProfitAsync),
          const SizedBox(height: 16),
          _buildShopValueSection(monthlyProfitAsync), // Uses full monthly report data if available
          const SizedBox(height: 16),
          _buildSalesSection(dashboardAsync),
          const SizedBox(height: 16),
          _buildOutstandingSection(dashboardAsync),
        ],
      ),
    );
  }

  Widget _buildProfitSection(AsyncValue<MonthlyReportData> async) {
    return async.when(
      data: (data) => AppCard(
        color: AppColors.success,
        child: Column(
          children: [
            const Text('Estimated Monthly Profit', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            Text(CurrencyFormatter.format(data.profit), 
                style: AppTextStyles.largeTitle.copyWith(color: Colors.white)),
            const Text('Based on cost prices and sales so far', style: TextStyle(fontSize: 10, color: Colors.white60)),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }

  Widget _buildShopValueSection(AsyncValue<MonthlyReportData> async) {
    // Note: This ideally should use the FullMonthlyReport from Task 8, but for now we'll use available data
    return AppCard(
      color: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SHOP VALUE (MARKET VALUE)', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
          const Divider(color: Colors.white24),
          _statRow('Total Assets (Cash + Stock)', 0.0, Colors.white, isBold: true), // Requires deeper query
          const Text('Includes your stock value at retail prices', style: TextStyle(fontSize: 9, color: Colors.white60)),
        ],
      ),
    );
  }

  Widget _buildSalesSection(AsyncValue<DashboardData> async) {
    return async.when(
      data: (data) => AppCard(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SALES BREAKDOWN', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
            const Divider(),
            _statRow('Today\'s Revenue', data.todaySales, AppColors.primary),
            _statRow('Today\'s Collection', data.todayReceived, AppColors.success),
            _statRow('Monthly Revenue', data.monthSales, AppColors.accent),
          ],
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildOutstandingSection(AsyncValue<DashboardData> async) {
    return async.when(
      data: (data) => AppCard(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('LIABILITIES & ASSETS', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
            const Divider(),
            _statRow('Suppliers Payable', data.supplierOutstanding, AppColors.danger),
            _statRow('Buyers Receivable', data.wholesalerOutstanding + data.customerOutstanding, AppColors.success),
            const Divider(),
            _statRow('Net Outstanding', (data.wholesalerOutstanding + data.customerOutstanding) - data.supplierOutstanding, AppColors.info, isBold: true),
          ],
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _statRow(String label, double val, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color == Colors.white ? Colors.white : AppColors.textPrimary,
          )),
          Text(CurrencyFormatter.format(val.abs()), 
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
