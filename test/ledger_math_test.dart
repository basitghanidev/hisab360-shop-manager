import 'package:flutter_test/flutter_test.dart';
import 'package:sentery_app/core/utils/money_utils.dart';

void main() {
  group('Ledger Calculation Engine', () {
    test('Customer Balance: Sum of Invoices minus Sum of Payments', () {
      // Scenario:
      // 1. Opening Balance: 0
      // 2. Bill 1: 1000.50
      // 3. Payment 1: 500
      // 4. Bill 2: 250.75
      // Expected Balance: 1000.50 - 500 + 250.75 = 751.25
      
      Money balance = Money.zero;
      
      // Invoice 1
      final inv1 = Money.fromDouble(1000.50);
      balance = balance + inv1;
      
      // Payment 1
      final pay1 = Money.fromDouble(500.0);
      balance = balance - pay1;
      
      // Invoice 2
      final inv2 = Money.fromDouble(250.75);
      balance = balance + inv2;
      
      expect(balance.paisa, 75125);
      expect(balance.toDouble(), 751.25);
    });

    test('Supplier Balance: Sum of Purchases minus Sum of Payments', () {
      // For suppliers: positive = we owe them
      // 1. Purchase: 5000
      // 2. We pay: 2000
      // Expected Balance: 3000
      
      Money balance = Money.zero;
      
      final pur1 = Money.fromDouble(5000);
      balance = balance + pur1; // We owe them more
      
      final pay1 = Money.fromDouble(2000);
      balance = balance - pay1; // We owe them less
      
      expect(balance.paisa, 300000);
    });
  });
}
