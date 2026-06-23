import 'dart:convert';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/database/daos/draft_dao.dart';
import 'package:sentery_app/core/utils/money_utils.dart';
import 'package:sentery_app/features/invoices/providers/invoice_provider.dart';
import 'package:drift/drift.dart';

class DraftService {
  final DraftDao _dao;
  DraftService(this._dao);

  Future<void> saveSaleDraft({
    required List<InvoiceItemDraft> items,
    int? partyId,
    String? partyName,
    String? partyType,
    String? tempName,
    String? buyerType,
    double manualDiscount = 0.0,
    double amountPaid = 0.0,
    String? notes,
    DateTime? invoiceDate,
  }) async {
    final payload = {
      'items': items.map((i) => _itemToMap(i)).toList(),
      'partyId': partyId,
      'tempName': tempName,
      'buyerType': buyerType,
      'manualDiscount': manualDiscount,
      'amountPaid': amountPaid,
      'notes': notes,
      'invoiceDate': (invoiceDate ?? DateTime.now()).toIso8601String(),
    };

    final mSubtotal = items.fold(Money.zero, (sum, i) => sum + Money.fromPaisa(i.paisaTotal));
    final mTotal = mSubtotal - Money.fromDouble(manualDiscount);

    await _dao.upsertDraft(DraftInvoicesCompanion.insert(
      draftType: 'sale',
      partyType: Value(partyType),
      partyId: Value(partyId),
      partyNameSnapshot: Value(partyName ?? tempName),
      payloadJson: jsonEncode(payload),
      totalPreview: Value(mTotal.paisa),
      itemCount: Value(items.length),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> savePurchaseDraft({
    required List<InvoiceItemDraft> items,
    int? supplierId,
    String? supplierName,
    String? challan,
    String? notes,
    double amountPaid = 0.0,
    DateTime? invoiceDate,
  }) async {
    final payload = {
      'items': items.map((i) => _itemToMap(i)).toList(),
      'supplierId': supplierId,
      'challan': challan,
      'notes': notes,
      'amountPaid': amountPaid,
      'invoiceDate': (invoiceDate ?? DateTime.now()).toIso8601String(),
    };

    final mTotal = items.fold(Money.zero, (sum, i) => sum + Money.fromPaisa(i.paisaTotal));

    await _dao.upsertDraft(DraftInvoicesCompanion.insert(
      draftType: 'purchase',
      partyType: const Value('supplier'),
      partyId: Value(supplierId),
      partyNameSnapshot: Value(supplierName),
      payloadJson: jsonEncode(payload),
      totalPreview: Value(mTotal.paisa),
      itemCount: Value(items.length),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> savePaymentDraft({
    required String partyType,
    required int partyId,
    String? partyName,
    int? invoiceId,
    required double amount,
    String? method,
    String? notes,
  }) async {
    final payload = {
      'partyType': partyType,
      'partyId': partyId,
      'invoiceId': invoiceId,
      'amount': amount,
      'method': method,
      'notes': notes,
    };

    final amountPaisa = Money.fromDouble(amount).paisa;

    await _dao.upsertDraft(DraftInvoicesCompanion.insert(
      draftType: 'payment',
      partyType: Value(partyType),
      partyId: Value(partyId),
      partyNameSnapshot: Value(partyName),
      payloadJson: jsonEncode(payload),
      totalPreview: Value(amountPaisa),
      itemCount: const Value(0),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<Map<String, dynamic>?> getSaleDraft() async {
    final d = await _dao.getDraftByType('sale');
    return d != null ? jsonDecode(d.payloadJson) : null;
  }

  Future<Map<String, dynamic>?> getPurchaseDraft() async {
    final d = await _dao.getDraftByType('purchase');
    return d != null ? jsonDecode(d.payloadJson) : null;
  }
  
  Future<Map<String, dynamic>?> getPaymentDraft() async {
    final d = await _dao.getDraftByType('payment');
    return d != null ? jsonDecode(d.payloadJson) : null;
  }

  Future<void> clearSaleDraft() => _dao.deleteDraftByType('sale');
  Future<void> clearPurchaseDraft() => _dao.deleteDraftByType('purchase');
  Future<void> clearPaymentDraft() => _dao.deleteDraftByType('payment');

  Stream<List<DraftInvoice>> watchDrafts() => _dao.watchAllDrafts();

  Map<String, dynamic> _itemToMap(InvoiceItemDraft i) => {
    'itemId': i.itemId,
    'name': i.name,
    'quantity': i.quantity,
    'unitPrice': i.unitPrice,
    'purchasePrice': i.purchasePrice,
    'unitType': i.unitType,
    'discount': i.discount,
    'note': i.note,
  };

  InvoiceItemDraft itemFromMap(Map<String, dynamic> m) => InvoiceItemDraft(
    itemId: m['itemId'],
    name: m['name'],
    quantity: (m['quantity'] as num).toDouble(),
    unitPrice: (m['unitPrice'] as num).toDouble(),
    purchasePrice: (m['purchasePrice'] as num).toDouble(),
    unitType: m['unitType'],
    discount: (m['discount'] as num).toDouble(),
    note: m['note'] ?? '',
  );
}
