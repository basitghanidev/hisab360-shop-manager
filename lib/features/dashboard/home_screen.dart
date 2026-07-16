import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/features/dashboard/providers/dashboard_provider.dart';
import 'package:sentery_app/features/reports/providers/report_provider.dart';
import 'package:sentery_app/features/settings/providers/settings_provider.dart';
import 'package:sentery_app/core/database/database_provider.dart';
import 'package:sentery_app/core/widgets/animated_sync_icon.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final lowStockAsync = ref.watch(lowStockItemsProvider);
    final settingsAsync = ref.watch(settingsStreamProvider);

    int crossAxisCount;
    final width = MediaQuery.of(context).size.width;
    if (width > 1100) {
      crossAxisCount = 4; // 14 inch / Large monitor
    } else if (width > 800) {
      crossAxisCount = 3; // 12 inch / Tablet
    } else {
      crossAxisCount = 2; // Mobile
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/app_logo.png', height: 28),
            const SizedBox(width: 8),
            const Text('Hisab360', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          ],
        ),
        actions: [
          AnimatedSyncIcon(
            onPressed: () {
              ref.invalidate(dashboardProvider);
              ref.invalidate(lowStockItemsProvider);
              ref.invalidate(settingsStreamProvider);
            },
          ),
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/settings')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          ref.invalidate(lowStockItemsProvider);
          ref.invalidate(settingsStreamProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Welcome Header
            settingsAsync.when(
              data: (s) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome to Shop Manager,', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                    Text(s?.shopName ?? 'Shop Owner', style: AppTextStyles.largeTitle.copyWith(fontSize: 26, letterSpacing: -0.5)),
                  ],
                ),
              ),
              loading: () => const SizedBox(height: 60),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Today's Summary
            dashboardAsync.when(
              data: (data) => Column(
                children: [
                  LayoutBuilder(builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 600;
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _statCard('Today Sale', CurrencyFormatter.format(data.todaySales), AppColors.primary, Icons.trending_up)),
                            const SizedBox(width: 12),
                            Expanded(child: _statCard('Monthly Sale', CurrencyFormatter.format(data.monthSales), AppColors.accent, Icons.calendar_month)),
                            if (isWide) ...[
                              const SizedBox(width: 12),
                              Expanded(child: _statCard('Cash Taken (Today)', CurrencyFormatter.format(data.todayReceived), AppColors.success, Icons.payments)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (!isWide) ...[
                              Expanded(child: _statCard('Cash Taken (Today)', CurrencyFormatter.format(data.todayReceived), AppColors.success, Icons.payments)),
                              const SizedBox(width: 12),
                            ],
                            Expanded(child: _statCard('Monthly Expenses', CurrencyFormatter.format(data.monthExpenses), AppColors.danger, Icons.outbond)),
                            const SizedBox(width: 12),
                            Expanded(child: _statCard('Total Receivable', CurrencyFormatter.format(data.totalReceivable), AppColors.success, Icons.arrow_downward)),
                            const SizedBox(width: 12),
                            Expanded(child: _statCard('Total Payable', CurrencyFormatter.format(data.totalPayable), AppColors.danger, Icons.arrow_upward)),
                          ],
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => context.push('/reports/business-stats'),
                    icon: const Icon(Icons.insights),
                    label: const Text('View Detailed Business Stats'),
                  ),
                ],
              ),
              loading: () => const _ShimmerDashboard(),
              error: (e, _) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error: $e'))),
            ),

            const SizedBox(height: 20),

            // Low Stock Alert Banner
            lowStockAsync.when(
              data: (lowItems) {
                if (lowItems.isEmpty) return const SizedBox.shrink();
                return AppCard(
                  color: AppColors.danger.withOpacity(0.08),
                  onTap: () => context.push('/reports/low-stock'),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${lowItems.length} Item Kam Ho Rahe Hain!',
                                style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(lowItems.take(2).map((item) => (item as dynamic).name?.toString() ?? "").join(', ') + (lowItems.length > 2 ? ' ...' : ''),
                                style: AppTextStyles.caption.copyWith(color: AppColors.danger.withOpacity(0.8))),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.danger),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 12),

            // Draft Recovery Card
            FutureBuilder<Map<String, dynamic>?>(
              future: ref.read(draftServiceProvider).getSaleDraft(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();
                return AppCard(
                  color: AppColors.info,
                  onTap: () => context.push('/invoice/sale'),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note, color: Colors.white),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Unsaved Sale Bill found! Tap to restore.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                      Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white.withOpacity(0.8)),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
            const Text('JALDI KAAM (Quick Actions)', style: AppTextStyles.caption),
            const SizedBox(height: 12),

            // Quick Actions Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _actionCard(context, Icons.add_shopping_cart, 'New Bill', 'Nayi Bill', '/invoice/sale', AppColors.primary),
                _actionCard(context, Icons.shopping_bag_outlined, 'Purchase', 'Maal Khareedna', '/invoice/purchase', AppColors.accent),
                _actionCard(context, Icons.outbond_outlined, 'Expenses', 'Kharchay', '/expenses', AppColors.danger),
                _actionCard(context, Icons.assignment_return_outlined, 'Returns', 'Maal Wapsi', '/returns/create', AppColors.warning),
                _actionCard(context, Icons.receipt_long_outlined, 'All Bills', 'Sab Bill', '/invoice/list', Colors.indigo),
                _actionCard(context, Icons.bar_chart, 'Reports', 'Sab Reportien', '/reports', Colors.teal),
                _actionCard(context, Icons.people_outline, 'People', 'Logon Ka Hisab', '/people', Colors.blueGrey),
                _actionCard(context, Icons.drafts_outlined, 'Drafts', 'Adhoori Bills', '/drafts', Colors.deepOrange),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 18)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _actionCard(BuildContext context, IconData icon, String eng, String urdu, String route, Color color) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(eng, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            Text(urdu, style: TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// Loading shimmer placeholder
class _ShimmerDashboard extends StatelessWidget {
  const _ShimmerDashboard();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          Expanded(child: _shimmerBox(80)),
          const SizedBox(width: 12),
          Expanded(child: _shimmerBox(80)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _shimmerBox(80)),
          const SizedBox(width: 12),
          Expanded(child: _shimmerBox(80)),
        ]),
      ],
    );
  }
  Widget _shimmerBox(double h) {
    return Container(
      height: h,
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(14)),
    );
  }
}
