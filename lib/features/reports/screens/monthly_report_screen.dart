import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/database/database_provider.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/core/widgets/animated_sync_icon.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';
import 'package:sentery_app/core/database/daos/report_dao.dart';
import 'package:sentery_app/core/services/report_pdf_service.dart';

// Month/Year state provider
final selectedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

final fullMonthlyReportProvider = FutureProvider.family<FullMonthlyReport, DateTime>((ref, month) async {
  final db = ref.watch(databaseProvider);
  return db.reportDao.getFullMonthlyReport(month.year, month.month);
});

class MonthlyReportScreen extends ConsumerWidget {
  const MonthlyReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final reportAsync = ref.watch(fullMonthlyReportProvider(selectedMonth));

    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(english: 'Monthly Report', urdu: 'Mahana Hisaab', englishStyle: AppTextStyles.navTitle),
        actions: [
          AnimatedSyncIcon(onPressed: () => ref.invalidate(fullMonthlyReportProvider(selectedMonth))),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export PDF',
            onPressed: () async {
              final report = await ref.read(fullMonthlyReportProvider(selectedMonth).future);
              await ReportPdfService().previewMonthlyReport(report, selectedMonth);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Month Navigator
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => ref.read(selectedMonthProvider.notifier).state =
                      DateTime(selectedMonth.year, selectedMonth.month - 1),
                ),
                GestureDetector(
                  onTap: () => _showMonthPicker(context, ref, selectedMonth),
                  child: Text(
                    '${months[selectedMonth.month - 1]} ${selectedMonth.year}',
                    style: AppTextStyles.cardTitle.copyWith(color: AppColors.primary),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: selectedMonth.month == DateTime.now().month && selectedMonth.year == DateTime.now().year
                      ? null
                      : () => ref.read(selectedMonthProvider.notifier).state =
                          DateTime(selectedMonth.year, selectedMonth.month + 1),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: reportAsync.when(
              data: (report) => ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 12),
                  // Hero profit card
                  _ProfitHeroCard(report: report),
                  const SizedBox(height: 16),
                  
                  // Two-column quick summary row
                  Row(
                    children: [
                      Expanded(child: _QuickStatCard('Total Sales', report.totalSales, AppColors.primary, Icons.trending_up)),
                      const SizedBox(width: 12),
                      Expanded(child: _QuickStatCard('Total Purchases', report.totalPurchases, AppColors.accent, Icons.shopping_bag_outlined)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _QuickStatCard('Cash Received', report.cashReceived, AppColors.success, Icons.payments_outlined)),
                      const SizedBox(width: 12),
                      Expanded(child: _QuickStatCard('Cash Paid', report.cashPaid, AppColors.danger, Icons.arrow_upward)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Collapsible detailed sections
                  _CollapsibleSection(
                    title: 'Sales Detail',
                    children: [
                      _DataRow('Wholesale Sales', report.wholesaleSales),
                      _DataRow('Retail Sales', report.retailSales),
                      _DataRow('Online Received', report.onlineReceived),
                      _DataRow('Credit Given (Udhaar)', report.creditGiven, color: AppColors.danger),
                    ],
                  ),
                  _CollapsibleSection(
                    title: 'Purchase Detail',
                    children: [
                      _DataRow('Cash Paid', report.cashPaid),
                      _DataRow('Online Paid', report.onlinePaid),
                      _DataRow('Credit Taken', report.creditTaken, color: AppColors.warning),
                    ],
                  ),
                  _CollapsibleSection(
                    title: 'Outstanding Balances',
                    children: [
                      _DataRow('Suppliers (We Owe)', report.supplierOutstanding, color: AppColors.danger),
                      _DataRow('Wholesalers (Owe Us)', report.wholesalerOutstanding, color: AppColors.success),
                      _DataRow('Customers (Owe Us)', report.customerOutstanding, color: AppColors.success),
                      const Divider(),
                      _DataRow('Net Outstanding', report.netOutstanding,
                          isBold: true,
                          color: report.netOutstanding >= 0 ? AppColors.success : AppColors.danger),
                    ],
                  ),
                  _CollapsibleSection(
                    title: 'Shop Value',
                    children: [
                      _DataRow('Stock at Cost', report.stockValueAtCost),
                      _DataRow('Stock at Retail', report.stockValueAtRetail),
                      _DataRow('Total Assets', report.totalAssets),
                      _DataRow('Total Liabilities', report.totalLiabilities, color: AppColors.danger),
                      const Divider(),
                      _DataRow('Net Shop Value', report.netShopValue, isBold: true,
                          color: report.netShopValue >= 0 ? AppColors.success : AppColors.danger),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error loading report: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  Widget _row(String label, double amount, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label, 
              style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 15 : 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(CurrencyFormatter.format(amount.abs()),
              style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color, fontSize: isBold ? 15 : 14)),
        ],
      ),
    );
  }

  void _showMonthPicker(BuildContext context, WidgetRef ref, DateTime current) {
    // ...
  }
}

class _ProfitHeroCard extends StatelessWidget {
  final FullMonthlyReport report;
  const _ProfitHeroCard({required this.report});
  
  @override
  Widget build(BuildContext context) {
    final isProfit = report.grossProfit >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (isProfit ? AppColors.success : AppColors.danger).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (isProfit ? AppColors.success : AppColors.danger).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(isProfit ? 'Profit (Faida)' : 'Loss (Nuqsan)',
              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(CurrencyFormatter.format(report.grossProfit.abs()),
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold,
                  color: isProfit ? AppColors.success : AppColors.danger)),
        ],
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;
  const _QuickStatCard(this.label, this.value, this.color, this.icon);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(CurrencyFormatter.format(value),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _CollapsibleSection extends StatefulWidget {
  final String title;
  final List<Widget> children;
  const _CollapsibleSection({required this.title, required this.children});
  
  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = false;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
      child: Column(
        children: [
          ListTile(
            title: Text(widget.title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
            trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textSecondary),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: widget.children),
            ),
          ],
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isBold;
  final Color? color;
  const _DataRow(this.label, this.value, {this.isBold = false, this.color});
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isBold ? 14 : 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(CurrencyFormatter.format(value.abs()),
              style: TextStyle(fontSize: isBold ? 15 : 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
