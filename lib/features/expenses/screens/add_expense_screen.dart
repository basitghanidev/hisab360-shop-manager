import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/money_utils.dart';
import 'package:sentery_app/features/expenses/providers/expense_provider.dart';
import 'package:drift/drift.dart' as drift;

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  int? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amountStr = _amountController.text;
    if (amountStr.isEmpty) return;

    final amountPaisa = Money.fromString(amountStr).paisa;
    if (amountPaisa <= 0) return;

    setState(() => _isLoading = true);

    try {
      final dao = ref.read(expenseDaoProvider);
      await dao.insertExpense(ExpensesCompanion.insert(
        amount: drift.Value(amountPaisa),
        categoryId: drift.Value(_selectedCategoryId),
        notes: drift.Value(_notesController.text.isEmpty ? null : _notesController.text),
        date: drift.Value(_selectedDate),
      ));

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(expenseCategoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.danger),
              decoration: const InputDecoration(
                prefixText: 'Rs. ',
                hintText: 'Enter Amount',
                border: UnderlineInputBorder(),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.danger, width: 2)),
              ),
            ),
            const SizedBox(height: 24),
            categoriesAsync.when(
              data: (categories) => DropdownButtonFormField<int>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                onChanged: (v) => setState(() => _selectedCategoryId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, s) => Text('Error: $e'),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                    const Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('SAVE EXPENSE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
