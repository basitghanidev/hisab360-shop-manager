import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_strings.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';
import 'package:sentery_app/features/invoices/providers/invoice_provider.dart';
import 'package:intl/intl.dart';

class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  String _query = '';
  String _filterType = 'all'; 

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesStreamProvider);
    final dateFormat = DateFormat('dd MMM, hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(
          english: 'All Bills',
          urdu: AppStrings.invoicesRoman,
          englishStyle: AppTextStyles.navTitle,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: CupertinoSearchTextField(
              placeholder: 'Bill # ya Grahak ka naam...',
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),

          // Filter chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _filterChip('All', 'all'),
                _filterChip('Sales', 'sale'),
                _filterChip('Purchases', 'purchase'),
                _filterChip('Returns', 'return'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(invoicesStreamProvider);
                await Future.delayed(const Duration(milliseconds: 300));
              },
              child: invoicesAsync.when(
                data: (list) {
                  // Apply filters
                  var filtered = list.where((inv) {
                    final matchesQuery = _query.isEmpty ||
                        inv.invoiceNumber.toLowerCase().contains(_query) ||
                        (inv.tempCustomerName?.toLowerCase().contains(_query) ?? false) ||
                        (inv.partyNameSnapshot?.toLowerCase().contains(_query) ?? false);
                    final matchesType = _filterType == 'all' ||
                        inv.invoiceType.contains(_filterType);
                    return matchesQuery && matchesType;
                  }).toList();

                  if (filtered.isEmpty) {
                    return ListView(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              const Text('Koi bill nahi mila', style: AppTextStyles.body),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final invoice = filtered[index];
                      return _InvoiceTile(invoice: invoice, dateFormat: dateFormat);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Error: $e')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String type) {
    final isSelected = _filterType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
        selected: isSelected,
        selectedColor: AppColors.primary,
        onSelected: (_) => setState(() => _filterType = type),
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  final dynamic invoice;
  final DateFormat dateFormat;

  const _InvoiceTile({required this.invoice, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    final isSale = invoice.invoiceType.startsWith('sale');
    final isPurchase = invoice.invoiceType == 'purchase';
    final isReturn = invoice.invoiceType.contains('return');
    
    Color typeColor = AppColors.primary;
    IconData typeIcon = Icons.arrow_upward;
    String typeLabel = 'SALE';

    if (isPurchase) {
      typeColor = AppColors.accent;
      typeIcon = Icons.arrow_downward;
      typeLabel = 'PURCHASE';
    } else if (isReturn) {
      typeColor = Colors.orange;
      typeIcon = Icons.settings_backup_restore;
      typeLabel = 'RETURN';
    } else if (invoice.invoiceType.contains('payment')) {
      typeColor = AppColors.success;
      typeIcon = Icons.payments;
      typeLabel = 'PAYMENT';
    }

    final String partyDisplay = invoice.partyNameSnapshot ?? invoice.tempCustomerName ?? 'Walk-in';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => context.push('/invoice/${invoice.id}'),
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: typeColor.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(typeIcon, color: typeColor, size: 20),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(invoice.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            _statusBadge(invoice.status),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(partyDisplay, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
            Text(dateFormat.format(invoice.invoiceDate), style: const TextStyle(fontSize: 11)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(CurrencyFormatter.formatPaisa(invoice.totalAmount), 
                style: TextStyle(fontWeight: FontWeight.bold, color: typeColor, fontSize: 16)),
            if (invoice.amountRemaining > 0)
              Text('Rem: ${CurrencyFormatter.formatPaisa(invoice.amountRemaining)}', 
                  style: const TextStyle(color: AppColors.danger, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color = Colors.grey;
    if (status == 'paid') color = AppColors.success;
    if (status == 'partial') color = AppColors.warning;
    if (status == 'pending') color = AppColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}
