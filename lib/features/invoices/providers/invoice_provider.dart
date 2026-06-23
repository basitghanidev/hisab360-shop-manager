import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/database/database_provider.dart';
import 'package:sentery_app/core/database/daos/invoice_dao.dart';
import 'package:sentery_app/core/utils/money_utils.dart';
import 'package:drift/drift.dart';

class InvoiceRepository {
  final InvoiceDao _dao;
  InvoiceRepository(this._dao);

  Stream<List<Invoice>> watchAllInvoices() => _dao.watchAllInvoices();
  
  Future<Invoice?> getInvoiceById(int id) => _dao.getInvoiceById(id);

  Future<List<InvoiceItem>> getInvoiceItems(int invoiceId) => _dao.getInvoiceItems(invoiceId);

  Future<List<Payment>> getInvoicePayments(int invoiceId) => _dao.getInvoicePayments(invoiceId);

  Future<int> createInvoice({
    required InvoicesCompanion invoice,
    required List<InvoiceItemsCompanion> items,
    required List<PaymentsCompanion> initialPayments,
  }) => _dao.createInvoice(invoice: invoice, items: items, initialPayments: initialPayments);

  Future<String> generateInvoiceNumber(String type) => _dao.generateInvoiceNumber(type);
}

final invoiceDaoProvider = Provider<InvoiceDao>((ref) {
  return ref.watch(databaseProvider).invoiceDao;
});

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository(ref.watch(invoiceDaoProvider));
});

final invoicesStreamProvider = StreamProvider<List<Invoice>>((ref) {
  return ref.watch(invoiceRepositoryProvider).watchAllInvoices();
});

final invoiceByIdProvider = FutureProvider.family<Invoice?, int>((ref, id) {
  return ref.watch(invoiceRepositoryProvider).getInvoiceById(id);
});

final invoiceItemsProvider = FutureProvider.family<List<InvoiceItem>, int>((ref, id) {
  return ref.watch(invoiceRepositoryProvider).getInvoiceItems(id);
});

final invoicesByPartyProvider = FutureProvider.family<List<Invoice>, (String, int)>((ref, arg) async {
  final (type, id) = arg;
  final db = ref.watch(databaseProvider);
  if (type == 'customer') return db.customerDao.getCustomerInvoices(id);
  if (type == 'wholesaler') return db.wholesalerDao.getWholesalerInvoices(id);
  if (type == 'supplier') return db.supplierDao.getSupplierInvoices(id);
  return [];
});

// State for invoice creation
class InvoiceItemDraft {
  final int itemId;
  final String name;
  final double quantity;
  final double unitPrice; 
  final double purchasePrice;
  final String unitType;
  final double discount;
  final String note;

  InvoiceItemDraft({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.purchasePrice,
    required this.unitType,
    this.discount = 0.0,
    this.note = '',
  });

  double get total {
    return Money.fromPaisa(paisaTotal).toDouble();
  }

  int get paisaTotal {
    final mSubtotal = Money.fromDouble(unitPrice).multiplyByDouble(quantity);
    final mDiscount = Money.fromDouble(discount);
    return (mSubtotal - mDiscount).paisa;
  }

  InvoiceItemDraft copyWith({
    double? quantity,
    double? unitPrice,
    double? discount,
    String? note,
  }) {
    return InvoiceItemDraft(
      itemId: itemId,
      name: name,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      purchasePrice: purchasePrice,
      unitType: unitType,
      discount: discount ?? this.discount,
      note: note ?? this.note,
    );
  }
}

final invoiceDraftItemsProvider = StateProvider<List<InvoiceItemDraft>>((ref) => []);
