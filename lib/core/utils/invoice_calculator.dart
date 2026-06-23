import 'package:sentery_app/core/utils/money_utils.dart';

class InvoiceCalculator {
  static Map<String, int> calculate({
    required List<({int unitPricePaisa, double quantity, int discountPaisa})> items,
    int manualDiscountPaisa = 0,
    double taxPercentage = 0.0,
  }) {
    int subtotalPaisa = 0;
    int itemsDiscountPaisa = 0;

    for (final item in items) {
      final lineSubtotal = Money.fromPaisa(item.unitPricePaisa).multiplyByDouble(item.quantity).paisa;
      subtotalPaisa += lineSubtotal;
      itemsDiscountPaisa += item.discountPaisa;
    }

    final totalBeforeTax = subtotalPaisa - itemsDiscountPaisa - manualDiscountPaisa;
    
    int taxPaisa = 0;
    if (taxPercentage > 0) {
      taxPaisa = (Money.fromPaisa(totalBeforeTax).toDouble() * (taxPercentage / 100.0) * 100).round();
    }

    final totalAmount = totalBeforeTax + taxPaisa;

    return {
      'subtotal': subtotalPaisa,
      'itemsDiscount': itemsDiscountPaisa,
      'manualDiscount': manualDiscountPaisa,
      'tax': taxPaisa,
      'total': totalAmount,
    };
  }
}
