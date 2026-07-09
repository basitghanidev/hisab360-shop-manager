import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/core/utils/money_utils.dart';
import 'package:sentery_app/features/dashboard/providers/dashboard_provider.dart';
import 'package:sentery_app/features/reports/providers/report_provider.dart';
import 'package:sentery_app/features/returns/providers/return_provider.dart';
import 'package:sentery_app/features/items/providers/item_provider.dart';
import 'package:sentery_app/features/suppliers/providers/supplier_provider.dart';
import 'package:sentery_app/features/wholesalers/providers/wholesaler_provider.dart';
import 'package:sentery_app/features/customers/providers/customer_provider.dart';
import 'package:sentery_app/features/invoices/providers/invoice_provider.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';
import 'package:drift/drift.dart' as drift;

class CreateReturnScreen extends ConsumerStatefulWidget {
  const CreateReturnScreen({super.key});

  @override
  ConsumerState<CreateReturnScreen> createState() => _CreateReturnScreenState();
}

class _CreateReturnScreenState extends ConsumerState<CreateReturnScreen> {
  String _returnType = 'return_wholesaler'; 
  int? _selectedSupplierId;
  int? _selectedWholesalerId;
  int? _selectedCustomerId;
  int? _selectedInvoiceId;
  final _amountPaidController = TextEditingController(text: '0');
  String _paymentMethod = 'cash';
  
