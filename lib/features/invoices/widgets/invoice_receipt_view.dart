import 'package:flutter/material.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:intl/intl.dart';

class InvoiceReceiptView extends StatelessWidget {
  final Invoice invoice;
  final List<InvoiceItem> items;
  final String partyName;
  final String partyType;
  final double paperWidth;

  const InvoiceReceiptView({
    super.key,
    required this.invoice,
    required this.items,
    required this.partyName,
    required this.partyType,
    this.paperWidth = 300, // Roughly 80mm
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: paperWidth,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Column(
              children: [
                const Text('SENTERY POS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Text('Professional Shop Management', style: TextStyle(fontSize: 10)),
                Text('Invoice #: ${invoice.invoiceNumber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text('Date: ${DateFormat('dd MMM yyyy').format(invoice.invoiceDate)}', style: const TextStyle(fontSize: 10)),
              ],
            ),
          ),
          const Divider(),
          Text('Bill To: $partyName', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          Text('Type: $partyType', style: const TextStyle(fontSize: 10)),
          const Divider(),
          const Row(
            children: [
              Expanded(flex: 3, child: Text('Item', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
              Expanded(child: Text('Qty', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('Total', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
            ],
          ),
          const Divider(),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text(item.itemNameSnapshot, style: const TextStyle(fontSize: 10))),
                Expanded(child: Text('${item.quantity}', style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text(CurrencyFormatter.formatPaisa(item.lineTotal), style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
              ],
            ),
          )),
          const Divider(),
          _buildRow('Subtotal', invoice.subtotal),
          _buildRow('Discount', invoice.discountAmount),
          _buildRow('Total', invoice.totalAmount, isBold: true),
          _buildRow('Paid', invoice.amountPaid),
          _buildRow('Remaining', invoice.amountRemaining, color: invoice.amountRemaining > 0 ? AppColors.danger : AppColors.success),
          const Divider(),
          const Center(
            child: Text('Thank you for your business!', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, int paisa, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(CurrencyFormatter.formatPaisa(paisa), style: TextStyle(fontSize: 10, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }
}
