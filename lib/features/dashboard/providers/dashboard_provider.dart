import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/database/database_provider.dart';
import 'package:sentery_app/core/database/daos/report_dao.dart';

class DashboardData {
  final double todaySales;
  final double monthSales;
  final double yearSales;
  final double supplierOutstanding;
  final double wholesalerOutstanding;
  final double customerOutstanding;
  final double todayReceived;
  final double todayPaid;
  final double monthExpenses;

  final double supplierCredit;
  final double wholesalerCredit;
  final double customerCredit;

  DashboardData({
    required this.todaySales,
    required this.monthSales,
    required this.yearSales,
    required this.supplierOutstanding,
    required this.wholesalerOutstanding,
    required this.customerOutstanding,
    required this.todayReceived,
    required this.todayPaid,
    required this.monthExpenses,
    required this.supplierCredit,
    required this.wholesalerCredit,
    required this.customerCredit,
  });

  double get totalReceivable => wholesalerOutstanding + customerOutstanding + supplierCredit;
  double get totalPayable => supplierOutstanding + wholesalerCredit + customerCredit;
  double get netKhataBalance => totalReceivable - totalPayable;
}

final reportDaoProvider = Provider<ReportDao>((ref) {
  return ref.watch(databaseProvider).reportDao;
});

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final dao = ref.watch(reportDaoProvider);
  return DashboardData(
    todaySales: await dao.getTodaySales(),
    monthSales: await dao.getMonthSales(),
    yearSales: await dao.getYearSales(),
    supplierOutstanding: await dao.getTotalSupplierBalance(),
    wholesalerOutstanding: await dao.getTotalWholesalerBalance(),
    customerOutstanding: await dao.getTotalCustomerBalance(),
    todayReceived: await dao.getTodayReceived(),
    todayPaid: await dao.getTodayPaid(),
    monthExpenses: await dao.getMonthExpenses(),
    supplierCredit: await dao.getTotalSupplierCredit(),
    wholesalerCredit: await dao.getTotalWholesalerCredit(),
    customerCredit: await dao.getTotalCustomerCredit(),
  );
});
