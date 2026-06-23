import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/constants/app_strings.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';

class ReportsHomeScreen extends StatelessWidget {
  const ReportsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(
          english: 'Reports & Analytics',
          urdu: AppStrings.reportsRoman,
          englishStyle: AppTextStyles.navTitle,
        ),
        actions: [
          IconButton(icon: const Icon(Icons.sync), onPressed: () {}), // Logic later if needed
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Add any specific report refreshes here if needed
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          _buildReportTile(context, Icons.receipt_long, 'Recent Invoices', AppStrings.invoicesRoman, () => context.push('/invoice/list')),
          _buildReportTile(context, Icons.calendar_month, 'Monthly Report', 'Mahana Report', () => context.push('/reports/monthly')),
          _buildReportTile(context, Icons.history, 'Yearly Report', 'Salana Report', () => context.push('/reports/yearly')),
          _buildReportTile(context, Icons.inventory, 'Stock Report', AppStrings.itemsRoman, () => context.push('/reports/stock')),
          _buildReportTile(context, Icons.warning_amber, 'Low Stock Report', AppStrings.lowStockRoman, () => context.push('/reports/low-stock')),
          _buildReportTile(context, Icons.account_balance_wallet, 'Khata Report', AppStrings.khataRoman, () => context.push('/reports/outstanding')),
        ],
      ),
    ),
   );
  }

  Widget _buildReportTile(BuildContext context, IconData icon, String eng, String roman, VoidCallback onTap) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: BilingualLabel(english: eng, urdu: roman, englishStyle: AppTextStyles.cardTitle),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}
