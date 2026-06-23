import 'package:flutter/material.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/core/widgets/app_card.dart';

class PartyBalanceSummaryCard extends StatelessWidget {
  final String partyType;
  final int currentBalance; // Now using paisa (int)

  const PartyBalanceSummaryCard({
    super.key,
    required this.partyType,
    required this.currentBalance,
  });

  @override
  Widget build(BuildContext context) {
    String title;
    String explanation;
    Color color;
    IconData icon;

    if (partyType == 'supplier') {
      if (currentBalance >= 0) {
        title = 'Hum Ne Dena Hai';
        explanation = 'You owe this supplier';
        color = AppColors.danger;
        icon = Icons.upload_outlined;
      } else {
        title = 'Hume Milna Hai / Advance';
        explanation = 'Supplier owes you or our advance';
        color = AppColors.success;
        icon = Icons.download_outlined;
      }
    } else { // Customer or Wholesaler
      if (currentBalance >= 0) {
        title = 'Hume Milna Hai';
        explanation = 'Customer owes you';
        color = AppColors.success;
        icon = Icons.download_outlined;
      } else {
        title = 'Advance / Hum Ne Dena Hai';
        explanation = 'You owe customer or their advance';
        color = AppColors.danger;
        icon = Icons.upload_outlined;
      }
    }

    return AppCard(
      color: color.withOpacity(0.1),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, color: color)),
                Text(explanation, style: AppTextStyles.caption.copyWith(color: color.withOpacity(0.8))),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.formatPaisa(currentBalance.abs()),
            style: AppTextStyles.largeTitle.copyWith(color: color, fontSize: 24),
          ),
        ],
      ),
    );
  }
}
