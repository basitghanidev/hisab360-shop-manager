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
import 'package:sentery_app/core/database/daos/item_dao.dart';
import 'package:sentery_app/features/dashboard/providers/dashboard_provider.dart';
import 'package:sentery_app/features/customers/providers/customer_provider.dart';
import 'package:sentery_app/features/wholesalers/providers/wholesaler_provider.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';
import 'package:drift/drift.dart' as drift;
import 'package:sentery_app/core/services/invoice_pdf_service.dart';
import 'package:sentery_app/core/database/database_provider.dart';
import 'package:sentery_app/features/invoices/widgets/add_item_to_invoice_sheet.dart';
import 'package:sentery_app/core/widgets/searchable_party_picker.dart';
import 'package:intl/intl.dart';

class SaleInvoiceScreen extends ConsumerStatefulWidget {
  const SaleInvoiceScreen({super.key});

  @override
  ConsumerState<SaleInvoiceScreen> createState() => _SaleInvoiceScreenState();
}

class _SaleInvoiceScreenState extends ConsumerState<SaleInvoiceScreen> {
  String _buyerType = 'sale_retail'; 
  int? _selectedPartyId;
  String? _tempCustomerName;
  bool _isNewCustomer = false;
  
  Money _previousBalance = Money.zero;
  final _amountPaidController = TextEditingController();
  final _manualDiscountController = TextEditingController();
  final _notesController = TextEditingController();
  bool _showManualDiscount = false;
  DateTime _invoiceDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForDraft());
  }

  Future<void> _checkForDraft() async {
    final draft = await ref.read(draftServiceProvider).getSaleDraft();
    if (draft == null || !mounted) return;

    final timestamp = DateTime.parse(draft['timestamp']);
    final timeStr = DateFormat('hh:mm a').format(timestamp);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Draft?'),
        content: Text('Found an unsaved bill from $timeStr. Would you like to restore it?'),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(draftServiceProvider).clearSaleDraft();
              Navigator.pop(context);
            },
            child: const Text('Discard', style: TextStyle(color: AppColors.danger)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _buyerType = draft['buyerType'] ?? 'sale_retail';
                _selectedPartyId = draft['partyId'];
                _tempCustomerName = draft['tempName'];
                _manualDiscountController.text = (draft['manualDiscount'] ?? 0.0).toStringAsFixed(0);
                _amountPaidController.text = (draft['amountPaid'] ?? 0.0).toStringAsFixed(0);
                _notesController.text = draft['notes'] ?? '';
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
    ref.read(draftServiceProvider).saveSaleDraft(
      items: ref.read(invoiceDraftItemsProvider),
      partyId: _selectedPartyId,
      tempName: _tempCustomerName,
      buyerType: _buyerType,
      manualDiscount: double.tryParse(_manualDiscountController.text) ?? 0.0,
      notes: _notesController.text,
      amountPaid: double.tryParse(_amountPaidController.text) ?? 0.0,
      invoiceDate: _invoiceDate,
    );
  }

  @override
  void dispose() {
    _amountPaidController.dispose();
    _manualDiscountController.dispose();
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
    final mManualDiscount = Money.fromString(_manualDiscountController.text);
    final mTotal = mSubtotal - mManualDiscount;
    final mAmountPaid = Money.fromString(_amountPaidController.text);
    final mTotalBaqi = _previousBalance + mTotal - mAmountPaid;

    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(
          english: 'Sale Bill',
          urdu: AppStrings.newBillRoman,
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
                  _buildTypeSelection(),
                  const SizedBox(height: 16),
                  _buildPartySelection(),
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
                  const SizedBox(height: 16),
                  _buildNotesField(),
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

  Widget _buildTypeSelection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BilingualLabel(english: 'Bill Type', urdu: 'Bill Ki Qism', englishStyle: AppTextStyles.body),
          const SizedBox(height: 8),
          CupertinoSlidingSegmentedControl<String>(
            groupValue: _buyerType,
            children: const {
              'sale_retail': Text('Retail (Parchoon)'),
              'sale_wholesale': Text('Wholesale (Thok)'),
            },
            onValueChanged: (v) {
              setState(() {
                _buyerType = v!;
                _selectedPartyId = null;
                _previousBalance = Money.zero;
                _isNewCustomer = false;
              });
              _saveDraft();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPartySelection() {
    if (_buyerType == 'sale_wholesale') {
      final wholesalersAsync = ref.watch(wholesalersStreamProvider);
      return wholesalersAsync.when(
        data: (list) => AppCard(
          onTap: () async {
            final picked = await showPartyPicker(
              context,
              title: 'Select Wholesaler',
              items: list.map((w) => PartyPickerItem(
                id: w.id, name: w.name,
                subtitle: 'Balance: ${CurrencyFormatter.formatPaisa(w.currentBalance.abs())}',
              )).toList(),
            );
            if (picked != null) {
              final w = list.firstWhere((e) => e.id == picked);
              setState(() {
                _selectedPartyId = picked;
                _previousBalance = Money.fromPaisa(w.currentBalance);
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
                  _selectedPartyId != null
                      ? list.firstWhere((w) => w.id == _selectedPartyId).name
                      : 'Select Wholesaler (Thok Farosh)',
                ),
              ),
            ],
          ),
        ),
        loading: () => const LinearProgressIndicator(),
        error: (e, s) => Text('Error: $e'),
      );
    } else {
      return AppCard(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Walk-in'),
                    value: false,
                    groupValue: _isNewCustomer || _selectedPartyId != null,
                    onChanged: (v) => setState(() {
                      _isNewCustomer = false;
                      _selectedPartyId = null;
                      _previousBalance = Money.zero;
                      _saveDraft();
                    }),
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Saved/New'),
                    value: true,
                    groupValue: _isNewCustomer || _selectedPartyId != null,
                    onChanged: (v) => setState(() {
                      _isNewCustomer = true;
                      _saveDraft();
                    }),
                  ),
                ),
              ],
            ),
            if (_isNewCustomer || _selectedPartyId != null) ...[
              const Divider(),
              _buildCustomerSelector(),
            ],
          ],
        ),
      );
    }
  }

  Widget _buildCustomerSelector() {
    final customersAsync = ref.watch(customersStreamProvider);
    return Column(
      children: [
        customersAsync.when(
          data: (list) => AppCard(
            onTap: () async {
              final picked = await showPartyPicker(
                context,
                title: 'Select Customer',
                items: [
                  ...list.map((c) => PartyPickerItem(
                    id: c.id, name: c.name,
                    subtitle: 'Balance: ${CurrencyFormatter.formatPaisa(c.currentBalance.abs())}',
                  )),
                  const PartyPickerItem(id: -1, name: '+ Create New Profile'),
                ],
              );
              if (picked != null) {
                if (picked == -1) {
                  setState(() {
                    _selectedPartyId = null;
                    _isNewCustomer = true;
                    _previousBalance = Money.zero;
                  });
                } else {
                  final c = list.firstWhere((e) => e.id == picked);
                  setState(() {
                    _selectedPartyId = picked;
                    _isNewCustomer = false;
                    _previousBalance = Money.fromPaisa(c.currentBalance);
                  });
                }
                _saveDraft();
              }
            },
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedPartyId != null
                        ? list.firstWhere((c) => c.id == _selectedPartyId).name
                        : 'Select Customer (Grahak)',
                  ),
                ),
              ],
            ),
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, s) => Text('Error: $e'),
        ),
        if (_selectedPartyId == null) ...[
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) {
              _tempCustomerName = v;
              _saveDraft();
            },
            decoration: const InputDecoration(labelText: 'Customer Name (Naam Likhein)', border: OutlineInputBorder()),
          ),
        ],
      ],
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
          const Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text('Invoice Date: $formatted', style: AppTextStyles.body)),
          const Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildNotesField() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BilingualLabel(
            english: 'Invoice Notes', 
            urdu: 'Bill ki extra note', 
            englishStyle: AppTextStyles.body
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 2,
            onChanged: (_) => _saveDraft(),
            decoration: const InputDecoration(
              hintText: 'Payment ya delivery ki detail yahan likhein',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSummary(Money mTotal, Money mAmountPaid, Money mTotalBaqi) {
    return AppCard(
      color: AppColors.primary.withOpacity(0.05),
      child: Column(
        children: [
          _summaryRow(AppStrings.previousBalance, _previousBalance, AppStrings.previousBalanceRoman),
          _summaryRow(AppStrings.newBill, mTotal + Money.fromString(_manualDiscountController.text), AppStrings.newBillRoman),
          
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const BilingualLabel(english: 'Extra Discount', urdu: 'Mazeed Riayat', englishStyle: AppTextStyles.caption),
                    IconButton(
                      icon: Icon(_showManualDiscount ? Icons.remove_circle_outline : Icons.add_circle_outline, 
                          size: 20, color: AppColors.primary),
                      onPressed: () => setState(() => _showManualDiscount = !_showManualDiscount),
                    ),
                  ],
                ),
                if (_showManualDiscount)
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _manualDiscountController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.end,
                      onChanged: (v) {
                      setState(() {});
                      _saveDraft();
                    },
                      decoration: const InputDecoration(isDense: true, prefixText: 'Rs.', hintText: '0'),
                    ),
                  )
                else
                  Text(CurrencyFormatter.format(Money.fromString(_manualDiscountController.text).toDouble()), 
                      style: const TextStyle(color: AppColors.success)),
              ],
            ),
          ),

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
                decoration: const InputDecoration(isDense: true, prefixText: 'Rs.', hintText: '0'),
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
              Text(CurrencyFormatter.format(item.total), style: AppTextStyles.body.copyWith(color: AppColors.primary)),
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
            TextField(controller: discountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Discount (Riayat)')),
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
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: (mTotal.paisa <= 0 || _isLoading) ? null : () => _saveInvoice(mTotal, mAmountPaid, mTotalBaqi),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(_isLoading ? 'Saving...' : 'Save Bill', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddItemSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddItemToInvoiceSheet(
        isPurchase: false,
        isWholesale: _buyerType == 'sale_wholesale',
        wholesalerId: _buyerType == 'sale_wholesale' ? _selectedPartyId : null,
      ),
    );
  }

  Future<void> _saveInvoice(Money mTotal, Money mAmountPaid, Money mTotalBaqi) async {
    final draftItems = ref.read(invoiceDraftItemsProvider);
    if (draftItems.isEmpty) return;

    // A "true walk-in" has no profile selected AND no name typed.
    // If the user typed a name, they intend to create a profile — allow remaining.
    final isTrueWalkIn = _selectedPartyId == null && 
        (_tempCustomerName == null || _tempCustomerName!.trim().isEmpty);

    if (isTrueWalkIn && mAmountPaid.toDouble() < mTotal.toDouble()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Walk-in customers must pay in full.\n'
            'To allow remaining balance, enter the customer\'s name to create a profile.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.danger,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // If there is a remaining balance for a known party, show a disclaimer
    // before saving so the shop owner consciously approves giving credit.
    final hasRemaining = (mTotal - mAmountPaid).paisa > 0;
    final hasRegisteredParty = _selectedPartyId != null ||
        (_tempCustomerName != null && _tempCustomerName!.trim().isNotEmpty);

    if (hasRemaining && hasRegisteredParty) {
      final remainingStr = CurrencyFormatter.formatPaisa((mTotal - mAmountPaid).paisa);
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Confirm Credit (Udhaar)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This bill has a remaining balance:'),
              const SizedBox(height: 8),
              Text(remainingStr,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.danger)),
              const SizedBox(height: 12),
              const Text(
                'The customer owes this amount. Are you sure you want to save the bill and extend this credit?',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Yes, Save with Udhaar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _isLoading = true);

    try {
      String partyName = _tempCustomerName ?? 'Walk-in Customer';
      String partyType = 'customer';
      int? finalCustomerId = (_buyerType == 'sale_retail') ? _selectedPartyId : null;

      if (_buyerType == 'sale_retail' && _selectedPartyId == null && _tempCustomerName != null && _tempCustomerName!.isNotEmpty) {
        finalCustomerId = await ref.read(customerRepositoryProvider).addCustomer(
          CustomersCompanion.insert(name: _tempCustomerName!, isTemporary: const drift.Value(false))
        );
        final c = await ref.read(customerRepositoryProvider).getCustomerById(finalCustomerId);
        partyName = c?.name ?? partyName;
      } else if (_selectedPartyId != null) {
        if (_buyerType == 'sale_wholesale') {
          final w = await ref.read(wholesalerRepositoryProvider).getWholesalerById(_selectedPartyId!);
          partyName = w?.name ?? partyName;
          partyType = 'wholesaler';
        } else {
          final c = await ref.read(customerRepositoryProvider).getCustomerById(_selectedPartyId!);
          partyName = c?.name ?? partyName;
        }
      }

      final manualDiscountPaisa = Money.fromString(_manualDiscountController.text).paisa;

      final invoice = InvoicesCompanion.insert(
        invoiceNumber: '', 
        invoiceType: _buyerType,
        wholesalerId: drift.Value(_buyerType == 'sale_wholesale' ? _selectedPartyId : null),
        customerId: drift.Value(finalCustomerId),
        tempCustomerName: drift.Value(finalCustomerId == null ? _tempCustomerName : null),
        
        previousBalance: drift.Value(_previousBalance.paisa),
        totalBalanceAfter: drift.Value(mTotalBaqi.paisa),
        partyNameSnapshot: drift.Value(partyName),
        partyTypeSnapshot: drift.Value(partyType),
        
        subtotal: drift.Value(draftItems.fold(0, (sum, item) => sum + Money.fromDouble(item.unitPrice).multiplyByDouble(item.quantity).paisa)),
        discountAmount: drift.Value(draftItems.fold(0, (sum, item) => sum + Money.fromDouble(item.discount).paisa) + manualDiscountPaisa),
        totalAmount: drift.Value(mTotal.paisa),
        amountPaid: drift.Value(mAmountPaid.paisa),
        amountRemaining: drift.Value((mTotal - mAmountPaid).paisa), 
        invoiceDate: drift.Value(_invoiceDate),
        status: drift.Value(mTotalBaqi.paisa <= _previousBalance.paisa ? 'paid' : (mAmountPaid.paisa > 0 ? 'partial' : 'pending')),
        notes: drift.Value(_notesController.text.isEmpty ? null : _notesController.text),
      );

      final items = draftItems.map((d) => InvoiceItemsCompanion.insert(
        invoiceId: 0,
        itemId: d.itemId,
        itemNameSnapshot: d.name,
        quantity: drift.Value(d.quantity),
        unitTypeSnapshot: d.unitType,
        salePrice: drift.Value(Money.fromDouble(d.unitPrice).paisa),
        costPriceAtSale: drift.Value(Money.fromDouble(d.purchasePrice).paisa),
        lineTotal: drift.Value(d.paisaTotal),
        lineProfit: drift.Value(d.paisaTotal - Money.fromDouble(d.purchasePrice).multiplyByDouble(d.quantity).paisa),
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
      await ref.read(draftServiceProvider).clearSaleDraft();
      
      // After successful save, invalidate dashboard so it reflects new data immediately.
      ref.invalidate(dashboardProvider);

      if (mounted) {
        final result = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Bill Saved Successfully'),
            content: const Text('Would you like to print this bill now?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, 'save_only'),
                child: const Text('Save Only', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(dialogCtx, 'save_and_print'),
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Save and Print'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );

        if (mounted) {
          if (result == 'save_and_print') {
            await InvoicePdfService(ref.read(databaseProvider)).printInvoice(id);
          }
          if (mounted) {
            context.go('/home');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        if (e is InsufficientStockException) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cannot save: ${e.itemName} has only '
                '${e.available.toStringAsFixed(0)} units available.',
              ),
              backgroundColor: AppColors.danger,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
