import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_strings.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/core/utils/money_utils.dart';
import 'package:sentery_app/core/widgets/searchable_item_picker.dart';
import 'package:sentery_app/core/utils/balance_label_helper.dart';
import 'package:sentery_app/features/invoices/providers/invoice_provider.dart';
import 'package:sentery_app/features/items/providers/item_provider.dart';
import 'package:sentery_app/features/wholesalers/providers/wholesaler_provider.dart';

class AddItemToInvoiceSheet extends ConsumerStatefulWidget {
  final bool isPurchase;
  final bool isWholesale;
  final int? wholesalerId; 

  const AddItemToInvoiceSheet({
    super.key,
    required this.isPurchase,
    this.isWholesale = false,
    this.wholesalerId,
  });

  @override
  ConsumerState<AddItemToInvoiceSheet> createState() => _AddItemToInvoiceSheetState();
}

class _AddItemToInvoiceSheetState extends ConsumerState<AddItemToInvoiceSheet> {
  Item? _selectedItem;
  String? _selectedUnitType;
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  List<WholesalerItemPrice> _customPrices = [];
  List<String> _priceHistory = []; 

  @override
  void initState() {
    super.initState();
    if (widget.isWholesale && widget.wholesalerId != null) {
      _loadCustomPrices();
    }
  }

  Future<void> _loadCustomPrices() async {
    final prices = await ref.read(wholesalerRepositoryProvider).getCustomPrices(widget.wholesalerId!);
    if (mounted) setState(() => _customPrices = prices);
  }

  Future<void> _onItemSelected(Item item) async {
    int pricePaisa;
    _priceHistory = [];

    if (widget.isPurchase) {
      pricePaisa = item.purchasePrice;
    } else if (widget.isWholesale) {
      final customPrice = firstWhereOrNull(_customPrices, (p) => p.itemId == item.id);
      if (customPrice != null) {
        pricePaisa = customPrice.customPrice;
        _priceHistory = ['Custom price set: ${CurrencyFormatter.formatPaisa(pricePaisa)}', 'Default: ${CurrencyFormatter.formatPaisa(item.defaultResellerPrice)}'];
      } else {
        pricePaisa = item.defaultResellerPrice;
        _priceHistory = ['Using default reseller price'];
      }
    } else {
      pricePaisa = item.retailPrice;
    }

    final unitTypesMap = await ref.read(unitTypesMapProvider.future);
    final unitName = unitTypesMap[item.unitTypeId] ?? 'Pc';

    setState(() {
      _selectedItem = item;
      _selectedUnitType = unitName;
      _priceController.text = Money.fromPaisa(pricePaisa).toDouble().toStringAsFixed(0);
    });
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),

              Text(
                widget.isPurchase ? 'Add Purchase Item' : (widget.isWholesale ? 'Add Wholesale Item' : 'Add Sale Item'),
                style: AppTextStyles.cardTitle,
              ),
              const SizedBox(height: 16),

              GestureDetector(
                onTap: () async {
                  final picked = await showItemPicker(
                    context, ref,
                    mode: widget.isPurchase
                        ? ItemPickerMode.purchase
                        : (widget.isWholesale ? ItemPickerMode.wholesale : ItemPickerMode.retail),
                    wholesalerCustomPrices: widget.isWholesale
                        ? {for (final p in _customPrices) p.itemId: Money.fromPaisa(p.customPrice).toDouble()}
                        : null,
                  );
                  if (picked != null) _onItemSelected(picked);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: _selectedItem != null ? AppColors.primary : AppColors.border),
                    borderRadius: BorderRadius.circular(10),
                    color: _selectedItem != null ? AppColors.primary.withOpacity(0.05) : null,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: _selectedItem != null ? AppColors.primary : AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedItem?.name ?? AppStrings.selectItem,
                          style: TextStyle(
                            color: _selectedItem != null ? AppColors.textPrimary : AppColors.textSecondary,
                            fontWeight: _selectedItem != null ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (_selectedItem != null)
                        const Icon(Icons.swap_horiz, size: 18, color: AppColors.primary),
                    ],
                  ),
                ),
              ),

              if (_selectedItem != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Stock: ${_selectedItem!.currentStock}',
                              style: AppTextStyles.caption.copyWith(
                                color: _selectedItem!.currentStock <= _selectedItem!.lowStockLimit
                                    ? AppColors.danger : AppColors.success,
                                fontWeight: FontWeight.bold,
                              )),
                          if (widget.isPurchase)
                            Text('Purchase: ${CurrencyFormatter.formatPaisa(_selectedItem!.purchasePrice)}',
                                style: AppTextStyles.caption),
                        ],
                      ),
                      if (_priceHistory.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        ...(_priceHistory.map((h) => Text('📌 $h',
                            style: AppTextStyles.caption.copyWith(color: AppColors.primary)))),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: AppStrings.quantity,
                        suffixText: _selectedUnitType ?? '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                        hintText: 'Kitni tadaad',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: widget.isWholesale ? 'Wholesale Price' : (widget.isPurchase ? 'Purchase Price' : 'Retail Price'),
                        prefixText: 'Rs. ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                        hintText: 'Qeemat',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_selectedItem != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Stock Available:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      Text('${_selectedItem!.currentStock} ${_selectedUnitType ?? ""}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: _selectedItem!.currentStock <= 0 ? AppColors.danger : AppColors.success)),
                    ],
                  ),
                ),

              if (_selectedItem != null) ...[
                const SizedBox(height: 10),
                Builder(builder: (context) {
                  final qty = double.tryParse(_qtyController.text) ?? 0;
                  final price = double.tryParse(_priceController.text) ?? 0;
                  final total = qty * price;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Line Total:', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(CurrencyFormatter.format(total),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16)),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selectedItem == null ? null : _addToInvoice,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(AppStrings.addToInvoice, style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(AppStrings.addToInvoiceRoman, style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _addToInvoice() {
    if (_selectedItem == null) return;
    final qty = double.tryParse(_qtyController.text) ?? 1.0;
    final price = double.tryParse(_priceController.text) ?? 0.0;

    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantity must be greater than 0')));
      return;
    }
    
    // Prevent adding item if stock is zero or insufficient (only for sales)
    if (!widget.isPurchase) {
      if (_selectedItem!.currentStock <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Stock khatam hai (Out of Stock). Cannot add to bill.'),
          backgroundColor: AppColors.danger,
        ));
        return;
      }
      if (qty > _selectedItem!.currentStock) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Tadaad maujooda maal se zyada hai. Only ${_selectedItem!.currentStock} available.'),
          backgroundColor: AppColors.danger,
        ));
        return;
      }
    }

    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Price must be greater than 0')));
      return;
    }

    final draft = InvoiceItemDraft(
      itemId: _selectedItem!.id,
      name: _selectedItem!.name,
      quantity: qty,
      unitPrice: price,
      purchasePrice: Money.fromPaisa(_selectedItem!.averageCost > 0 ? _selectedItem!.averageCost : _selectedItem!.purchasePrice).toDouble(),
      unitType: _selectedUnitType ?? 'Pc',
    );
    final list = [...ref.read(invoiceDraftItemsProvider)];
    list.add(draft);
    ref.read(invoiceDraftItemsProvider.notifier).state = list;
    Navigator.pop(context);
  }
}
