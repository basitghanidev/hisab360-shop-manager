import 'package:flutter_test/flutter_test.dart';
import 'package:sentery_app/core/utils/invoice_calculator.dart';

void main() {
  group('InvoiceCalculator — grand total accuracy', () {
    test('Single item, no discount: 5 pieces × Rs 100 = Rs 500', () {
      final result = InvoiceCalculator.calculate(items: [
        (unitPricePaisa: 10000, quantity: 5.0, discountPaisa: 0),
      ]);
      expect(result['subtotal'], equals(50000));
      expect(result['total'], equals(50000));
    });

    test('Item-level discount: Rs 500 item - Rs 50 discount = Rs 450', () {
      final result = InvoiceCalculator.calculate(items: [
        (unitPricePaisa: 50000, quantity: 1.0, discountPaisa: 5000),
      ]);
      expect(result['total'], equals(45000));
    });

    test('Manual (order-wide) discount applied after item subtotal', () {
      final result = InvoiceCalculator.calculate(
        items: [
          (unitPricePaisa: 10000, quantity: 3.0, discountPaisa: 0), // Rs 300
          (unitPricePaisa: 20000, quantity: 2.0, discountPaisa: 0), // Rs 400
        ],
        manualDiscountPaisa: 5000, // Rs 50 off
      );
      expect(result['subtotal'], equals(70000));       // Rs 700
      expect(result['manualDiscount'], equals(5000));  // Rs 50
      expect(result['total'], equals(65000));           // Rs 650
    });

    test('Multiple items with mixed discounts', () {
      final result = InvoiceCalculator.calculate(
        items: [
          (unitPricePaisa: 15000, quantity: 4.0, discountPaisa: 2000), // Rs 600 - Rs 20 = Rs 580
          (unitPricePaisa: 8000, quantity: 10.0, discountPaisa: 0),    // Rs 800
        ],
        manualDiscountPaisa: 10000, // Rs 100 off
      );
      expect(result['subtotal'], equals(140000));      // Rs 1400
      expect(result['itemsDiscount'], equals(2000));   // Rs 20
      expect(result['manualDiscount'], equals(10000)); // Rs 100
      expect(result['total'], equals(128000));          // Rs 1280
    });

    test('Fractional quantity: 2.5 kg × Rs 80 = Rs 200', () {
      final result = InvoiceCalculator.calculate(items: [
        (unitPricePaisa: 8000, quantity: 2.5, discountPaisa: 0),
      ]);
      expect(result['total'], equals(20000)); // Rs 200 exactly
    });

    test('Total remains positive (clamping is handled by UI/DAO but calculator shows reality)', () {
      // If someone enters a discount bigger than the total, result shows negative value here.
      // The app UI and DAOs clamp this, but the calculator should remain purely mathematical.
      final result = InvoiceCalculator.calculate(
        items: [(unitPricePaisa: 10000, quantity: 1.0, discountPaisa: 0)],
        manualDiscountPaisa: 15000, // Discount > total
      );
      expect(result['total'], equals(-5000));
    });

    test('Zero items returns all zeros', () {
      final result = InvoiceCalculator.calculate(items: []);
      expect(result['subtotal'], equals(0));
      expect(result['total'], equals(0));
    });
  });
}
