import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/core/utils/money_utils.dart';
import 'package:sentery_app/features/invoices/providers/invoice_provider.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';
import 'package:sentery_app/core/services/invoice_pdf_service.dart';
import 'package:sentery_app/core/database/database_provider.dart';
import 'package:sentery_app/features/wholesalers/providers/wholesaler_provider.dart';
import 'package:sentery_app/features/suppliers/providers/supplier_provider.dart';
import 'package:sentery_app/features/customers/providers/customer_provider.dart';
import 'package:intl/intl.dart';

class InvoiceDetailScreen extends ConsumerWidget {
  final int id;
  const InvoiceDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceAsync = ref.watch(invoiceByIdProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(
          english: 'Invoice Details',
          urdu: 'Bill Ki Tafseel',
          englishStyle: AppTextStyles.navTitle,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share / Print Bill',
            onPressed: () async {
              await InvoicePdfService(ref.read(databaseProvider)).previewInvoice(id);
            },
          ),
        ],
      ),
      body: invoiceAsync.when(
        data: (invoice) {
          if (invoice == null) return const Center(child: Text('Invoice not found'));
          final itemsAsync = ref.watch(invoiceItemsProvider(id));

          String partyName = invoice.tempCustomerName ?? 'Walk-in Customer';
          String partyLabel = 'Customer';
          String? partyRoute;

          if (invoice.wholesalerId != null) {
            final ws = ref.watch(wholesalerByIdProvider(invoice.wholesalerId!));
            partyName = ws.when(data: (w) => w?.name ?? 'Wholesaler', loading: () => '...', error: (_, __) => 'Unknown');
            partyLabel = 'Wholesaler (Thok)';
            partyRoute = '/wholesalers/${invoice.wholesalerId}';
          } else if (invoice.supplierId != null) {
            final sp = ref.watch(supplierByIdProvider(invoice.supplierId!));
            partyName = sp.when(data: (s) => s?.name ?? 'Supplier', loading: () => '...', error: (_, __) => 'Unknown');
            partyLabel = 'Supplier (Saudagar)';
            partyRoute = '/suppliers/${invoice.supplierId}';
          } else if (invoice.customerId != null) {
            final cs = ref.watch(customerByIdProvider(invoice.customerId!));
            partyName = cs.when(data: (c) => c?.name ?? 'Customer', loading: () => '...', error: (_, __) => 'Unknown');
            partyLabel = 'Customer (Grahak)';
            partyRoute = '/customers/${invoice.customerId}';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  color: AppColors.primary.withOpacity(0.05),
                  onTap: partyRoute != null ? () => context.push(partyRoute!) : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(invoice.invoiceNumber, style: AppTextStyles.cardTitle.copyWith(color: AppColors.primary)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(invoice.status).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(invoice.status.toUpperCase(),
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _getStatusColor(invoice.status))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Date: ${DateFormat('dd MMM yyyy').format(invoice.invoiceDate)}', style: AppTextStyles.caption),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text('$partyLabel: $partyName', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                          ),
                          if (partyRoute != null) ...[
                            const Icon(Icons.chevron_right, color: AppColors.primary, size: 18),
                            const SizedBox(width: 2),
                            Text('View Profile', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (invoice.invoiceType.contains('_payment_receipt'))
                  _buildReceiptContent(invoice)
                else ...[
                  const Text('ITEMS (MAAL)', style: AppTextStyles.caption),
                  const Divider(),
                  itemsAsync.when(
                    data: (items) => Column(children: items.map((item) => _buildItemRow(item)).toList()),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, s) => Text('Error: $e'),
                  ),
                  const Divider(),
                ],

                AppCard(
                  child: Column(
                    children: [
                      _buildRow('Previous Balance (Pehla Baaqi)', invoice.previousBalance),
                      _buildRow('Bill Amount (Naya Bill)', invoice.totalAmount),
                      const Divider(),
                      _buildRow('Paid Today (Aaj Ada)', invoice.amountPaid, color: AppColors.success),
                      _buildRow('Bill Remaining', invoice.amountRemaining,
                          color: invoice.amountRemaining > 0 ? AppColors.danger : AppColors.success),
                      const Divider(),
                      _buildRow('Total Khata After Bill', invoice.totalBalanceAfter,
                          color: invoice.totalBalanceAfter > 0 ? AppColors.danger : AppColors.success, isBold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (invoice.notes != null) ...[
                  const Text('NOTES (Zaroori Maloomat)', style: AppTextStyles.caption),
                  AppCard(
                    child: Text(invoice.notes!, style: const TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(height: 16),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await InvoicePdfService(ref.read(databaseProvider)).previewInvoice(id);
                    },
                    icon: const Icon(Icons.print),
                    label: const Text('Print / Share Bill'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildReceiptContent(dynamic invoice) {
    return AppCard(
      color: AppColors.success.withOpacity(0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BilingualLabel(english: 'Payment Receipt', urdu: 'Adaigi ki raseed', englishStyle: AppTextStyles.cardTitle),
          const SizedBox(height: 12),
          _buildRowRaw('Payment Method', (invoice.paymentMethod ?? 'Cash').toUpperCase()),
          if (invoice.onlineMethod != null)
            _buildRowRaw('Via', invoice.onlineMethod!.toUpperCase()),
          if (invoice.transactionId != null)
            _buildRowRaw('Transaction ID', invoice.transactionId!),
          if (invoice.accountNumber != null)
            _buildRowRaw('Account #', invoice.accountNumber!),
          const Divider(height: 24),
          _buildRow('Previous Baaqi', invoice.receiptPreviousRemaining ?? 0),
          _buildRow('Paid Today', invoice.totalAmount, color: AppColors.success, isBold: true),
          const Divider(),
          _buildRow('New Baaqi', invoice.receiptFinalRemaining ?? 0, isBold: true),
        ],
      ),
    );
  }

  Widget _buildRowRaw(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildItemRow(dynamic item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itemNameSnapshot, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                Text('${item.quantity} ${item.unitTypeSnapshot} × ${CurrencyFormatter.formatPaisa(item.salePrice)}',
                    style: AppTextStyles.caption),
                if ((item.itemNote ?? '').isNotEmpty)
                  Text('Note: ${item.itemNote}', style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(CurrencyFormatter.formatPaisa(item.lineTotal), style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
              if ((item.discountAmount ?? 0) > 0)
                Text('-${CurrencyFormatter.formatPaisa(item.discountAmount)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.success)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, int paisa, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
          Text(CurrencyFormatter.formatPaisa(paisa),
              style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color, fontSize: isBold ? 15 : 14)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid': return AppColors.success;
      case 'pending': return AppColors.danger;
      case 'partial': return Colors.orange;
      default: return Colors.grey;
    }
  }
}
