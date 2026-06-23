import 'package:flutter_test/flutter_test.dart';
import 'package:sentery_app/core/utils/money_utils.dart';

void main() {
  group('Money — floating-point precision', () {
    test('0.1 + 0.2 equals exactly 0.3 (not 0.30000000000000004)', () {
      final a = Money.fromDouble(0.1);
      final b = Money.fromDouble(0.2);
      final result = a + b;
      expect(result.toDouble(), equals(0.3));
      expect(result.paisa, equals(30)); // 30 paisa = Rs 0.30 exactly
    });

    test('1.005 rounds to 1.01, not 1.00 (banker rounding trap)', () {
      final m = Money.fromString('1.005');
      expect(m.paisa, equals(101)); // Rs 1.01
    });

    test('Large amounts: 99999.99 stores correctly', () {
      final m = Money.fromDouble(99999.99);
      expect(m.paisa, equals(9999999));
      expect(m.toDouble(), equals(99999.99));
    });

    test('Quantity × price: 3 × 33.33 = 99.99 exactly', () {
      final price = Money.fromDouble(33.33);
      final total = price.multiplyByDouble(3);
      expect(total.paisa, equals(9999)); // Rs 99.99
    });

    test('Zero is zero — no ghost paisa', () {
      expect(Money.zero.paisa, equals(0));
      expect(Money.fromDouble(0.0).paisa, equals(0));
      expect(Money.fromString('').paisa, equals(0));
      expect(Money.fromString('0').paisa, equals(0));
    });

    test('Negative money has correct abs()', () {
      final m = Money.fromDouble(-500.0);
      expect(m.isNegative, isTrue);
      expect(m.abs().paisa, equals(50000));
    });

    test('fromString handles comma-formatted input from UI', () {
      // User might type "1,500" in the amount field
      final m = Money.fromString('1,500');
      expect(m.paisa, equals(150000)); // Rs 1500.00
    });
  });
}
