import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/database/database_provider.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';
import 'package:sentery_app/core/utils/money_utils.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';

class AddLedgerEntryScreen extends ConsumerStatefulWidget {
  final String partyType;
  final int partyId;
  final bool isGave;

  const AddLedgerEntryScreen({
    super.key,
    required this.partyType,
    required this.partyId,
    required this.isGave,
  });

  @override
  ConsumerState<AddLedgerEntryScreen> createState() => _AddLedgerEntryScreenState();
}

class _AddLedgerEntryScreenState extends ConsumerState<AddLedgerEntryScreen> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isGave ? 'YOU GAVE' : 'YOU GOT';
    final color = widget.isGave ? AppColors.danger : AppColors.success;

    return Scaffold(
      appBar: AppBar(
        title: Text('$title Rs'),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AppCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        style: AppTextStyles.largeTitle.copyWith(color: color),
                        decoration: InputDecoration(
                          prefixText: 'Rs. ',
                          hintText: 'Enter Amount',
                          hintStyle: TextStyle(color: color.withOpacity(0.3)),
                          border: InputBorder.none,
                        ),
                      ),
                      const Divider(),
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Notes (Optional) - e.g. Bill payment, Advance',
                          border: InputBorder.none,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  onTap: _selectDate,
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('dd MMMM yyyy').format(_selectedDate),
                        style: AppTextStyles.body,
                      ),
                      const Spacer(),
                      const Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveEntry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'SAVE TRANSACTION',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _saveEntry() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter amount')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = ref.read(databaseProvider);
      final amountPaisa = Money.fromString(amountText).paisa;
      
      // A payment in our system is a 'money_in' or 'money_out' transaction
      // For ledger: 
      // YOU GAVE (isGave=true) -> Money going OUT of shop. For a customer, this is typically an adjustment or loan (Debit).
      // YOU GOT (isGave=false) -> Money coming IN to shop. This is a payment received (Credit).
      
      final direction = widget.isGave ? 'money_out' : 'money_in';

      await db.paymentDao.recordManualPayment(
        partyType: widget.partyType,
        partyId: widget.partyId,
        amount: amountPaisa,
        direction: direction,
        date: _selectedDate,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }
}
