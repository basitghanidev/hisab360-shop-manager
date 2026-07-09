import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/database/database_provider.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';

class LedgerEntryTile extends ConsumerWidget {
  final LedgerEntry entry;
  const LedgerEntryTile({super.key, required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isDebit = entry.debit > 0;
    
    Color color;
    String actionLabel;
    int amountPaisa;

    if (entry.partyType == 'supplier') {
      if (isDebit) { // We paid supplier
        color = AppColors.success;
        actionLabel = entry.entryType == 'payment' ? 'Raqam Ada Ki (Paid)' : 'Maine Diye (Adjustment)';
        amountPaisa = entry.debit;
      } else { // Supplier gave us goods (Invoice) or they paid us (Return)
        color = AppColors.danger;
        actionLabel = entry.entryType == 'invoice' ? 'Maal Liye (Purchase)' : (entry.entryType == 'return' ? 'Maal Wapsi (Return)' : 'Maine Liye (Adjustment)');
        amountPaisa = entry.credit;
      }
    } else { // Customer or Wholesaler
      if (entry.credit > 0) { // They paid us
        color = AppColors.success;
        actionLabel = entry.entryType == 'payment' ? 'Wasooli (Received)' : (entry.entryType == 'return' ? 'Maal Wapsi (Return)' : 'Maine Liye (Adjustment)');
        amountPaisa = entry.credit;
      } else { // We gave them goods (Invoice) or we paid them (Refund/Return)
        color = AppColors.danger;
        if (entry.entryType == 'invoice') {
          actionLabel = 'Maal Diya (Sale)';
          amountPaisa = entry.debit;
        } else if (entry.entryType == 'return') {
          // ─── FIXED: return shows RED "Hum Ne Dena Hai" ───────────────
          actionLabel = 'Maal Wapsi — Hum Ne Dena Hai';
          amountPaisa = entry.debit;
          // ─────────────────────────────────────────────────────────────
        } else if (entry.entryType == 'payment') {
          actionLabel = 'Wapsi Adaigi (Refund Paid)';
          amountPaisa = entry.debit;
        } else {
          actionLabel = 'Maine Diye (Adjustment)';
          amountPaisa = entry.debit;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<String?>(
                      future: entry.invoiceId != null ? _fetchInvoiceNumber(ref, entry.invoiceId!) : Future.value(null),
                      builder: (context, snap) {
                        final title = entry.entryType == 'payment' && snap.hasData 
                            ? 'Settlement for Bill #${snap.data}' 
                            : _describeEntry(entry.entryType);
                        return Text(
                          title, 
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    Text(DateFormat('dd MMM, hh:mm a').format(entry.entryDate),
                        style: AppTextStyles.caption.copyWith(color: Colors.grey[600])),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: color.withOpacity(0.2)),
                      ),
                      child: Text('Bal: ${CurrencyFormatter.formatPaisa(entry.balanceAfter.abs())}',
                          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.formatPaisa(amountPaisa),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(actionLabel, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          if (entry.notes != null && entry.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(entry.notes!, style: TextStyle(fontSize: 13, color: Colors.grey[700], fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  Future<String?> _fetchInvoiceNumber(WidgetRef ref, int invoiceId) async {
    final db = ref.read(databaseProvider);
    final inv = await (db.select(db.invoices)..where((t) => t.id.equals(invoiceId))).getSingleOrNull();
    return inv?.invoiceNumber;
  }

  String _describeEntry(String type) {
    switch (type) {
      case 'invoice': return 'Transaction (Sooda)';
      case 'payment': return 'Payment (Raqam)';
      case 'return': return 'Maal Wapsi (Return)';
      case 'opening_balance': return 'Starting Balance';
      case 'adjustment': return 'Adjustment';
      default: return type.toUpperCase();
    }
  }
}
