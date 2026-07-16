import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:sentery_app/core/database/daos/supplier_dao.dart';
import 'package:sentery_app/core/database/daos/wholesaler_dao.dart';
import 'package:sentery_app/core/database/daos/item_dao.dart';
import 'package:sentery_app/core/database/daos/customer_dao.dart';
import 'package:sentery_app/core/database/daos/invoice_dao.dart';
import 'package:sentery_app/core/database/daos/report_dao.dart';
import 'package:sentery_app/core/database/daos/return_dao.dart';
import 'package:sentery_app/core/database/daos/payment_dao.dart';
import 'package:sentery_app/core/database/daos/audit_dao.dart';
import 'package:sentery_app/core/database/daos/settings_dao.dart';
import 'package:sentery_app/core/database/daos/draft_dao.dart';
import 'package:sentery_app/core/database/daos/expense_dao.dart';

part 'app_database.g.dart';

class AppSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get shopName => text().withDefault(const Constant('Shop Management'))();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get language => text().withDefault(const Constant('en'))(); 
  TextColumn get costingMethod => text().withDefault(const Constant('average'))(); 
  IntColumn get lastItemCode => integer().withDefault(const Constant(0))();
  TextColumn get pdfPageSize => text().withDefault(const Constant('A4'))(); // A4, Roll80, Roll58
}

class ItemCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get nameUrdu => text().nullable()();
}

class UnitTypes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  TextColumn get nameUrdu => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
}

