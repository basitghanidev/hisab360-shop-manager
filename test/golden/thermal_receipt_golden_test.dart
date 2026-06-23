import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/features/invoices/widgets/invoice_receipt_view.dart';

void main() {
  testWidgets('InvoiceReceiptView Golden Test (80mm)', (WidgetTester tester) async {
    final invoice = Invoice(
      id: 1,
      invoiceNumber: 'INV-2026-0001',
      invoiceType: 'sale_retail',
      isTemporaryCustomer: false,
      previousBalance: 0,
      totalBalanceAfter: 15000,
      totalAmount: 15000,
      amountPaid: 0,
      amountRemaining: 15000,
      subtotal: 15000,
      discountAmount: 0,
      invoiceDate: DateTime(2026, 6, 20),
      createdAt: DateTime(2026, 6, 20),
      status: 'pending',
    );

    final items = [
      InvoiceItem(
        id: 1,
        invoiceId: 1,
        itemId: 1,
        itemNameSnapshot: 'Test Item 1',
        quantity: 2.0,
        unitTypeSnapshot: 'Piece',
        salePrice: 5000,
        costPriceAtSale: 4000,
        discountAmount: 0,
        lineTotal: 10000,
        lineProfit: 2000,
      ),
      InvoiceItem(
        id: 2,
        invoiceId: 1,
        itemId: 2,
        itemNameSnapshot: 'Test Item 2',
        quantity: 1.0,
        unitTypeSnapshot: 'Piece',
        salePrice: 5000,
        costPriceAtSale: 4000,
        discountAmount: 0,
        lineTotal: 5000,
        lineProfit: 1000,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.grey,
          body: Center(
            child: RepaintBoundary(
              child: InvoiceReceiptView(
                invoice: invoice,
                items: items,
                partyName: 'Test Customer',
                partyType: 'Customer',
                paperWidth: 300,
              ),
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(InvoiceReceiptView),
      matchesGoldenFile('receipt_80mm.png'),
    );
  });

  testWidgets('InvoiceReceiptView Golden Test (58mm)', (WidgetTester tester) async {
    final invoice = Invoice(
      id: 1,
      invoiceNumber: 'INV-2026-0001',
      invoiceType: 'sale_retail',
      isTemporaryCustomer: false,
      previousBalance: 0,
      totalBalanceAfter: 15000,
      totalAmount: 15000,
      amountPaid: 0,
      amountRemaining: 15000,
      subtotal: 15000,
      discountAmount: 0,
      invoiceDate: DateTime(2026, 6, 20),
      createdAt: DateTime(2026, 6, 20),
      status: 'pending',
    );

    final items = [
      InvoiceItem(
        id: 1,
        invoiceId: 1,
        itemId: 1,
        itemNameSnapshot: 'Test Item 1',
        quantity: 2.0,
        unitTypeSnapshot: 'Piece',
        salePrice: 5000,
        costPriceAtSale: 4000,
        discountAmount: 0,
        lineTotal: 10000,
        lineProfit: 2000,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.grey,
          body: Center(
            child: RepaintBoundary(
              child: InvoiceReceiptView(
                invoice: invoice,
                items: items,
                partyName: 'Test Customer',
                partyType: 'Customer',
                paperWidth: 200, // Roughly 58mm
              ),
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(InvoiceReceiptView),
      matchesGoldenFile('receipt_58mm.png'),
    );
  });
}
