import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_strings.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/money_utils.dart';
import 'package:sentery_app/features/wholesalers/providers/wholesaler_provider.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';
import 'package:drift/drift.dart' as drift;

class AddEditWholesalerScreen extends ConsumerStatefulWidget {
  final int? id;
  const AddEditWholesalerScreen({super.key, this.id});

  @override
  ConsumerState<AddEditWholesalerScreen> createState() => _AddEditWholesalerScreenState();
}

class _AddEditWholesalerScreenState extends ConsumerState<AddEditWholesalerScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _areaController;
  late TextEditingController _notesController;
  late TextEditingController _openingBalanceController;
  
  String _balanceType = 'debit'; // debit = they owe us, credit = we have their advance
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _areaController = TextEditingController();
    _notesController = TextEditingController();
    _openingBalanceController = TextEditingController(text: '0');

    if (widget.id != null) {
      _loadWholesaler();
    }
  }

  Future<void> _loadWholesaler() async {
    setState(() => _isLoading = true);
    final wholesaler = await ref.read(wholesalerRepositoryProvider).getWholesalerById(widget.id!);
    if (wholesaler != null) {
      _nameController.text = wholesaler.name;
      _phoneController.text = wholesaler.phone ?? '';
      _addressController.text = wholesaler.address ?? '';
      _areaController.text = wholesaler.area ?? '';
      _notesController.text = wholesaler.notes ?? '';
      
      final mOpening = Money.fromPaisa(wholesaler.openingBalance);
      _openingBalanceController.text = mOpening.abs().toDouble().toString();
      _balanceType = mOpening.paisa >= 0 ? 'debit' : 'credit';
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _areaController.dispose();
    _notesController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final repository = ref.read(wholesalerRepositoryProvider);

    final mOpening = Money.fromString(_openingBalanceController.text);
    final int netBalance = _balanceType == 'debit' ? mOpening.paisa : -mOpening.paisa;

    if (widget.id == null) {
      await repository.addWholesaler(WholesalersCompanion.insert(
        name: _nameController.text,
        phone: drift.Value(_phoneController.text.isEmpty ? null : _phoneController.text),
        address: drift.Value(_addressController.text.isEmpty ? null : _addressController.text),
        area: drift.Value(_areaController.text.isEmpty ? null : _areaController.text),
        notes: drift.Value(_notesController.text.isEmpty ? null : _notesController.text),
        openingBalance: drift.Value(netBalance),
        currentBalance: drift.Value(netBalance),
      ));
    } else {
      final existing = await repository.getWholesalerById(widget.id!);
      if (existing != null) {
        await repository.updateWholesaler(existing.copyWith(
          name: _nameController.text,
          phone: drift.Value(_phoneController.text.isEmpty ? null : _phoneController.text),
          address: drift.Value(_addressController.text.isEmpty ? null : _addressController.text),
          area: drift.Value(_areaController.text.isEmpty ? null : _areaController.text),
          notes: drift.Value(_notesController.text.isEmpty ? null : _notesController.text),
          openingBalance: netBalance,
          currentBalance: netBalance,
        ));
      }
    }

    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BilingualLabel(
          english: widget.id == null ? 'Add Wholesaler' : 'Edit Wholesaler',
          urdu: widget.id == null ? 'Naya Thok Farosh' : 'Tabdeel Karein',
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
                      label: 'Wholesaler Name',
                      urduLabel: 'Thok Farosh Ka Naam',
                      validator: (v) => v == null || v.isEmpty ? 'Please enter a name' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      urduLabel: 'Phone Number',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _areaController,
                            label: 'Area / Market',
                            urduLabel: 'Ilaqa',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Container()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _addressController,
                      label: 'Address',
                      urduLabel: 'Mukammal Pata',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Opening Balance Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const BilingualLabel(english: 'Opening Balance', urdu: 'Purana Hisab', englishStyle: AppTextStyles.subheadline),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _openingBalanceController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  prefixText: 'Rs. ',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                value: _balanceType,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  filled: true,
                                  fillColor: AppColors.surface,
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'debit', child: Text('Owe Us (Dena Hai)')),
                                  DropdownMenuItem(value: 'credit', child: Text('Advance (Jama Hai)')),
                                ],
                                onChanged: (v) => setState(() => _balanceType = v!),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _notesController,
                      label: 'Notes',
                      urduLabel: 'Zaroori Note',
                      maxLines: 3,
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }
}
