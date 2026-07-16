import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/features/wholesalers/providers/wholesaler_provider.dart';
import 'package:sentery_app/features/invoices/providers/invoice_provider.dart';
import 'package:sentery_app/core/widgets/ledger_entry_tile.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/features/people/widgets/party_balance_summary_card.dart';
import 'package:intl/intl.dart';

class WholesalerDetailScreen extends ConsumerWidget {
  final int id;
  const WholesalerDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wholesalerAsync = ref.watch(wholesalerByIdProvider(id));
    final ledgerAsync = ref.watch(wholesalerLedgerProvider(id));
    final invoicesAsync = ref.watch(wholesalerInvoicesProvider(id));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Wholesaler Profile'),
          actions: [
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => context.push('/wholesalers/$id/edit')),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Ledger (Khata)'),
              Tab(text: 'Bills (Invoices)'),
            ],
          ),
        ),
        body: wholesalerAsync.when(
          data: (wholesaler) {
            if (wholesaler == null) return const Center(child: Text('Wholesaler not found'));
            return Column(
              children: [
                _buildProfileCard(wholesaler),
                PartyBalanceSummaryCard(partyType: 'wholesaler', currentBalance: wholesaler.currentBalance),
                _buildActionStrip(context),
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
        bottomNavigationBar: _buildBottomActionButtons(context),
      ),
    );
  }

  Widget _buildBottomActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => context.push('/people/add-ledger-entry?partyType=wholesaler&partyId=$id&isGave=true'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('YOU GAVE Rs', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () => context.push('/people/add-ledger-entry?partyType=wholesaler&partyId=$id&isGave=false'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('YOU GOT Rs', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(Wholesaler wholesaler) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(wholesaler.name, style: AppTextStyles.largeTitle.copyWith(fontSize: 24)),
              if (wholesaler.area != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(wholesaler.area!, style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          if (wholesaler.phone != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(wholesaler.phone!, style: AppTextStyles.body),
              ],
            ),
          ],
          if (wholesaler.address != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text(wholesaler.address!, style: AppTextStyles.caption)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionStrip(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.push('/wholesalers/$id/prices'),
              icon: const Icon(Icons.sell_outlined, size: 18),
              label: const Text('Custom Prices'),
            ),
          ),
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
