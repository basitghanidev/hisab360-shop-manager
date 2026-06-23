import 'package:flutter/material.dart';
import 'package:sentery_app/core/constants/app_colors.dart';

/// Single shared rule for how a balance amount should be labeled and colored,
/// anywhere in the app. Two conventions exist depending on party type:
///
/// - Supplier: positive currentBalance = we owe them = DEBIT (red).
///             negative currentBalance = they owe us / our advance = CREDIT (green).
/// - Customer / Wholesaler: positive currentBalance = they owe us = CREDIT (green).
///             negative currentBalance = we owe them / their advance = DEBIT (red).
class BalanceLabel {
  final String label;   // "Credit" or "Debit"
  final Color color;    // green or red
  final double amount;  // always positive (already abs()'d)

  const BalanceLabel({required this.label, required this.color, required this.amount});

  /// For suppliers: positive balance = Debit (we owe them).
  factory BalanceLabel.forSupplier(double balance) {
    if (balance >= 0) {
      return BalanceLabel(label: 'Debit', color: AppColors.danger, amount: balance);
    }
    return BalanceLabel(label: 'Credit', color: AppColors.success, amount: balance.abs());
  }

  /// For customers/wholesalers: positive balance = Credit (they owe us).
  factory BalanceLabel.forReceivable(double balance) {
    if (balance >= 0) {
      return BalanceLabel(label: 'Credit', color: AppColors.success, amount: balance);
    }
    return BalanceLabel(label: 'Debit', color: AppColors.danger, amount: balance.abs());
  }
}

T? firstWhereOrNull<T>(Iterable<T> list, bool Function(T) test) {
  for (var element in list) {
    if (test(element)) return element;
  }
  return null;
}
