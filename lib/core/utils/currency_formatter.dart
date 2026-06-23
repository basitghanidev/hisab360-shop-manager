import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _format = NumberFormat('#,##0', 'en_PK');

  /// Formats an amount as currency.
  static String format(double amount) {
    if (amount < 0) {
      return '- Rs. ${_format.format(amount.abs())}';
    }
    return 'Rs. ${_format.format(amount)}';
  }

  /// Helper for database-stored paisa (integers)
  static String formatPaisa(int paisa) {
    return format(paisa / 100.0);
  }

  static String formatPK(double amount) {
    final value = amount.abs();
    final prefix = amount < 0 ? '- ' : '';
    if (value >= 10000000) {
      return '${prefix}Rs. ${(value / 10000000).toStringAsFixed(2)} Cr';
    } else if (value >= 100000) {
      return '${prefix}Rs. ${(value / 100000).toStringAsFixed(2)} Lakh';
    }
    return '${prefix}Rs. ${_format.format(value)}';
  }
}
