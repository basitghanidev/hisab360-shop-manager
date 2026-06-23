import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_strings.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/core/utils/money_utils.dart';
import 'package:sentery_app/features/invoices/providers/invoice_provider.dart';
import 'package:sentery_app/features/items/providers/item_provider.dart';
import 'package:sentery_app/features/suppliers/providers/supplier_provider.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';
import 'package:drift/drift.dart' as drift;
import 'package:sentery_app/core/services/invoice_pdf_service.dart';
import 'package:sentery_app/core/database/database_provider.dart';
import 'package:sentery_app/features/invoices/widgets/add_item_to_invoice_sheet.dart';
import 'package:sentery_app/core/widgets/searchable_party_picker.dart';
import 'package:intl/intl.dart';

class PurchaseInvoiceScreen extends ConsumerStatefulWidget {
  const PurchaseInvoiceScreen({super.key});

  @override
  ConsumerState<PurchaseInvoiceScreen> createState() => _PurchaseInvoiceScreenState();
}

class _PurchaseInvoiceScreenState extends ConsumerState<PurchaseInvoiceScreen> {
  int? _selectedSupplierId;
  Money _previousBalance = Money.zero;
  final _amountPaidController = TextEditingController(text: '0');
  final _supplierChallanController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _invoiceDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForDraft());
  }

  Future<void> _checkForDraft() async {
    final draft = await ref.read(draftServiceProvider).getPurchaseDraft();
    if (draft == null || !mounted) return;

    final timestamp = DateTime.parse(draft['timestamp']);
    final timeStr = DateFormat('hh:mm a').format(timestamp);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Draft?'),
        content: Text('Found an unsaved purchase from $timeStr. Would you like to restore it?'),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(draftServiceProvider).clearPurchaseDraft();
              Navigator.pop(context);
            },
            child: const Text('Discard', style: TextStyle(color: AppColors.danger)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedSupplierId = draft['supplierId'];
                _supplierChallanController.text = draft['challan'] ?? '';
                _notesController.text = draft['notes'] ?? '';
                _amountPaidController.text = (draft['amountPaid'] ?? 0.0).toStringAsFixed(0);
                if (draft['invoiceDate'] != null) _invoiceDate = DateTime.parse(draft['invoiceDate']);
              });
              
              final items = (draft['items'] as List)
                  .map((i) => ref.read(draftServiceProvider).itemFromMap(i as Map<String, dynamic>))
                  .toList();
              ref.read(invoiceDraftItemsProvider.notifier).state = items;
              
              Navigator.pop(context);
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _saveDraft() {
    ref.read(draftServiceProvider).savePurchaseDraft(
      items: ref.read(invoiceDraftItemsProvider),
      supplierId: _selectedSupplierId,
      challan: _supplierChallanController.text,
      notes: _notesController.text,
      amountPaid: double.tryParse(_amountPaidController.text) ?? 0.0,
      invoiceDate: _invoiceDate,
    );
  }

  @override
  void dispose() {
    _amountPaidController.dispose();
    _supplierChallanController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(invoiceDraftItemsProvider, (prev, next) {
      if (next != prev) _saveDraft();
    });

    final draftItems = ref.watch(invoiceDraftItemsProvider);
    final mSubtotal = draftItems.fold(Money.zero, (sum, item) => sum + Money.fromDouble(item.total));
    final mTotal = mSubtotal; 
    final mAmountPaid = Money.fromString(_amountPaidController.text);
    final mTotalBaqi = _previousBalance + mTotal - mAmountPaid;

    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(
          english: 'Purchase Invoice',
          urdu: 'Maal Khareedna',
          englishStyle: AppTextStyles.navTitle,
        ),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSupplierSelection(),
                  const SizedBox(height: 16),
                  _buildDateSelector(),
                  const SizedBox(height: 16),
                  _buildItemEntryHeader(),
                  const Divider(),
                  ...draftItems.map((item) => _buildDraftItemRow(item, ref)),
                  if (draftItems.isEmpty)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No items added (Maal Shamil Karein)'),
                    )),
                  const SizedBox(height: 24),
                  _buildBalanceSummary(mTotal, mAmountPaid, mTotalBaqi),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          _buildBottomAction(mTotal, mAmountPaid, mTotalBaqi),
        ],
      ),
    );
  }

  Widget _buildSupplierSelection() {
    final suppliersAsync = ref.watch(suppliersStreamProvider);
    return AppCard(
      child: Column(
        children: [
          suppliersAsync.when(
            data: (list) => AppCard(
              onTap: () async {
                final picked = await showPartyPicker(
                  context,
                  title: 'Select Supplier',
                  items: list.map((s) => PartyPickerItem(
                    id: s.id, name: s.name,
                    subtitle: 'Balance: ${CurrencyFormatter.formatPaisa(s.currentBalance.abs())}',
                  )).toList(),
                );
                if (picked != null) {
                  final s = list.firstWhere((e) => e.id == picked);
                  setState(() {
                    _selectedSupplierId = picked;
                    _previousBalance = Money.fromPaisa(s.currentBalance);
                  });
                  _saveDraft();
                }
              },
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedSupplierId != null
                          ? list.firstWhere((s) => s.id == _selectedSupplierId).name
                          : 'Select Supplier (Saplair)',
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, s) => Text('Error: $e'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _supplierChallanController,
            onChanged: (_) => _saveDraft(),
            decoration: const InputDecoration(labelText: 'Supplier Bill # (Optional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 2,
            onChanged: (_) => _saveDraft(),
            decoration: const InputDecoration(
              labelText: 'Purchase Notes (Optional)', 
              hintText: 'Koi khas detail likhein',
              border: OutlineInputBorder()
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    final formatted = DateFormat('dd MMM yyyy').format(_invoiceDate);
    return AppCard(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _invoiceDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          helpText: 'Invoice Date Chunein',
        );
        if (picked != null) setState(() => _invoiceDate = picked);
      },
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, color: AppColors.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text('Invoice Date: $formatted', style: AppTextStyles.body)),
          const Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildBalanceSummary(Money mTotal, Money mAmountPaid, Money mTotalBaqi) {
    return AppCard(
      color: AppColors.accent.withOpacity(0.05),
      child: Column(
        children: [
          _summaryRow(AppStrings.previousBalance, _previousBalance, AppStrings.previousBalanceRoman),
          _summaryRow(AppStrings.newBill, mTotal, AppStrings.newBillRoman),
          _summaryRow(AppStrings.paidToday, mAmountPaid, AppStrings.paidTodayRoman, isInput: true),
          const Divider(),
          _summaryRow(AppStrings.totalRemaining, mTotalBaqi, AppStrings.totalRemainingRoman, isBold: true, color: mTotalBaqi.paisa > 0 ? AppColors.danger : AppColors.success),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, Money val, String roman, {bool isInput = false, bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          BilingualLabel(english: label, urdu: roman, englishStyle: isBold ? AppTextStyles.body.copyWith(fontWeight: FontWeight.bold) : AppTextStyles.caption),
          if (isInput)
            SizedBox(
              width: 100,
              child: TextField(
                controller: _amountPaidController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.end,
                onChanged: (v) => setState(() {}),
                style: const TextStyle(fontWeight: FontWeight.bold),
                decoration: const InputDecoration(isDense: true, prefixText: 'Rs.'),
              ),
            )
          else
            Text(CurrencyFormatter.formatPaisa(val.paisa), style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color, fontSize: isBold ? 18 : 14)),
        ],
      ),
    );
  }

  Widget _buildItemEntryHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const BilingualLabel(english: 'Items', urdu: 'Maal Shamil Karein', englishStyle: AppTextStyles.cardTitle),
        TextButton.icon(
          onPressed: _showAddItemSheet,
          icon: const Icon(Icons.add_circle),
          label: const Text('Add Item'),
        ),
      ],
    );
  }

  Widget _buildDraftItemRow(InvoiceItemDraft item, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                    Text('${item.quantity} ${item.unitType} x ${CurrencyFormatter.format(item.unitPrice)}', style: AppTextStyles.caption),
                  ],
                ),
              ),
              Text(CurrencyFormatter.format(item.total), style: AppTextStyles.body.copyWith(color: AppColors.accent)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: AppColors.accent, size: 20),
                onPressed: () => _showItemExtras(item),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger, size: 20),
                onPressed: () {
                  final list = [...ref.read(invoiceDraftItemsProvider)];
                  list.remove(item);
                  ref.read(invoiceDraftItemsProvider.notifier).state = list;
                },
              ),
            ],
          ),
          if (item.discount > 0 || (item.note?.isNotEmpty ?? false)) ...[
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (item.discount > 0) Text('Riayat: ${CurrencyFormatter.format(item.discount)}', style: const TextStyle(fontSize: 10, color: AppColors.success)),
                if (item.note?.isNotEmpty ?? false) Expanded(child: Text('Note: ${item.note}', style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic), textAlign: TextAlign.right)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showItemExtras(InvoiceItemDraft item) {
    final discountController = TextEditingController(text: item.discount.toString());
    final noteController = TextEditingController(text: item.note);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Extras for ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: discountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Discount Amount (Riayat)')),
            TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Item Note (Bil Note)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final updated = item.copyWith(
                discount: double.tryParse(discountController.text) ?? 0.0,
                note: noteController.text,
              );
              final list = [...ref.read(invoiceDraftItemsProvider)];
              final idx = list.indexOf(item);
              list[idx] = updated;
              ref.read(invoiceDraftItemsProvider.notifier).state = list;
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(Money mTotal, Money mAmountPaid, Money mTotalBaqi) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: (mTotal.paisa <= 0 || _isLoading || _selectedSupplierId == null) ? null : () => _saveInvoice(mTotal, mAmountPaid, mTotalBaqi),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text(_isLoading ? 'Saving...' : 'Save & Preview Bill', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  void _showAddItemSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddItemToInvoiceSheet(isPurchase: true),
    );
  }

  Future<void> _saveInvoice(Money mTotal, Money mAmountPaid, Money mTotalBaqi) async {
    final draftItems = ref.read(invoiceDraftItemsProvider);
    if (draftItems.isEmpty || _selectedSupplierId == null) return;

    setState(() => _isLoading = true);

    try {
      final supplier = await ref.read(supplierRepositoryProvider).getSupplierById(_selectedSupplierId!);
      final partyName = supplier?.name ?? 'Supplier';

      final invoice = InvoicesCompanion.insert(
        invoiceNumber: '', 
        invoiceType: 'purchase',
        supplierId: drift.Value(_selectedSupplierId),
        
        previousBalance: drift.Value(_previousBalance.paisa),
        totalBalanceAfter: drift.Value(mTotalBaqi.paisa),
        partyNameSnapshot: drift.Value(partyName),
        partyTypeSnapshot: const drift.Value('supplier'),

        notes: drift.Value(_notesController.text.isEmpty ? null : _notesController.text),
        subtotal: drift.Value(draftItems.fold(0, (sum, item) => sum + Money.fromDouble(item.unitPrice).multiplyByDouble(item.quantity).paisa)),
        discountAmount: drift.Value(draftItems.fold(0, (sum, item) => sum + Money.fromDouble(item.discount).paisa)),
        totalAmount: drift.Value(mTotal.paisa),
        amountPaid: drift.Value(mAmountPaid.paisa),
        amountRemaining: drift.Value((mTotal - mAmountPaid).paisa), 
        invoiceDate: drift.Value(_invoiceDate),
        status: drift.Value(mTotalBaqi.paisa <= _previousBalance.paisa ? 'paid' : (mAmountPaid.paisa > 0 ? 'partial' : 'pending')),
      );

      final items = draftItems.map((d) => InvoiceItemsCompanion.insert(
        invoiceId: 0,
        itemId: d.itemId,
        itemNameSnapshot: d.name,
        quantity: drift.Value(d.quantity),
        unitTypeSnapshot: d.unitType,
        salePrice: drift.Value(Money.fromDouble(d.unitPrice).paisa), 
        costPriceAtSale: drift.Value(Money.fromDouble(d.unitPrice).paisa), 
        lineTotal: drift.Value(d.paisaTotal),
        lineProfit: const drift.Value(0),
        discountAmount: drift.Value(Money.fromDouble(d.discount).paisa),
        itemNote: drift.Value(d.note),
      )).toList();

      final payments = mAmountPaid.paisa > 0 ? [
        PaymentsCompanion.insert(invoiceId: const drift.Value(null), paymentMethod: 'cash', amount: drift.Value(mAmountPaid.paisa))
      ] : <PaymentsCompanion>[];

      final id = await ref.read(invoiceRepositoryProvider).createInvoice(
        invoice: invoice,
        items: items,
        initialPayments: payments,
      );

      ref.read(invoiceDraftItemsProvider.notifier).state = [];
      await ref.read(draftServiceProvider).clearPurchaseDraft();
      
      if (mounted) {
        await InvoicePdfService(ref.read(databaseProvider)).previewInvoice(id);
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
