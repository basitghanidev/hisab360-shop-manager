import 'package:drift/drift.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/item_utils.dart';
import 'package:sentery_app/core/utils/money_utils.dart';

part 'report_dao.g.dart';

class MonthSummary {
  final int month;
  final double sales, purchases, profit;
  MonthSummary({required this.month, required this.sales, required this.purchases, required this.profit});
}

class FullMonthlyReport {
  final double totalSales, wholesaleSales, retailSales;
  final double cashReceived, onlineReceived, creditGiven;
  final double totalPurchases, cashPaid, onlinePaid, creditTaken;
  final double totalExpenses;
  final double grossProfit, netProfit;
  final double supplierOutstanding, wholesalerOutstanding, customerOutstanding, netOutstanding;
  final double stockValueAtCost, stockValueAtRetail;
  final double totalAssets, totalLiabilities, netShopValue;

  FullMonthlyReport({
    required this.totalSales, required this.wholesaleSales, required this.retailSales,
    required this.cashReceived, required this.onlineReceived, required this.creditGiven,
    required this.totalPurchases, required this.cashPaid, required this.onlinePaid, required this.creditTaken,
    required this.totalExpenses,
    required this.grossProfit, required this.netProfit,
    required this.supplierOutstanding, required this.wholesalerOutstanding, required this.customerOutstanding,
    required this.netOutstanding, required this.stockValueAtCost, required this.stockValueAtRetail,
    required this.totalAssets, required this.totalLiabilities, required this.netShopValue,
  });
}

@DriftAccessor(tables: [Invoices, InvoiceItems, Suppliers, Wholesalers, Customers, Items, Payments, LedgerEntries, StockMovements, StockBatches, Expenses])
class ReportDao extends DatabaseAccessor<AppDatabase> with _$ReportDaoMixin {
  ReportDao(super.db);

