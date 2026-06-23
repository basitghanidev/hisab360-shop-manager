import 'package:flutter_test/flutter_test.dart';
import 'package:sentery_app/core/utils/invoice_calculator.dart';

void main() {
  group('Invoice Calculation Engine (Tax & Discount)', () {
    test('Calculates subtotal and discounts correctly', () {
      final items = [
        (unitPricePaisa: 10000, quantity: 2.0, discountPaisa: 500), // 200.00 - 5.00
        (unitPricePaisa: 5000, quantity: 1.5, discountPaisa: 0),   // 75.00
      ];

      final result = InvoiceCalculator.calculate(
        items: items,
        manualDiscountPaisa: 1000, // 10.00 extra off
      );

      // Subtotal: 10000*2 + 5000*1.5 = 20000 + 7500 = 27500 paisa
      // Items Discount: 500
      // Manual Discount: 1000
      // Total: 27500 - 500 - 1000 = 26000
      expect(result['subtotal'], 27500);
      expect(result['total'], 26000);
    });

    test('Calculates GST/Tax correctly', () {
      final items = [
        (unitPricePaisa: 100000, quantity: 1.0, discountPaisa: 0), // 1000.00
      ];

      final result = InvoiceCalculator.calculate(
        items: items,
        taxPercentage: 17.0, // 17% GST
      );

      // Subtotal: 100000
      // Tax: 100000 * 0.17 = 17000
      // Total: 117000
      expect(result['tax'], 17000);
      expect(result['total'], 117000);
    });
  });
}
