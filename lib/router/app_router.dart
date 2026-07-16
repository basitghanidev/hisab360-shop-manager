import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/constants/app_colors.dart';

import 'package:sentery_app/features/dashboard/home_screen.dart';
import 'package:sentery_app/features/dashboard/hisab_kitab_screen.dart';
import 'package:sentery_app/features/items/screens/item_list_screen.dart';
import 'package:sentery_app/features/items/screens/item_detail_screen.dart';
import 'package:sentery_app/features/items/screens/add_edit_item_screen.dart';
import 'package:sentery_app/features/people/screens/people_screen.dart';
import 'package:sentery_app/features/customers/screens/customer_list_screen.dart';
import 'package:sentery_app/features/customers/screens/customer_detail_screen.dart';
import 'package:sentery_app/features/customers/screens/add_edit_customer_screen.dart';
import 'package:sentery_app/features/suppliers/screens/supplier_list_screen.dart';
import 'package:sentery_app/features/suppliers/screens/supplier_detail_screen.dart';
import 'package:sentery_app/features/suppliers/screens/add_edit_supplier_screen.dart';

import 'package:sentery_app/features/settings/screens/settings_screen.dart';
import 'package:sentery_app/features/settings/screens/shop_profile_screen.dart';
import 'package:sentery_app/features/settings/screens/audit_log_screen.dart';
import 'package:sentery_app/features/items/screens/category_management_screen.dart';
import 'package:sentery_app/features/backup/screens/backup_screen.dart';
import 'package:sentery_app/features/returns/screens/create_return_screen.dart';
import 'package:sentery_app/features/reports/screens/monthly_report_screen.dart';
import 'package:sentery_app/features/reports/screens/yearly_report_screen.dart';
import 'package:sentery_app/features/reports/screens/business_stats_screen.dart';
import 'package:sentery_app/features/reports/screens/low_stock_screen.dart';
import 'package:sentery_app/features/reports/screens/stock_report_screen.dart';
import 'package:sentery_app/features/reports/screens/outstanding_report_screen.dart';
import 'package:sentery_app/features/reports/screens/reports_home_screen.dart';
import 'package:sentery_app/features/invoices/screens/purchase_invoice_screen.dart';
import 'package:sentery_app/features/invoices/screens/sale_invoice_screen.dart';
import 'package:sentery_app/features/invoices/screens/invoice_list_screen.dart';
import 'package:sentery_app/features/invoices/screens/invoice_detail_screen.dart';
import 'package:sentery_app/features/invoices/screens/drafts_list_screen.dart';
import 'package:sentery_app/features/wholesalers/screens/wholesaler_list_screen.dart';
import 'package:sentery_app/features/wholesalers/screens/wholesaler_detail_screen.dart';
import 'package:sentery_app/features/wholesalers/screens/add_edit_wholesaler_screen.dart';
import 'package:sentery_app/features/wholesalers/screens/wholesaler_prices_screen.dart';
import 'package:sentery_app/features/people/screens/add_ledger_entry_screen.dart';
import 'package:sentery_app/features/expenses/screens/expense_list_screen.dart';
import 'package:sentery_app/features/expenses/screens/add_expense_screen.dart';