  Future<double> getTodayExpenses() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = await (select(expenses)..where((t) => t.date.isBiggerOrEqualValue(today))).get();
    int totalPaisa = 0;
    for (final e in result) totalPaisa += e.amount;
    return Money.fromPaisa(totalPaisa).toDouble();
  }

  Future<double> getMonthExpenses() async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final result = await (select(expenses)..where((t) => t.date.isBiggerOrEqualValue(firstDayOfMonth))).get();
    int totalPaisa = 0;
    for (final e in result) totalPaisa += e.amount;
    return Money.fromPaisa(totalPaisa).toDouble();
  }

  Future<double> getTodaySales() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Total Sales
    final sales = await (select(invoices)
          ..where((t) => t.invoiceDate.isBiggerOrEqualValue(today) & t.invoiceType.like('sale_%')))
        .get();
    
    // Total Returns (from customers/wholesalers)
    final returns = await (select(invoices)
          ..where((t) => 
              t.invoiceDate.isBiggerOrEqualValue(today) & 
              (t.invoiceType.equals('return_customer') | t.invoiceType.equals('return_wholesaler'))))
        .get();

    int totalPaisa = 0;
    for (final i in sales) totalPaisa += i.totalAmount;
    for (final i in returns) totalPaisa -= i.totalAmount; // Subtract returns for Net Sales

    return Money.fromPaisa(totalPaisa).toDouble();
  }

  Future<double> getMonthSales() async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    
    final sales = await (select(invoices)
          ..where((t) => t.invoiceDate.isBiggerOrEqualValue(firstDayOfMonth) & t.invoiceType.like('sale_%')))
        .get();

    final returns = await (select(invoices)
          ..where((t) => 
              t.invoiceDate.isBiggerOrEqualValue(firstDayOfMonth) & 
              (t.invoiceType.equals('return_customer') | t.invoiceType.equals('return_wholesaler'))))
        .get();

    int totalPaisa = 0;
    for (final i in sales) totalPaisa += i.totalAmount;
    for (final i in returns) totalPaisa -= i.totalAmount;

    return Money.fromPaisa(totalPaisa).toDouble();
  }

  Future<double> getYearSales() async {
    final now = DateTime.now();
    final firstDayOfYear = DateTime(now.year, 1, 1);
    
    final sales = await (select(invoices)
          ..where((t) => t.invoiceDate.isBiggerOrEqualValue(firstDayOfYear) & t.invoiceType.like('sale_%')))
        .get();

    final returns = await (select(invoices)
          ..where((t) => 
              t.invoiceDate.isBiggerOrEqualValue(firstDayOfYear) & 
              (t.invoiceType.equals('return_customer') | t.invoiceType.equals('return_wholesaler'))))
        .get();

    int totalPaisa = 0;
    for (final i in sales) totalPaisa += i.totalAmount;
    for (final i in returns) totalPaisa -= i.totalAmount;

    return Money.fromPaisa(totalPaisa).toDouble();
  }

  Future<double> getMonthProfit() async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    
    final sales = await (select(invoices)
          ..where((t) => t.invoiceDate.isBiggerOrEqualValue(firstDayOfMonth) & t.invoiceType.like('sale_%')))
        .get();
    
    int profitPaisa = 0;
    for (final sale in sales) {
      final items = await (select(invoiceItems)..where((t) => t.invoiceId.equals(sale.id))).get();
      for (final item in items) {
        profitPaisa += item.lineProfit;
      }
      profitPaisa -= sale.discountAmount;
    }

    // Subtract loss from customer returns
    final returns = await (select(invoices)
          ..where((t) => 
              t.invoiceDate.isBiggerOrEqualValue(firstDayOfMonth) & 
              (t.invoiceType.equals('return_customer') | t.invoiceType.equals('return_wholesaler'))))
        .get();

    for (final ret in returns) {
      final items = await (select(invoiceItems)..where((t) => t.invoiceId.equals(ret.id))).get();
      for (final item in items) {
        // Profit lost = current sale price - original cost
        // We record costPriceAtSale in return items too.
        final revenue = item.lineTotal;
        final cost = Money.fromPaisa(item.costPriceAtSale).multiplyByDouble(item.quantity).paisa;
        profitPaisa -= (revenue - cost);
      }
    }

    return Money.fromPaisa(profitPaisa).toDouble();
  }

  Future<double> getTotalSupplierBalance() async {
    final result = await (select(suppliers)..where((t) => t.isActive.equals(true))).get();
    int totalPaisa = 0;
    for (final s in result) {
      if (s.currentBalance > 0) totalPaisa += s.currentBalance;
    }
    return Money.fromPaisa(totalPaisa).toDouble();
  }

  Future<double> getTotalWholesalerBalance() async {
    final result = await (select(wholesalers)..where((t) => t.isActive.equals(true))).get();
    int totalPaisa = 0;
    for (final w in result) {
      if (w.currentBalance > 0) totalPaisa += w.currentBalance;
    }
    return Money.fromPaisa(totalPaisa).toDouble();
  }

  Future<double> getTotalCustomerBalance() async {
    final result = await (select(customers)..where((t) => t.isActive.equals(true))).get();
    int totalPaisa = 0;
    for (final c in result) {
      if (c.currentBalance > 0) totalPaisa += c.currentBalance;
    }
    return Money.fromPaisa(totalPaisa).toDouble();
  }

  Future<double> getTotalSupplierCredit() async {
    final result = await (select(suppliers)..where((t) => t.isActive.equals(true))).get();
    int totalPaisa = 0;
    for (final s in result) {
      if (s.currentBalance < 0) totalPaisa += s.currentBalance.abs();
    }
    return Money.fromPaisa(totalPaisa).toDouble();
  }

  Future<double> getTotalWholesalerCredit() async {
    final result = await (select(wholesalers)..where((t) => t.isActive.equals(true))).get();
    int totalPaisa = 0;
    for (final w in result) {
      if (w.currentBalance < 0) totalPaisa += w.currentBalance.abs();
    }
    return Money.fromPaisa(totalPaisa).toDouble();
  }

  Future<double> getTotalCustomerCredit() async {
    final result = await (select(customers)..where((t) => t.isActive.equals(true))).get();
    int totalPaisa = 0;
    for (final c in result) {
      if (c.currentBalance < 0) totalPaisa += c.currentBalance.abs();
    }
    return Money.fromPaisa(totalPaisa).toDouble();
  }
  
  Future<List<Item>> getLowStockItems() async {
    return (select(items)
      ..where((t) => t.isActive.equals(true) & t.currentStock.isSmallerOrEqual(t.lowStockLimit)))
      .get();
  }

  Future<double> getTodayReceived() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    // Only count 'payment' and 'invoice' entry types — never 'return'.
    // A return entry for a customer represents a refund (money going OUT),
    // not money coming in. Including it would inflate the received figure.
    final result = await (select(ledgerEntries)
      ..where((t) =>
          t.entryDate.isBiggerOrEqualValue(today) &
          t.entryDate.isSmallerThanValue(tomorrow) &
          (t.partyType.equals('customer') | t.partyType.equals('wholesaler')) &
          (t.entryType.equals('payment') | t.entryType.equals('invoice'))))
      .get();

    int totalPaisa = 0;
    for (final e in result) {
      totalPaisa += e.credit;
    }
    return Money.fromPaisa(totalPaisa).toDouble();
  }

  Future<double> getTodayPaid() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final result = await (select(ledgerEntries)
      ..where((t) =>
          t.entryDate.isBiggerOrEqualValue(today) &
          t.entryDate.isSmallerThanValue(tomorrow) &
          t.partyType.equals('supplier')))
      .get();

    int totalPaisa = 0;
    for (final e in result) {
      totalPaisa += e.debit;
    }
    return Money.fromPaisa(totalPaisa).toDouble();
  }

  Future<FullMonthlyReport> getFullMonthlyReport(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);

    // --- Sales ---
    final allSales = await (select(invoices)
      ..where((t) => t.invoiceDate.isBiggerOrEqualValue(start) &
          t.invoiceDate.isSmallerThanValue(end) &
          t.invoiceType.like('sale_%'))).get();

    int wsPaisa = 0, rtPaisa = 0;
    for (final inv in allSales) {
      if (inv.invoiceType == 'sale_wholesale') wsPaisa += inv.totalAmount;
      else rtPaisa += inv.totalAmount;
    }
    final totalSalesPaisa = wsPaisa + rtPaisa;

    final receivedEntries = await (select(ledgerEntries)
      ..where((t) =>
          t.entryDate.isBiggerOrEqualValue(start) &
          t.entryDate.isSmallerThanValue(end) &
          (t.partyType.equals('customer') | t.partyType.equals('wholesaler')) &
          t.paymentId.isNotNull()))
      .get();

    int cashRecPaisa = 0, onlineRecPaisa = 0;
    for (final entry in receivedEntries) {
      final payment = await (select(payments)..where((t) => t.id.equals(entry.paymentId!))).getSingleOrNull();
      if (payment == null) continue;
      if (payment.paymentMethod == 'cash') {
        cashRecPaisa += entry.credit;
      } else {
        onlineRecPaisa += entry.credit;
      }
    }
    final creditGivenPaisa = (totalSalesPaisa - cashRecPaisa - onlineRecPaisa).clamp(0, 999999999999);

    // --- Purchases ---
    final allPurchases = await (select(invoices)
      ..where((t) => t.invoiceDate.isBiggerOrEqualValue(start) &
          t.invoiceDate.isSmallerThanValue(end) &
          t.invoiceType.equals('purchase'))).get();
    int totalPurPaisa = 0;
    for (final i in allPurchases) totalPurPaisa += i.totalAmount;

    final paidEntries = await (select(ledgerEntries)
      ..where((t) =>
          t.entryDate.isBiggerOrEqualValue(start) &
          t.entryDate.isSmallerThanValue(end) &
          t.partyType.equals('supplier') &
          t.paymentId.isNotNull()))
      .get();

    int cashPaidPaisa = 0, onlinePaidPaisa = 0;
    for (final entry in paidEntries) {
      final payment = await (select(payments)..where((t) => t.id.equals(entry.paymentId!))).getSingleOrNull();
      if (payment == null) continue;
      if (payment.paymentMethod == 'cash') {
        cashPaidPaisa += entry.debit;
      } else {
        onlinePaidPaisa += entry.debit;
      }
    }
    final creditTakenPaisa = (totalPurPaisa - cashPaidPaisa - onlinePaidPaisa).clamp(0, 999999999999);

    // --- Profit ---
    int grossProfitPaisa = 0;
    for (final sale in allSales) {
      final items = await (select(invoiceItems)..where((t) => t.invoiceId.equals(sale.id))).get();
      for (final item in items) {
        grossProfitPaisa += item.lineProfit;
      }
      grossProfitPaisa -= sale.discountAmount;
    }

    final totalExp = await getMonthExpenses();
    final totalExpPaisa = Money.fromDouble(totalExp).paisa;
    final netProfitPaisa = grossProfitPaisa - totalExpPaisa;

    // --- Outstanding ---
    final supOut = await getTotalSupplierBalance();
    final whOut = await getTotalWholesalerBalance();
    final cusOut = await getTotalCustomerBalance();
    
    // For Dashboard/Report purposes: 
    // Receivable = Customers who owe us + Wholesalers who owe us + Supplier Advances
    final supplierCredit = await getTotalSupplierCredit();
    final totalReceivable = cusOut + whOut + supplierCredit;
    
    // Payable = Suppliers we owe + Wholesaler Advances + Customer Advances
    final wholesalerCredit = await getTotalWholesalerCredit();
    final customerCredit = await getTotalCustomerCredit();
    final totalPayable = supOut + wholesalerCredit + customerCredit;

    final netOut = totalReceivable - totalPayable;

    // --- Stock Value ---
    final allItems = await (select(items)..where((t) => t.isActive.equals(true))).get();
    int costValPaisa = 0, retValPaisa = 0;
    for (final item in allItems) {
      costValPaisa += Money.fromPaisa(getEffectiveCost(item)).multiplyByDouble(item.currentStock).paisa;
      retValPaisa += Money.fromPaisa(item.retailPrice).multiplyByDouble(item.currentStock).paisa;
    }

    final totalAssets = Money.fromPaisa(costValPaisa).toDouble() + totalReceivable;
    final totalLiabilities = totalPayable;
    final netShopValue = totalAssets - totalLiabilities;

    return FullMonthlyReport(
      totalSales: Money.fromPaisa(totalSalesPaisa).toDouble(),
      wholesaleSales: Money.fromPaisa(wsPaisa).toDouble(),
      retailSales: Money.fromPaisa(rtPaisa).toDouble(),
      cashReceived: Money.fromPaisa(cashRecPaisa).toDouble(),
      onlineReceived: Money.fromPaisa(onlineRecPaisa).toDouble(),
      creditGiven: Money.fromPaisa(creditGivenPaisa).toDouble(),
      totalPurchases: Money.fromPaisa(totalPurPaisa).toDouble(),
      cashPaid: Money.fromPaisa(cashPaidPaisa).toDouble(),
      onlinePaid: Money.fromPaisa(onlinePaidPaisa).toDouble(),
      creditTaken: Money.fromPaisa(creditTakenPaisa).toDouble(),
      totalExpenses: totalExp,
      grossProfit: Money.fromPaisa(grossProfitPaisa).toDouble(),
      netProfit: Money.fromPaisa(netProfitPaisa).toDouble(),
      supplierOutstanding: supOut,
      wholesalerOutstanding: whOut,
      customerOutstanding: cusOut,
      netOutstanding: netOut,
      stockValueAtCost: Money.fromPaisa(costValPaisa).toDouble(),
      stockValueAtRetail: Money.fromPaisa(retValPaisa).toDouble(),
      totalAssets: totalAssets,
      totalLiabilities: totalLiabilities,
      netShopValue: netShopValue,
    );
  }

  Future<List<MonthSummary>> getYearlyBreakdown(int year) async {
    final results = <MonthSummary>[];
    for (int month = 1; month <= 12; month++) {
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 1);
      if (start.isAfter(DateTime.now())) break;

      final sales = await (select(invoices)
        ..where((t) => t.invoiceDate.isBiggerOrEqualValue(start) &
            t.invoiceDate.isSmallerThanValue(end) & t.invoiceType.like('sale_%'))).get();
      
      int totalSPaisa = 0;
      for (final i in sales) totalSPaisa += i.totalAmount;

      final purchases = await (select(invoices)
        ..where((t) => t.invoiceDate.isBiggerOrEqualValue(start) &
            t.invoiceDate.isSmallerThanValue(end) & t.invoiceType.equals('purchase'))).get();
      
      int totalPPaisa = 0;
      for (final i in purchases) totalPPaisa += i.totalAmount;

      int profitPaisa = 0;
      for (final sale in sales) {
        final items = await (select(invoiceItems)..where((t) => t.invoiceId.equals(sale.id))).get();
        for (final item in items) {
          profitPaisa += item.lineProfit;
        }
        profitPaisa -= sale.discountAmount;
      }

      results.add(MonthSummary(
        month: month,
        sales: Money.fromPaisa(totalSPaisa).toDouble(),
        purchases: Money.fromPaisa(totalPPaisa).toDouble(),
        profit: Money.fromPaisa(profitPaisa).toDouble(),
      ));
    }
    return results;
  }
}
