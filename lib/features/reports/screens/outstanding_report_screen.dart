import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/core/utils/money_utils.dart';
import 'package:sentery_app/features/suppliers/providers/supplier_provider.dart';
import 'package:sentery_app/features/wholesalers/providers/wholesaler_provider.dart';
import 'package:sentery_app/features/customers/providers/customer_provider.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';

class OutstandingReportScreen extends ConsumerWidget {
  const OutstandingReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const BilingualLabel(
            english: 'Outstanding Balances',
            urdu: 'Baaki Rupay Ki List',
            englishStyle: AppTextStyles.navTitle,
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Suppliers'),
              Tab(text: 'Wholesalers'),
              Tab(text: 'Customers'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SupplierOutstandingList(),
            _WholesalerOutstandingList(),
            _CustomerOutstandingList(),
          ],
        ),
      ),
    );
  }
}

class _SupplierOutstandingList extends ConsumerWidget {
  const _SupplierOutstandingList();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(suppliersStreamProvider);
    return suppliers.when(
      data: (list) {
        final withBalance = list.where((s) => s.currentBalance != 0).toList();
        final totalPaisa = withBalance.fold(0, (sum, s) => sum + s.currentBalance);
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppColors.danger.withOpacity(0.06),
              child: Column(
                children: [
                  const Text('Total We Owe Suppliers', style: AppTextStyles.caption),
                  Text(CurrencyFormatter.formatPaisa(totalPaisa.abs()), style: AppTextStyles.largeTitle.copyWith(color: AppColors.danger, fontSize: 26)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: withBalance.length,
                itemBuilder: (c, i) => _PartyRow(
                  withBalance[i].name, withBalance[i].currentBalance, AppColors.danger,
                  onTap: () => context.push('/suppliers/${withBalance[i].id}'),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Text('Error: $e'),
    );
  }
}

class _WholesalerOutstandingList extends ConsumerWidget {
  const _WholesalerOutstandingList();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wholesalers = ref.watch(wholesalersStreamProvider);
    return wholesalers.when(
      data: (list) {
        final withBalance = list.where((w) => w.currentBalance != 0).toList();
        final totalPaisa = withBalance.fold(0, (sum, w) => sum + w.currentBalance);
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppColors.success.withOpacity(0.06),
              child: Column(
                children: [
                  const Text('Total Wholesalers Owe Us', style: AppTextStyles.caption),
                  Text(CurrencyFormatter.formatPaisa(totalPaisa.abs()), style: AppTextStyles.largeTitle.copyWith(color: AppColors.success, fontSize: 26)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: withBalance.length,
                itemBuilder: (c, i) => _PartyRow(
                  withBalance[i].name, withBalance[i].currentBalance, AppColors.success,
                  onTap: () => context.push('/wholesalers/${withBalance[i].id}'),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Text('Error: $e'),
    );
  }
}

class _CustomerOutstandingList extends ConsumerWidget {
  const _CustomerOutstandingList();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersStreamProvider);
    return customers.when(
      data: (list) {
        final withBalance = list.where((c) => c.currentBalance != 0).toList();
        final totalPaisa = withBalance.fold(0, (sum, c) => sum + c.currentBalance);
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppColors.success.withOpacity(0.06),
              child: Column(
                children: [
                  const Text('Total Customers Owe Us', style: AppTextStyles.caption),
                  Text(CurrencyFormatter.formatPaisa(totalPaisa.abs()), style: AppTextStyles.largeTitle.copyWith(color: AppColors.success, fontSize: 26)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: withBalance.length,
                itemBuilder: (c, i) => _PartyRow(
                  withBalance[i].name, withBalance[i].currentBalance, AppColors.success,
                  onTap: () => context.push('/customers/${withBalance[i].id}'),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Text('Error: $e'),
    );
  }
}

class _PartyRow extends StatelessWidget {
  final String name;
  final int balance; // Paisa
  final Color color;
  final VoidCallback? onTap;
  const _PartyRow(this.name, this.balance, this.color, {this.onTap});

  @override
  Widget build(BuildContext context) {
    if (balance == 0) return const SizedBox.shrink();
    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name, 
              style: AppTextStyles.body,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              Text(CurrencyFormatter.formatPaisa(balance.abs()), style: AppTextStyles.body.copyWith(color: color, fontWeight: FontWeight.bold)),
              if (onTap != null) const Icon(Icons.chevron_right, color: AppColors.textLight, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}
