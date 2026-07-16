import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_strings.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/money_utils.dart';
import 'package:sentery_app/features/items/providers/item_provider.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';
import 'package:drift/drift.dart' as drift;

class AddEditItemScreen extends ConsumerStatefulWidget {
  final int? id;
  const AddEditItemScreen({super.key, this.id});

  @override
  ConsumerState<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends ConsumerState<AddEditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _itemCodeController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _resellerPriceController;
  late TextEditingController _retailPriceController;
  late TextEditingController _currentStockController;
  late TextEditingController _reorderLevelController;
  late TextEditingController _descriptionController;
  
  int? _selectedCategoryId;
  int? _selectedUnitTypeId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _itemCodeController = TextEditingController();
    _purchasePriceController = TextEditingController();
    _resellerPriceController = TextEditingController();
    _retailPriceController = TextEditingController();
    _currentStockController = TextEditingController();
    _reorderLevelController = TextEditingController(text: '5');
    _descriptionController = TextEditingController();

    if (widget.id != null) {
      _loadItem();
    } else {
      _loadNextCodePreview();
    }
  }

  String? _nextCodePreview;

  Future<void> _loadNextCodePreview() async {
    final code = await ref.read(itemDaoProvider).generateNextItemCode();
    if (mounted) {
      setState(() => _nextCodePreview = code);
    }
  }

  Future<void> _loadItem() async {
    setState(() => _isLoading = true);
    final item = await ref.read(itemRepositoryProvider).getItemById(widget.id!);
    if (item != null) {
      _nameController.text = item.name;
      _itemCodeController.text = item.itemCode ?? '';
      _purchasePriceController.text = item.purchasePrice == 0 ? '' : Money.fromPaisa(item.purchasePrice).toDouble().toString();
      _resellerPriceController.text = item.defaultResellerPrice == 0 ? '' : Money.fromPaisa(item.defaultResellerPrice).toDouble().toString();
      _retailPriceController.text = item.retailPrice == 0 ? '' : Money.fromPaisa(item.retailPrice).toDouble().toString();
      _currentStockController.text = item.currentStock == 0 ? '' : item.currentStock.toString();
      _reorderLevelController.text = item.lowStockLimit == 5.0 ? '5' : item.lowStockLimit.toString();
      _descriptionController.text = item.description ?? '';
      _selectedCategoryId = item.categoryId;
      _selectedUnitTypeId = item.unitTypeId;
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _itemCodeController.dispose();
    _purchasePriceController.dispose();
    _resellerPriceController.dispose();
    _retailPriceController.dispose();
    _currentStockController.dispose();
    _reorderLevelController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUnitTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a unit type')));
      return;
    }

    setState(() => _isLoading = true);
    final repository = ref.read(itemRepositoryProvider);

    final purchasePaisa = Money.fromString(_purchasePriceController.text).paisa;
    final resellerPaisa = Money.fromString(_resellerPriceController.text).paisa;
    final retailPaisa = Money.fromString(_retailPriceController.text).paisa;
    final currentStock = double.tryParse(_currentStockController.text) ?? 0.0;
    final reorderLevel = double.tryParse(_reorderLevelController.text) ?? 0.0;

    if (widget.id == null) {
      await repository.addItem(ItemsCompanion.insert(
        name: _nameController.text,
        itemCode: drift.Value(_itemCodeController.text.isEmpty ? null : _itemCodeController.text),
        categoryId: drift.Value(_selectedCategoryId),
        unitTypeId: _selectedUnitTypeId!,
        purchasePrice: drift.Value(purchasePaisa),
        defaultResellerPrice: drift.Value(resellerPaisa),
        retailPrice: drift.Value(retailPaisa),
        currentStock: drift.Value(currentStock),
        lowStockLimit: drift.Value(reorderLevel),
        description: drift.Value(_descriptionController.text.isEmpty ? null : _descriptionController.text),
      ));
    } else {
      final existing = await repository.getItemById(widget.id!);
      if (existing != null) {
        await repository.updateItem(existing.copyWith(
          name: _nameController.text,
          itemCode: drift.Value(_itemCodeController.text.isEmpty ? null : _itemCodeController.text),
          categoryId: drift.Value(_selectedCategoryId),
          unitTypeId: _selectedUnitTypeId!,
          purchasePrice: purchasePaisa,
          defaultResellerPrice: resellerPaisa,
          retailPrice: retailPaisa,
          currentStock: currentStock,
          lowStockLimit: reorderLevel,
          description: drift.Value(_descriptionController.text.isEmpty ? null : _descriptionController.text),
        ));
      }
    }

    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final unitTypesAsync = ref.watch(unitTypesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: BilingualLabel(
          english: widget.id == null ? 'Add Item' : 'Edit Item',
          urdu: widget.id == null ? 'Nayi Cheez' : 'Badlo',
          englishStyle: AppTextStyles.navTitle,
        ),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _save,
              child: const Text(AppStrings.save, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: 'Item Name',
                      urduLabel: 'Maal Ka Naam',
                      validator: (v) => v == null || v.isEmpty ? 'Please enter a name' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _itemCodeController,
                            label: 'Item Code',
                            urduLabel: 'Code',
                            hintText: _nextCodePreview != null
                                ? 'Auto: $_nextCodePreview'
                                : 'Auto-generated',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDropdown<ItemCategory>(
                            itemsAsync: categoriesAsync,
                            label: 'Category',
                            urduLabel: 'Category',
                            value: _selectedCategoryId,
                            onChanged: (v) => setState(() => _selectedCategoryId = v),
                            itemBuilder: (c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown<UnitType>(
                      itemsAsync: unitTypesAsync,
                      label: 'Unit Type',
                      urduLabel: 'Unit',
                      value: _selectedUnitTypeId,
                      onChanged: (v) => setState(() => _selectedUnitTypeId = v),
                      itemBuilder: (u) => DropdownMenuItem(value: u.id, child: Text('${u.name} (${u.nameUrdu ?? ''})', overflow: TextOverflow.ellipsis)),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _purchasePriceController,
                            label: 'Purchase Price',
                            urduLabel: 'Khareed Qeemat',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _resellerPriceController,
                            label: 'Wholesale Price',
                            urduLabel: 'Thok Qeemat',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _retailPriceController,
                            label: 'Retail Price',
                            urduLabel: 'Parchoon Qeemat',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Container()),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _currentStockController,
                            label: 'Current Stock',
                            urduLabel: 'Tadaad',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _reorderLevelController,
                            label: 'Reorder Level',
                            urduLabel: 'Minimum Stock',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String urduLabel,
    String? hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BilingualLabel(english: label, urdu: urduLabel, englishStyle: AppTextStyles.subheadline),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required AsyncValue<List<T>> itemsAsync,
    required String label,
    required String urduLabel,
    int? value,
    required void Function(int?) onChanged,
    required DropdownMenuItem<int> Function(T) itemBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BilingualLabel(english: label, urdu: urduLabel, englishStyle: AppTextStyles.subheadline),
        const SizedBox(height: 8),
        itemsAsync.when(
          data: (items) => DropdownButtonFormField<int>(
            value: value,
            isExpanded: true,
            items: items.map(itemBuilder).toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          loading: () => const CupertinoActivityIndicator(),
          error: (e, s) => Text('Error: $e'),
        ),
      ],
    );
  }
}
