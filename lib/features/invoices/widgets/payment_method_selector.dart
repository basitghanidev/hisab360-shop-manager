import 'package:flutter/material.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/money_utils.dart';
import 'package:drift/drift.dart' as drift;

class PaymentMethodSelector extends StatefulWidget {
  final double totalAmount;
  final Function(List<PaymentsCompanion> payments) onPaymentsChanged;

  const PaymentMethodSelector({
    super.key,
    required this.totalAmount,
    required this.onPaymentsChanged,
  });

  @override
  State<PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends State<PaymentMethodSelector> {
  String _selectedMethod = 'cash';
  final _amountController = TextEditingController();
  final _transactionIdController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();

  static const _methods = [
    {'key': 'cash', 'label': 'Cash (Naqad)', 'icon': Icons.money},
    {'key': 'easypaisa', 'label': 'Easypaisa', 'icon': Icons.phone_android},
    {'key': 'jazzcash', 'label': 'JazzCash', 'icon': Icons.phone_android},
    {'key': 'bank_transfer', 'label': 'Bank (Transfer)', 'icon': Icons.account_balance},
  ];

  void _notifyParent() {
    final mAmount = Money.fromString(_amountController.text);
    if (mAmount.paisa <= 0) {
      widget.onPaymentsChanged([]);
      return;
    }

    final payment = PaymentsCompanion.insert(
      invoiceId: const drift.Value(null),
      paymentMethod: _selectedMethod,
      amount: drift.Value(mAmount.paisa),
      onlineMethod: _selectedMethod != 'cash' ? drift.Value(_selectedMethod) : const drift.Value(null),
      transactionId: _transactionIdController.text.isNotEmpty ? drift.Value(_transactionIdController.text) : const drift.Value(null),
      accountNumber: _accountNumberController.text.isNotEmpty ? drift.Value(_accountNumberController.text) : const drift.Value(null),
    );
    widget.onPaymentsChanged([payment]);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _transactionIdController.dispose();
    _phoneController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PAYMENT METHOD (ADAIGI KA TARIKA)', style: AppTextStyles.caption),
        const SizedBox(height: 8),

        Wrap(
          spacing: 8,
          children: _methods.map((m) {
            final isSelected = _selectedMethod == m['key'];
            return ChoiceChip(
              label: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(m['icon'] as IconData, size: 14, color: isSelected ? Colors.white : AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(m['label'] as String, style: TextStyle(
                    fontSize: 12, color: isSelected ? Colors.white : AppColors.textPrimary)),
              ]),
              selected: isSelected,
              selectedColor: AppColors.primary,
              onSelected: (_) => setState(() {
                _selectedMethod = m['key'] as String;
                _notifyParent();
              }),
            );
          }).toList(),
        ),

        const SizedBox(height: 12),

        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Amount Paid (Ada Shuda Raqam)',
            prefixText: 'Rs. ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true,
            suffixIcon: TextButton(
              onPressed: () {
                _amountController.text = widget.totalAmount.toStringAsFixed(0);
                _notifyParent();
              },
              child: const Text('Full', style: TextStyle(fontSize: 12)),
            ),
          ),
          onChanged: (_) => _notifyParent(),
        ),

        if (_selectedMethod != 'cash') ...[
          const SizedBox(height: 12),
          if (_selectedMethod == 'easypaisa' || _selectedMethod == 'jazzcash') ...[
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: '${_selectedMethod == 'easypaisa' ? 'Easypaisa' : 'JazzCash'} Phone Number',
                prefixText: '+92 ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
              onChanged: (_) => _notifyParent(),
            ),
            const SizedBox(height: 8),
          ],
          if (_selectedMethod == 'bank_transfer') ...[
            TextField(
              controller: _bankNameController,
              decoration: InputDecoration(
                labelText: 'Bank Name (e.g. HBL, Meezan)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
              onChanged: (_) => _notifyParent(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _accountNumberController,
              decoration: InputDecoration(
                labelText: 'Account / IBAN Number',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
              onChanged: (_) => _notifyParent(),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _transactionIdController,
            decoration: InputDecoration(
              labelText: 'Transaction ID (Optional)',
              hintText: 'e.g. EP-20250115-789',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
            onChanged: (_) => _notifyParent(),
          ),
        ],
      ],
    );
  }
}