class Items extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get itemCode => text().nullable()();
  TextColumn get name => text().withLength(min: 1, max: 150)();
  TextColumn get nameUrdu => text().nullable()();
  IntColumn get categoryId => integer().nullable().references(ItemCategories, #id)();
  IntColumn get supplierId => integer().nullable().references(Suppliers, #id)();
  IntColumn get unitTypeId => integer().references(UnitTypes, #id)();
  IntColumn get purchasePrice => integer().withDefault(const Constant(0))();
  IntColumn get lastPurchasePrice => integer().withDefault(const Constant(0))();
  IntColumn get averageCost => integer().withDefault(const Constant(0))();
  IntColumn get defaultResellerPrice => integer().withDefault(const Constant(0))();
  IntColumn get retailPrice => integer().withDefault(const Constant(0))();
  RealColumn get currentStock => real().withDefault(const Constant(0.0))();
  RealColumn get lowStockLimit => real().withDefault(const Constant(5.0))();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class ItemPriceHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId => integer().references(Items, #id)();
  IntColumn get oldPrice => integer().withDefault(const Constant(0))();
  IntColumn get newPrice => integer().withDefault(const Constant(0))();
  TextColumn get priceType => text()(); 
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class StockBatches extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId => integer().references(Items, #id)();
  IntColumn get supplierId => integer().nullable().references(Suppliers, #id)();
  IntColumn get purchaseInvoiceId => integer().nullable().references(Invoices, #id)();
  RealColumn get quantityAdded => real().withDefault(const Constant(0.0))();
  RealColumn get quantityRemaining => real().withDefault(const Constant(0.0))();
  IntColumn get purchasePrice => integer().withDefault(const Constant(0))();
  DateTimeColumn get purchaseDate => dateTime().withDefault(currentDateAndTime)();
}

class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get openingBalance => integer().withDefault(const Constant(0))();
  IntColumn get currentBalance => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class Wholesalers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get area => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get openingBalance => integer().withDefault(const Constant(0))();
  IntColumn get creditLimit => integer().withDefault(const Constant(0))();
  IntColumn get currentBalance => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  IntColumn get openingBalance => integer().withDefault(const Constant(0))();
  IntColumn get creditLimit => integer().withDefault(const Constant(0))();
  IntColumn get currentBalance => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isTemporary => boolean().withDefault(const Constant(false))();
}

class WholesalerItemPrices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get wholesalerId => integer().references(Wholesalers, #id)();
  IntColumn get itemId => integer().references(Items, #id)();
  IntColumn get customPrice => integer().withDefault(const Constant(0))();
  DateTimeColumn get effectiveFrom => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get effectiveTo => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
}

class Invoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoiceNumber => text().unique()();
  TextColumn get invoiceType => text()(); 
  IntColumn get supplierId => integer().nullable().references(Suppliers, #id)();
  IntColumn get wholesalerId => integer().nullable().references(Wholesalers, #id)();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  BoolColumn get isTemporaryCustomer => boolean().withDefault(const Constant(false))();
  TextColumn get tempCustomerName => text().nullable()();

  // snapshot fields
  IntColumn get previousBalance => integer().withDefault(const Constant(0))();
  IntColumn get totalBalanceAfter => integer().withDefault(const Constant(0))();
  TextColumn get partyNameSnapshot => text().nullable()();
  TextColumn get partyTypeSnapshot => text().nullable()(); // customer, wholesaler, supplier

  // Payment Details (for receipts)
  TextColumn get paymentMethod => text().nullable()(); // cash, online, mixed, credit
  TextColumn get onlineMethod => text().nullable()(); // easypaisa, jazzcash, bank_transfer, other
  TextColumn get transactionId => text().nullable()();
  TextColumn get accountNumber => text().nullable()();
  TextColumn get senderName => text().nullable()();

  // Receipt specific fields
  IntColumn get linkedInvoiceId => integer().nullable().references(Invoices, #id)();
  TextColumn get linkedInvoiceNumberSnapshot => text().nullable()();
  IntColumn get receiptPreviousRemaining => integer().nullable()();
  IntColumn get receiptPaidToday => integer().nullable()();
  IntColumn get receiptFinalRemaining => integer().nullable()();

  IntColumn get subtotal => integer().withDefault(const Constant(0))();
  IntColumn get discountAmount => integer().withDefault(const Constant(0))();
  IntColumn get totalAmount => integer().withDefault(const Constant(0))();
  IntColumn get amountPaid => integer().withDefault(const Constant(0))();
  IntColumn get amountRemaining => integer().withDefault(const Constant(0))();
  DateTimeColumn get invoiceDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get originalInvoiceId => integer().nullable().references(Invoices, #id)();
  TextColumn get notes => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
}

class InvoiceItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get invoiceId => integer().references(Invoices, #id)();
  IntColumn get itemId => integer().references(Items, #id)();
  TextColumn get itemNameSnapshot => text()();
  RealColumn get quantity => real().withDefault(const Constant(0.0))();
  TextColumn get unitTypeSnapshot => text()();
  IntColumn get salePrice => integer().withDefault(const Constant(0))();
  IntColumn get costPriceAtSale => integer().withDefault(const Constant(0))();
  IntColumn get discountAmount => integer().withDefault(const Constant(0))();
  IntColumn get lineTotal => integer().withDefault(const Constant(0))();
  IntColumn get lineProfit => integer().withDefault(const Constant(0))();
  TextColumn get itemNote => text().nullable()();
  TextColumn get manualPriceChangeReason => text().nullable()();
}

class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get invoiceId => integer().nullable().references(Invoices, #id)();
  TextColumn get paymentMethod => text()(); // Cash, Online, Mixed, Credit
  IntColumn get amount => integer().withDefault(const Constant(0))();
  DateTimeColumn get paymentDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get onlineMethod => text().nullable()(); 
  TextColumn get transactionId => text().nullable()();
  TextColumn get accountNumber => text().nullable()();
  TextColumn get senderName => text().nullable()();
  TextColumn get notes => text().nullable()();
  
  // v6 fields
  TextColumn get paymentDirection => text().withDefault(const Constant('money_in'))(); // money_in, money_out
  IntColumn get partyId => integer().nullable()();
  TextColumn get partyType => text().nullable()();
}

class LedgerEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get partyType => text()(); // supplier, wholesaler, customer
  IntColumn get partyId => integer()();
  DateTimeColumn get entryDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get entryType => text()(); // opening_balance, invoice, payment, return, adjustment
  IntColumn get invoiceId => integer().nullable().references(Invoices, #id)();
  IntColumn get paymentId => integer().nullable().references(Payments, #id)();
  IntColumn get debit => integer().withDefault(const Constant(0))();
  IntColumn get credit => integer().withDefault(const Constant(0))();
  IntColumn get balanceAfter => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class BackupLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get backupDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get status => text()(); 
  IntColumn get recordCount => integer().withDefault(const Constant(0))();
  TextColumn get errorMessage => text().nullable()();
}

class AuditLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get actionName => text()(); 
  TextColumn get targetTable => text()();
  IntColumn get recordId => integer()();
  TextColumn get oldValue => text().nullable()();
  TextColumn get newValue => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class PriceLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get wholesalerId => integer().references(Wholesalers, #id)();
  IntColumn get itemId => integer().references(Items, #id)();
  IntColumn get price => integer().withDefault(const Constant(0))();
  DateTimeColumn get changedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get reason => text().nullable()();
}

class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId => integer().references(Items, #id)();
  TextColumn get movementType => text()();
  RealColumn get quantity => real().withDefault(const Constant(0.0))();
  RealColumn get balanceAfter => real().withDefault(const Constant(0.0))();
  IntColumn get referenceInvoiceId => integer().nullable().references(Invoices, #id)();
  DateTimeColumn get movedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();
}

class DraftInvoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get draftType => text()(); // sale, purchase, payment, return
  TextColumn get partyType => text().nullable()(); // customer, wholesaler, supplier
  IntColumn get partyId => integer().nullable()();
  TextColumn get partyNameSnapshot => text().nullable()();
  TextColumn get payloadJson => text()();
  IntColumn get totalPreview => integer().withDefault(const Constant(0))();
  IntColumn get itemCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class ExpenseCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get nameUrdu => text().nullable()();
}

class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().nullable().references(ExpenseCategories, #id)();
  IntColumn get amount => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [
  AppSettings,
  ItemCategories,
  UnitTypes,
  Items,
  ItemPriceHistory,
  StockBatches,
  Suppliers,
  Wholesalers,
  Customers,
  WholesalerItemPrices,
  Invoices,
  InvoiceItems,
  Payments,
  LedgerEntries,
  BackupLogs,
  AuditLogs,
  PriceLog,
  StockMovements,
  DraftInvoices,
  ExpenseCategories,
  Expenses,
], daos: [
  SupplierDao,
  WholesalerDao,
  ItemDao,
  CustomerDao,
  InvoiceDao,
  ReportDao,
  ReturnDao,
  PaymentDao,
  AuditDao,
  SettingsDao,
  DraftDao,
  ExpenseDao,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase()
      : super(driftDatabase(
          name: 'hisab360_v1', // Renamed for professional branding and safety
        ));
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 11; 

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _insertDefaultData();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 11) {
        await m.createTable(expenseCategories);
        await m.createTable(expenses);
      }
      if (from < 10) {
        await m.addColumn(appSettings, appSettings.pdfPageSize);
      }
      if (from < 6) {
        // v6 migrations
        await m.addColumn(invoices, invoices.previousBalance);
        await m.addColumn(invoices, invoices.totalBalanceAfter);
        await m.addColumn(invoices, invoices.partyNameSnapshot);
        await m.addColumn(invoiceItems, invoiceItems.manualPriceChangeReason);
        await m.addColumn(payments, payments.paymentDirection);
        await m.addColumn(payments, payments.partyId);
        await m.addColumn(payments, payments.partyType);
      }
      if (from < 7) {
        await m.addColumn(appSettings, appSettings.lastItemCode);
      }
      if (from < 8) {
        await m.addColumn(invoices, invoices.partyTypeSnapshot);
        await m.addColumn(invoices, invoices.paymentMethod);
        await m.addColumn(invoices, invoices.onlineMethod);
        await m.addColumn(invoices, invoices.transactionId);
        await m.addColumn(invoices, invoices.accountNumber);
        await m.addColumn(invoices, invoices.senderName);
        await m.addColumn(invoices, invoices.linkedInvoiceId);
        await m.addColumn(invoices, invoices.linkedInvoiceNumberSnapshot);
        await m.addColumn(invoices, invoices.receiptPreviousRemaining);
        await m.addColumn(invoices, invoices.receiptPaidToday);
        await m.addColumn(invoices, invoices.receiptFinalRemaining);
        
        await m.createTable(draftInvoices);
      }
      if (from < 9) {
        // Massive Refactor: Real -> Int (paisa)
        await m.createAll(); 
      }
    },
  );

  Future<void> _insertDefaultData() async {
    await batch((batch) {
      batch.insertAll(unitTypes, [
        UnitTypesCompanion.insert(name: 'Piece', nameUrdu: Value('Adad'), isDefault: Value(true)),
        UnitTypesCompanion.insert(name: 'KG', nameUrdu: Value('Kilo')),
        UnitTypesCompanion.insert(name: 'Meter', nameUrdu: Value('Meter')),
        UnitTypesCompanion.insert(name: 'Litre', nameUrdu: Value('Litre')),
        UnitTypesCompanion.insert(name: 'Box', nameUrdu: Value('Dabba')),
        UnitTypesCompanion.insert(name: 'Bundle', nameUrdu: Value('Gatha')),
      ]);

      batch.insertAll(itemCategories, [
        ItemCategoriesCompanion.insert(name: 'Pipes & Fittings', nameUrdu: Value('Pipes')),
        ItemCategoriesCompanion.insert(name: 'Taps & Valves', nameUrdu: Value('Nals')),
        ItemCategoriesCompanion.insert(name: 'Tiles', nameUrdu: Value('Tiles')),
        ItemCategoriesCompanion.insert(name: 'Other', nameUrdu: Value('Aur')),
      ]);

      batch.insertAll(expenseCategories, [
        ExpenseCategoriesCompanion.insert(name: 'Rent', nameUrdu: Value('Kiraya')),
        ExpenseCategoriesCompanion.insert(name: 'Electricity', nameUrdu: Value('Bijli')),
        ExpenseCategoriesCompanion.insert(name: 'Salaries', nameUrdu: Value('Tankhwah')),
        ExpenseCategoriesCompanion.insert(name: 'Transport', nameUrdu: Value('Sawari')),
        ExpenseCategoriesCompanion.insert(name: 'Tea/Food', nameUrdu: Value('Chaye Khana')),
        ExpenseCategoriesCompanion.insert(name: 'Other', nameUrdu: Value('Aur')),
      ]);

      batch.insert(appSettings, AppSettingsCompanion.insert());
    });
  }
}
