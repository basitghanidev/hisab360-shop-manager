import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/database/database_provider.dart';
import 'package:sentery_app/core/database/daos/report_dao.dart';

class MonthlyReportData {
  final double sales;
  final double profit;
  MonthlyReportData({required this.sales, required this.profit});
}

final reportDaoProvider = Provider<ReportDao>((ref) {
  return ref.watch(databaseProvider).reportDao;
});

final monthlyReportProvider = FutureProvider<MonthlyReportData>((ref) async {
  final dao = ref.watch(reportDaoProvider);
  return MonthlyReportData(
    sales: await dao.getMonthSales(),
    profit: await dao.getMonthProfit(),
  );
});

final yearlySalesReportProvider = FutureProvider<double>((ref) async {
  return ref.watch(reportDaoProvider).getYearSales();
});

final lowStockItemsProvider = FutureProvider<List<Item>>((ref) async {
  return ref.watch(reportDaoProvider).getLowStockItems();
});

final yearlyBreakdownProvider = FutureProvider.family<List<MonthSummary>, int>((ref, year) {
  return ref.watch(reportDaoProvider).getYearlyBreakdown(year);
});