import 'package:sentery_app/features/settings/screens/expense_category_management_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      // Main shell with adaptive navigation
      ShellRoute(
        builder: (context, state, child) {
          final isDesktop = MediaQuery.of(context).size.width > 900;
          final selectedIndex = _calculateSelectedIndex(state.fullPath ?? '/home');

          if (isDesktop) {
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (index) => _onItemTapped(index, context),
                    labelType: NavigationRailLabelType.all,
                    backgroundColor: AppColors.surface,
                    selectedIconTheme: const IconThemeData(color: AppColors.primary),
                    unselectedIconTheme: const IconThemeData(color: AppColors.textSecondary),
                    selectedLabelTextStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                    unselectedLabelTextStyle: const TextStyle(color: AppColors.textSecondary),
                    destinations: const [
                      NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: Text('Home')),
                      NavigationRailDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: Text('Hisab')),
                      NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: Text('Items')),
                      NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('People')),
                      NavigationRailDestination(icon: Icon(Icons.outbond_outlined), selectedIcon: Icon(Icons.outbond), label: Text('Expenses')),
                    ],
                  ),
                  const VerticalDivider(thickness: 1, width: 1),
                  Expanded(child: child),
                ],
              ),
            );
          }

          return Scaffold(
            body: child,
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: selectedIndex,
              onTap: (index) => _onItemTapped(index, context),
              type: BottomNavigationBarType.fixed,
              backgroundColor: AppColors.surface,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.textSecondary,
              showUnselectedLabels: true,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'Hisab'),
                BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2), label: 'Items'),
                BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'People'),
                BottomNavigationBarItem(icon: Icon(Icons.outbond_outlined), activeIcon: Icon(Icons.outbond), label: 'Expenses'),
              ],
            ),
          );
        },
        routes: [
          GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
          GoRoute(path: '/hisab', builder: (c, s) => const HisabKitabScreen()),
          GoRoute(path: '/items', builder: (c, s) => const ItemListScreen()),
          GoRoute(path: '/people', builder: (c, s) => const PeopleScreen()),
          GoRoute(path: '/expenses', builder: (c, s) => const ExpenseListScreen()),
        ],
      ),
      
      GoRoute(path: '/reports', builder: (c, s) => const ReportsHomeScreen()),
      GoRoute(path: '/expenses/add', builder: (c, s) => const AddExpenseScreen()),
      
      // Supplier routes
      GoRoute(path: '/suppliers/add', builder: (c, s) => const AddEditSupplierScreen()),
      GoRoute(path: '/suppliers/:id', builder: (c, s) => 
        SupplierDetailScreen(id: int.parse(s.pathParameters['id']!))),
      GoRoute(path: '/suppliers/:id/edit', builder: (c, s) => 
        AddEditSupplierScreen(id: int.parse(s.pathParameters['id']!))),
      
      // Customer routes
      GoRoute(path: '/customers/add', builder: (c, s) => const AddEditCustomerScreen()),
      GoRoute(path: '/customers/:id', builder: (c, s) => 
        CustomerDetailScreen(id: int.parse(s.pathParameters['id']!))),
      GoRoute(path: '/customers/:id/edit', builder: (c, s) => 
        AddEditCustomerScreen(id: int.parse(s.pathParameters['id']!))),
      
      // Wholesaler routes
      GoRoute(path: '/wholesalers/add', builder: (c, s) => const AddEditWholesalerScreen()),
      GoRoute(path: '/wholesalers/:id', builder: (c, s) => 
        WholesalerDetailScreen(id: int.parse(s.pathParameters['id']!))),
      GoRoute(path: '/wholesalers/:id/edit', builder: (c, s) => 
        AddEditWholesalerScreen(id: int.parse(s.pathParameters['id']!))),
      GoRoute(path: '/wholesalers/:id/prices', builder: (c, s) => 
        WholesalerPricesScreen(id: int.parse(s.pathParameters['id']!))),
      
      // Item routes
      GoRoute(path: '/items/add', builder: (c, s) => const AddEditItemScreen()),
      GoRoute(path: '/items/:id', builder: (c, s) => 
        ItemDetailScreen(id: int.parse(s.pathParameters['id']!))),
      GoRoute(path: '/items/:id/edit', builder: (c, s) => 
        AddEditItemScreen(id: int.parse(s.pathParameters['id']!))),
      
      // Invoice routes
      GoRoute(path: '/invoice/list', builder: (c, s) => const InvoiceListScreen()),
      GoRoute(path: '/invoice/purchase', builder: (c, s) => const PurchaseInvoiceScreen()),
      GoRoute(path: '/invoice/sale', builder: (c, s) => const SaleInvoiceScreen()),
      GoRoute(path: '/invoice/:id', builder: (c, s) => 
        InvoiceDetailScreen(id: int.parse(s.pathParameters['id']!))),
      GoRoute(path: '/drafts', builder: (c, s) => const DraftsListScreen()),
      
      // Return and Ledger Entry routes
      GoRoute(path: '/returns/create', builder: (c, s) => const CreateReturnScreen()),
      GoRoute(path: '/people/add-ledger-entry', builder: (c, s) {
        final partyType = s.uri.queryParameters['partyType']!;
        final partyId = int.parse(s.uri.queryParameters['partyId']!);
        final isGave = s.uri.queryParameters['isGave'] == 'true';
        return AddLedgerEntryScreen(
          partyType: partyType,
          partyId: partyId,
          isGave: isGave,
        );
      }),
      
      // Report routes
      GoRoute(path: '/reports/monthly', builder: (c, s) => const MonthlyReportScreen()),
      GoRoute(path: '/reports/yearly', builder: (c, s) => const YearlyReportScreen()),
      GoRoute(path: '/reports/business-stats', builder: (c, s) => const BusinessStatsScreen()),
      GoRoute(path: '/reports/low-stock', builder: (c, s) => const LowStockScreen()),
      GoRoute(path: '/reports/stock', builder: (c, s) => const StockReportScreen()),
      GoRoute(path: '/reports/outstanding', builder: (c, s) => const OutstandingReportScreen()),
      
      // Settings
      GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      GoRoute(path: '/settings/shop-profile', builder: (c, s) => const ShopProfileScreen()),
      GoRoute(path: '/settings/audit-logs', builder: (c, s) => const AuditLogScreen()),
      GoRoute(path: '/settings/categories', builder: (c, s) => const CategoryManagementScreen()),
      GoRoute(path: '/settings/expense-categories', builder: (c, s) => const ExpenseCategoryManagementScreen()),
      GoRoute(path: '/backup', builder: (c, s) => const BackupScreen()),
    ],
  );
});

int _calculateSelectedIndex(String location) {
  if (location.startsWith('/home')) return 0;
  if (location.startsWith('/hisab')) return 1;
  if (location.startsWith('/items')) return 2;
  if (location.startsWith('/people')) return 3;
  if (location.startsWith('/expenses')) return 4;
  return 0;
}

void _onItemTapped(int index, BuildContext context) {
  switch (index) {
    case 0: context.go('/home'); break;
    case 1: context.go('/hisab'); break;
    case 2: context.go('/items'); break;
    case 3: context.go('/people'); break;
    case 4: context.go('/expenses'); break;
  }
}
