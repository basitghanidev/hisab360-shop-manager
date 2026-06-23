import 'package:flutter_test/flutter_test.dart';
import 'package:sentery_app/core/utils/money_utils.dart';
import 'package:decimal/decimal.dart';

void main() {
  group('Money Utility Precision Tests', () {
    test('Avoids floating point error (0.1 + 0.2)', () {
      final m1 = Money.fromDouble(0.1);
      final m2 = Money.fromDouble(0.2);
      final result = m1 + m2;
      
      // Standard double would be 0.30000000000000004
      expect(result.toDouble(), 0.3);
      expect(result.paisa, 30);
    });

    test('Complex discount math remains precise', () {
      // 100.50 with 15% discount
      final price = Money.fromDouble(100.50);
      final discountFactor = Decimal.parse('0.15');
      final discount = price * discountFactor;
      final total = price - discount;

      // 100.50 * 0.15 = 15.075 -> rounded to 15.08 paisa?
      // Actually 10050 * 0.15 = 1507.5 -> rounded to 1508 paisa
      expect(discount.paisa, 1508);
      expect(total.paisa, 8542);
      expect(total.toDouble(), 85.42);
    });

    test('Multiplication by quantity (double)', () {
      final price = Money.fromDouble(15.75);
      final qty = 1.333; // e.g. weight in KG
      final total = price.multiplyByDouble(qty);

      // 1575 * 1.333 = 2099.475 -> 2099 paisa
      expect(total.paisa, 2099);
    });
  });
}
