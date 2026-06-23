import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/core/utils/money_utils.dart';
import 'package:sentery_app/features/customers/providers/customer_provider.dart';
import 'package:sentery_app/features/invoices/providers/invoice_provider.dart';
import 'package:sentery_app/core/widgets/ledger_entry_tile.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';
import 'package:sentery_app/features/people/widgets/party_balance_summary_card.dart';
import 'package:intl/intl.dart';

class CustomerDetailScreen extends ConsumerWidget {
  final int id;
  const CustomerDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerByIdProvider(id));
    final ledgerAsync = ref.watch(customerLedgerProvider(id));
    final invoicesAsync = ref.watch(customerInvoicesProvider(id));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Customer Profile'),
          actions: [
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => context.push('/customers/$id/edit')),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Ledger (Khata)'),
              Tab(text: 'Bills (Invoices)'),
            ],
          ),
        ),
        body: customerAsync.when(
          data: (customer) {
            if (customer == null) return const Center(child: Text('Customer not found'));
            return Column(
              children: [
                _buildProfileCard(customer),
                PartyBalanceSummaryCard(partyType: 'customer', currentBalance: customer.currentBalance),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildLedgerTab(ledgerAsync),
                      _buildInvoicesTab(invoicesAsync, context),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  Widget _buildProfileCard(Customer customer) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(customer.name, style: AppTextStyles.largeTitle.copyWith(fontSize: 24)),
          if (customer.phone != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(customer.phone!, style: AppTextStyles.body),
              ],
            ),
          ],
          if (customer.address != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text(customer.address!, style: AppTextStyles.caption)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLedgerTab(AsyncValue<List<LedgerEntry>> ledgerAsync) {
    return ledgerAsync.when(
      data: (entries) {
        if (entries.isEmpty) return const Center(child: Text('No transactions yet.'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          itemBuilder: (context, index) => LedgerEntryTile(entry: entries[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildInvoicesTab(AsyncValue<List<Invoice>> invoicesAsync, BuildContext context) {
    return invoicesAsync.when(
      data: (list) {
        if (list.isEmpty) return const Center(child: Text('No bills found.'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final inv = list[index];
            final isPaid = inv.status == 'paid';
            return AppCard(
              onTap: () => context.push('/invoice/${inv.id}'),
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isPaid ? AppColors.success : AppColors.warning).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      inv.invoiceType.contains('payment') ? Icons.receipt_long : Icons.description_outlined, 
                      color: isPaid ? AppColors.success : AppColors.warning, size: 20
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inv.invoiceNumber, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                        Text(DateFormat('dd MMM yyyy').format(inv.invoiceDate), style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(CurrencyFormatter.formatPaisa(inv.totalAmount), style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                      if (!isPaid)
                        Text('Rem: ${CurrencyFormatter.formatPaisa(inv.amountRemaining)}', 
                          style: const TextStyle(fontSize: 10, color: AppColors.danger, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 18, color: AppColors.textLight),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }
}