  final List<ReturnItemDraft> _returnItems = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _amountPaidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mTotal = _returnItems.fold(Money.zero, (sum, item) => sum + Money.fromDouble(item.quantity * item.price));

    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(
          english: 'Create Return',
          urdu: 'Maal Wapsi',
          englishStyle: AppTextStyles.navTitle,
        ),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTypeSelection(),
                  const SizedBox(height: 16),
                  _buildPartySelection(),
                  const SizedBox(height: 16),
                  _buildItemEntrySection(),
                  const Divider(),
                  ..._returnItems.asMap().entries.map((entry) => _buildReturnItemRow(entry.key, entry.value)),
                  if (_returnItems.isEmpty)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No items added for return'),
                    )),
                  
                  if (_returnItems.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildRefundSection(mTotal),
                  ],
                ],
              ),
            ),
          ),
          _buildBottomAction(mTotal),
        ],
      ),
    );
  }

  Widget _buildTypeSelection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BilingualLabel(english: 'Return Type', urdu: 'Wapsi Ki Qism', englishStyle: AppTextStyles.body),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _returnType,
            items: const [
              DropdownMenuItem(value: 'return_supplier', child: Text('Return to Supplier (Saudagar)')),
              DropdownMenuItem(value: 'return_wholesaler', child: Text('Return from Wholesaler (Thok)')),
              DropdownMenuItem(value: 'return_customer', child: Text('Return from Customer (Grahak)')),
            ],
            onChanged: (v) => setState(() {
              _returnType = v!;
              _selectedSupplierId = null;
              _selectedWholesalerId = null;
              _selectedCustomerId = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPartySelection() {
    Widget partyDropdown;
    int? currentPartyId;

    if (_returnType == 'return_supplier') {
      final suppliers = ref.watch(suppliersStreamProvider);
      currentPartyId = _selectedSupplierId;
      partyDropdown = suppliers.when(
        data: (list) => _buildPartyDropdown(list, _selectedSupplierId, (v) => setState(() { _selectedSupplierId = v; _selectedInvoiceId = null; }), 'Supplier'),
        loading: () => const LinearProgressIndicator(),
        error: (e, s) => Text('Error: $e'),
      );
    } else if (_returnType == 'return_wholesaler') {
      final wholesalers = ref.watch(wholesalersStreamProvider);
      currentPartyId = _selectedWholesalerId;
      partyDropdown = wholesalers.when(
        data: (list) => _buildPartyDropdown(list, _selectedWholesalerId, (v) => setState(() { _selectedWholesalerId = v; _selectedInvoiceId = null; }), 'Wholesaler'),
        loading: () => const LinearProgressIndicator(),
        error: (e, s) => Text('Error: $e'),
      );
    } else {
      final customers = ref.watch(customersStreamProvider);
      currentPartyId = _selectedCustomerId;
      partyDropdown = customers.when(
        data: (list) => _buildPartyDropdown(list, _selectedCustomerId, (v) => setState(() { _selectedCustomerId = v; _selectedInvoiceId = null; }), 'Customer'),
        loading: () => const LinearProgressIndicator(),
        error: (e, s) => Text('Error: $e'),
      );
    }

    return Column(
      children: [
        partyDropdown,
        if (currentPartyId != null) ...[
          const SizedBox(height: 12),
          _buildInvoiceSelector(currentPartyId),
        ],
      ],
    );
  }

  Widget _buildInvoiceSelector(int partyId) {
    final partyType = _returnType == 'return_supplier' ? 'supplier' : (_returnType == 'return_wholesaler' ? 'wholesaler' : 'customer');
    final invoicesAsync = ref.watch(invoicesByPartyProvider((partyType, partyId)));

    return invoicesAsync.when(
      data: (list) {
        // Defensive fix: Ensure selected invoice still exists in the list.
        if (_selectedInvoiceId != null && !list.any((i) => i.id == _selectedInvoiceId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedInvoiceId = null);
          });
        }
        
        final bool selectedIsValid = _selectedInvoiceId != null && list.any((i) => i.id == _selectedInvoiceId);
        final int? effectiveId = selectedIsValid ? _selectedInvoiceId : null;

        return AppCard(
          child: DropdownButtonFormField<int>(
            value: effectiveId,
            isExpanded: true,
            hint: const Text('Link to Original Bill (Optional)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('No Bill Link')),
              ...list.map((i) => DropdownMenuItem(value: i.id, child: Text(i.invoiceNumber))),
            ],
            onChanged: (v) => setState(() => _selectedInvoiceId = v),
            decoration: const InputDecoration(labelText: 'Billed As (Pichla Bill)', border: InputBorder.none),
          ),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error loading bills: $e'),
    );
  }

  Widget _buildPartyDropdown(List list, int? value, Function(int?) onChanged, String label) {
    return AppCard(
      child: DropdownButtonFormField<int>(
        value: value,
        isExpanded: true,
        items: list.map<DropdownMenuItem<int>>((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(labelText: 'Select $label (Banday ka naam dhoondein)'),
      ),
    );
  }

  Widget _buildItemEntrySection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const BilingualLabel(english: 'Items', urdu: 'Maal', englishStyle: AppTextStyles.cardTitle),
        TextButton.icon(
          onPressed: _showAddItemSheet,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Add Item'),
        ),
      ],
    );
  }

  Widget _buildReturnItemRow(int index, ReturnItemDraft item) {
    return ListTile(
      title: Text(item.name),
      subtitle: Text('${item.quantity} x ${CurrencyFormatter.format(item.price)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(CurrencyFormatter.format(item.quantity * item.price), style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
            onPressed: () => setState(() => _returnItems.removeAt(index)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(Money mTotal) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: (mTotal.paisa <= 0 || _isLoading) ? null : () => _saveReturn(mTotal),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(_isLoading ? 'Processing...' : 'Save Return (${CurrencyFormatter.formatPaisa(mTotal.paisa)})', 
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  void _showAddItemSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddReturnItemSheet(
        isSupplier: _returnType == 'return_supplier',
        onAdd: (item) {
          setState(() => _returnItems.add(item));
        }
      ),
    );
  }

  Widget _buildRefundSection(Money mTotal) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BilingualLabel(
            english: 'Refund Amount', 
            urdu: 'Wapsi Ki Raqam', 
            englishStyle: AppTextStyles.cardTitle
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountPaidController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _returnType == 'return_supplier' ? 'Cash Received Today' : 'Cash Paid Today',
              prefixText: 'Rs. ',
              border: const OutlineInputBorder(),
              helperText: 'Enter amount paid/received at time of return.',
            ),
            onChanged: (v) => setState(() {}),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _paymentMethod,
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Cash (Naqad)')),
              DropdownMenuItem(value: 'online', child: Text('Online (Digital)')),
            ],
            onChanged: (v) => setState(() => _paymentMethod = v!),
            decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Builder(builder: (ctx) {
            final paid = double.tryParse(_amountPaidController.text) ?? 0;
            final total = mTotal.toDouble();
            final remaining = total - paid;
            
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(remaining > 0 
                    ? (_returnType == 'return_supplier' ? 'Balance to Receive:' : 'Balance to Pay:')
                    : 'Settled:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(CurrencyFormatter.format(remaining.abs()), 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      color: remaining > 0 ? AppColors.danger : AppColors.success,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _saveReturn(Money mTotal) async {
    if (_returnType == 'return_supplier' && _selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select supplier'))); return;
    }
    if (_returnType == 'return_wholesaler' && _selectedWholesalerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select wholesaler'))); return;
    }
    if (_returnType == 'return_customer' && _selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select customer'))); return;
    }

    setState(() => _isLoading = true);

    final amountPaidToday = Money.fromDouble(double.tryParse(_amountPaidController.text) ?? 0).paisa;

    final returnInvoice = InvoicesCompanion.insert(
      invoiceNumber: '', 
      invoiceType: _returnType,
      supplierId: drift.Value(_selectedSupplierId),
      wholesalerId: drift.Value(_selectedWholesalerId),
      customerId: drift.Value(_selectedCustomerId),
      originalInvoiceId: drift.Value(_selectedInvoiceId),
      totalAmount: drift.Value(mTotal.paisa),
      subtotal: drift.Value(mTotal.paisa),
      amountPaid: drift.Value(amountPaidToday),
      amountRemaining: drift.Value(mTotal.paisa - amountPaidToday),
      status: drift.Value(amountPaidToday >= mTotal.paisa ? 'paid' : 'returned'),
    );
    
    // ...
    final returnedItems = _returnItems.map((d) => InvoiceItemsCompanion.insert(
      invoiceId: 0,
      itemId: d.itemId,
      itemNameSnapshot: d.name,
      quantity: drift.Value(d.quantity),
      unitTypeSnapshot: 'Piece',
      salePrice: drift.Value(Money.fromDouble(d.price).paisa),
      costPriceAtSale: drift.Value(Money.fromDouble(d.costPrice).paisa),
      lineTotal: drift.Value(Money.fromDouble(d.quantity * d.price).paisa),
      lineProfit: const drift.Value(0),
    )).toList();

    await ref.read(returnRepositoryProvider).createReturnInvoice(
      returnInvoice: returnInvoice,
      returnedItems: returnedItems,
      amountPaidToday: amountPaidToday,
      paymentMethod: _paymentMethod,
    );

    // After successful save, invalidate dashboard and low stock so it reflects new data immediately.
    ref.invalidate(dashboardProvider);
    ref.invalidate(lowStockItemsProvider);

    if (mounted) {
      context.pop();
    }
  }
}

class ReturnItemDraft {
  final int itemId;
  final String name;
  final double quantity;
  final double price;
  final double costPrice;
  ReturnItemDraft(this.itemId, this.name, this.quantity, this.price, this.costPrice);
}

class AddReturnItemSheet extends ConsumerStatefulWidget {
  final bool isSupplier;
  final Function(ReturnItemDraft) onAdd;
  const AddReturnItemSheet({super.key, required this.isSupplier, required this.onAdd});

  @override
  ConsumerState<AddReturnItemSheet> createState() => _AddReturnItemSheetState();
}

class _AddReturnItemSheetState extends ConsumerState<AddReturnItemSheet> {
  Item? _selectedItem;
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(itemsStreamProvider);

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BilingualLabel(english: 'Select Item to Return', urdu: 'Wapsi Valay Maal Ka Naam', englishStyle: AppTextStyles.cardTitle),
            const SizedBox(height: 16),
            items.when(
              data: (list) => DropdownButtonFormField<Item>(
                value: _selectedItem,
                isExpanded: true,
                items: list.map((i) => DropdownMenuItem(value: i, child: Text(i.name, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() {
                  _selectedItem = v;
                  _priceController.text = Money.fromPaisa(widget.isSupplier ? v!.purchasePrice : v!.retailPrice).toDouble().toString();
                }),
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, s) => Text('Error: $e'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextField(controller: _qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity (Tadaad)'))),
                const SizedBox(width: 16),
                Expanded(child: TextField(controller: _priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (Qeemat)', prefixText: 'Rs.'))),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (_selectedItem != null) {
                  final qty = double.tryParse(_qtyController.text) ?? 1.0;
                  
                  // If returning TO supplier, ensure we have enough stock to give back
                  if (widget.isSupplier && qty > _selectedItem!.currentStock) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Tadaad maujooda maal se zyada hai. Only ${_selectedItem!.currentStock} available.'),
                      backgroundColor: AppColors.danger,
                    ));
                    return;
                  }

                  widget.onAdd(ReturnItemDraft(
                    _selectedItem!.id, 
                    _selectedItem!.name, 
                    qty,
                    double.tryParse(_priceController.text) ?? 0.0,
                    Money.fromPaisa(_selectedItem!.averageCost).toDouble(),
                  ));
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
              child: const Text('Add to List'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
