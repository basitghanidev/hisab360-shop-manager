import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/constants/app_strings.dart';
import 'package:sentery_app/router/app_router.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/features/dashboard/providers/dashboard_provider.dart';
import 'package:sentery_app/features/items/providers/item_provider.dart';
import 'package:sentery_app/core/widgets/animated_sync_icon.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';

class HisabKitabScreen extends ConsumerWidget {
  const HisabKitabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(
          english: 'Khata Summary',
          urdu: AppStrings.khataRoman,
          englishStyle: AppTextStyles.navTitle,
        ),
        actions: [
          AnimatedSyncIcon(onPressed: () => ref.invalidate(dashboardProvider)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardProvider.future),
        child: dashboardAsync.when(
          data: (data) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildNetBalanceCard(data),
                const SizedBox(height: 16),
                _buildOutstandingSection(data),
                const SizedBox(height: 16),
                _buildDailyCashSection(data),
                const SizedBox(height: 16),
                _buildStockValueCard(ref),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildNetBalanceCard(DashboardData data) {
    final isNegative = data.netKhataBalance < 0;
    final color = isNegative ? AppColors.danger : AppColors.success;
    
    return AppCard(
      color: color,
      child: Column(
        children: [
          const BilingualLabel(
            english: 'Net Khata Balance',
            urdu: 'Kul Hisab Kitaab',
            englishStyle: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            urduColor: Colors.white70,
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(data.netKhataBalance.abs()),
            style: AppTextStyles.largeTitle.copyWith(color: Colors.white, fontSize: 36),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isNegative ? 'Hum Ne Dena Hai (PAYABLE)' : 'Hume Milna Hai (RECEIVABLE)',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutstandingSection(DashboardData data) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BilingualLabel(
            english: 'OUTSTANDING (Baaki Rupay)',
            urdu: 'Logon Ke Rupay',
            englishStyle: AppTextStyles.cardTitle,
          ),
          const SizedBox(height: 12),
          _buildRow('Suppliers (We Owe)', AppStrings.suppliersRoman, data.supplierOutstanding, AppColors.danger),
          if (data.supplierCredit > 0)
            _buildCreditNote('We have ${CurrencyFormatter.format(data.supplierCredit)} of advance paid to suppliers (already settled, not owed).'),
          const Divider(),
          _buildRow('Wholesalers (Owe Us)', AppStrings.wholesalersRoman, data.wholesalerOutstanding, AppColors.success),
          if (data.wholesalerCredit > 0)
            _buildCreditNote('${CurrencyFormatter.format(data.wholesalerCredit)} is sitting as credit on wholesaler accounts (they overpaid).'),
          const Divider(),
          _buildRow('Customers (Owe Us)', AppStrings.customersRoman, data.customerOutstanding, AppColors.success),
          if (data.customerCredit > 0)
            _buildCreditNote('${CurrencyFormatter.format(data.customerCredit)} is sitting as credit on customer accounts (they overpaid).'),
        ],
      ),
    );
  }

  Widget _buildCreditNote(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.success.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: AppTextStyles.caption.copyWith(color: AppColors.success.withOpacity(0.9))),
      ),
    );
  }

  Widget _buildDailyCashSection(DashboardData data) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BilingualLabel(english: 'Today Cash', urdu: 'Aaj Ki Naqad', englishStyle: AppTextStyles.cardTitle),
          const SizedBox(height: 12),
          _buildRow('Received Today', 'Aaj Wasooli', data.todayReceived, AppColors.success),
          const Divider(),
          _buildRow('Paid Today', 'Aaj Adaigi', data.todayPaid, AppColors.danger),
        ],
      ),
    );
  }

  Widget _buildRow(String eng, String sub, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eng, 
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  sub, 
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(CurrencyFormatter.format(amount), style: AppTextStyles.body.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStockValueCard(WidgetRef ref) {
    final stockValueAsync = ref.watch(totalStockValueProvider);
    return AppCard(
      onTap: () => ref.read(routerProvider).push('/reports/stock'),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const BilingualLabel(english: 'Total Stock Value (Cost)', urdu: 'Kul Maal Ki Qeemat', englishStyle: AppTextStyles.body),
          stockValueAsync.when(
            data: (val) => Text(CurrencyFormatter.format(val), style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
            loading: () => const Center(child: CircularProgressIndicator.adaptive()),
            error: (e, s) => const Icon(Icons.error_outline, color: AppColors.danger),
          ),
        ],
      ),
    );
  }
}
