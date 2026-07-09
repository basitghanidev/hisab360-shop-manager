import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/database/database_provider.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/core/utils/money_utils.dart';
import 'package:sentery_app/features/customers/providers/customer_provider.dart';
import 'package:sentery_app/features/dashboard/providers/dashboard_provider.dart';
import 'package:sentery_app/features/reports/providers/report_provider.dart';
import 'package:sentery_app/features/invoices/providers/invoice_provider.dart';
import 'package:sentery_app/features/suppliers/providers/supplier_provider.dart';
import 'package:sentery_app/features/wholesalers/providers/wholesaler_provider.dart';

class RecordPaymentScreen extends ConsumerStatefulWidget {
  final String? partyType; 
  final int? partyId;
  final String? direction; 

  const RecordPaymentScreen({super.key, this.partyType, this.partyId, this.direction});

  @override
  ConsumerState<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends ConsumerState<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _transactionIdController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _senderNameController = TextEditingController();

  String _partyType = 'customer';
  int? _selectedPartyId;
  int? _selectedInvoiceId;
  String _paymentMethod = 'cash';
  String _onlineMethod = 'easypaisa';
  String _paymentDirection = 'money_in'; 
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.partyType != null) _partyType = widget.partyType!;
    if (widget.partyId != null) _selectedPartyId = widget.partyId;
    if (widget.direction != null) _paymentDirection = widget.direction!;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _transactionIdController.dispose();
    _accountNumberController.dispose();
    _senderNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record Payment (Adaigi)')),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDirectionToggle(),
              if (_paymentDirection == 'money_out' && _partyType != 'supplier') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.danger.withOpacity(0.25)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.arrow_upward, color: AppColors.danger, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Shop is PAYING this party (Hum Inhe De Rahe Hain).\n'
                          'This money goes OUT of the shop.',
                          style: TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _buildTypeSelector(),
              const SizedBox(height: 20),
              _buildPartySelector(),
              if (_selectedPartyId != null) ...[
                const SizedBox(height: 20),
                _buildInvoiceSelector(),
              ],
              
              // Amount field — only show after invoice is selected (for customer/wholesaler)
              if (_partyType == 'supplier' || _selectedInvoiceId != null) ...[
                const SizedBox(height: 20),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount (Rupay)', 
                    border: OutlineInputBorder(), 
                    prefixText: 'Rs. ',
                    helperText: 'Select a bill above to auto-fill the remaining amount.',
                  ),
                  validator: (v) => (v == null || double.tryParse(v) == null || double.parse(v) <= 0) ? 'Enter valid amount' : null,
                ),
                const SizedBox(height: 20),
                _buildPaymentMethodSelector(),
                const SizedBox(height: 20),
                if (_paymentMethod == 'online' || _paymentMethod == 'mixed') _buildOnlineDetails(),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes (Optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _savePayment,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: AppColors.primary),
                    child: Text(_isLoading ? 'Saving...' : 'Save Payment', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ] else if (_partyType != 'supplier') ...[
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary.withOpacity(0.5), size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'Select a bill above to continue with the payment.',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment Direction', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'money_in', label: Text('Money In (Aaye)'), icon: Icon(Icons.arrow_downward, color: AppColors.success)),
            ButtonSegment(value: 'money_out', label: Text('Money Out (Gaye)'), icon: Icon(Icons.arrow_upward, color: AppColors.danger)),
          ],
          selected: {_paymentDirection},
          onSelectionChanged: (val) => setState(() => _paymentDirection = val.first),
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Party Type', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _partyType,
          items: const [
            DropdownMenuItem(value: 'customer', child: Text('Customer (Grahak)')),
            DropdownMenuItem(value: 'wholesaler', child: Text('Wholesaler (Thok Farosh)')),
            DropdownMenuItem(value: 'supplier', child: Text('Supplier (Maal Dene Wala)')),
          ],
          onChanged: (v) => setState(() { _partyType = v!; _selectedPartyId = null; _selectedInvoiceId = null; }),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ],
    );
  }

  Widget _buildPartySelector() {
    AsyncValue<List<dynamic>> partiesAsync;
    if (_partyType == 'customer') partiesAsync = ref.watch(customersStreamProvider);
    else if (_partyType == 'wholesaler') partiesAsync = ref.watch(wholesalersStreamProvider);
    else partiesAsync = ref.watch(suppliersStreamProvider);

    return partiesAsync.when(
      data: (list) {
        final items = list.map((e) => MapEntry<int, String>(e.id, e.name)).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Party', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _selectedPartyId,
              isExpanded: true,
              hint: const Text('Search party...'),
              items: items.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) async {
                if (v == null) return;
                setState(() {
                  _selectedPartyId = v;
                  _selectedInvoiceId = null;
                  _amountController.clear();
                });

                // ─── AUTO-DIRECTION FROM BALANCE ───────────────────────────────
                // If this customer/wholesaler has a negative balance, the shop
                // owes them money. Default to money_out (we pay them).
                // This prevents the user from accidentally recording money_in
                // when the shop is the one doing the paying.
                if (_partyType == 'customer') {
                  final customers = await ref.read(customersStreamProvider.future);
                  final party = customers.where((c) => c.id == v).firstOrNull;
                  if (party != null && mounted) {
                    setState(() {
                      _paymentDirection = party.currentBalance < 0 ? 'money_out' : 'money_in';
                    });
                  }
                } else if (_partyType == 'wholesaler') {
                  final wholesalers = await ref.read(wholesalersStreamProvider.future);
                  final party = wholesalers.where((w) => w.id == v).firstOrNull;
                  if (party != null && mounted) {
                    setState(() {
                      _paymentDirection = party.currentBalance < 0 ? 'money_out' : 'money_in';
                    });
                  }
                }
                // ─────────────────────────────────────────────────────────────
              },
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error loading parties: $e'),
    );
  }

  Widget _buildInvoiceSelector() {
    final invoicesAsync = ref.watch(invoicesByPartyProvider((_partyType, _selectedPartyId!)));
    return invoicesAsync.when(
      data: (list) {
        final pending = list
            .where((i) =>
                i.status != 'paid' &&
                i.status != 'cancelled' &&
                !i.invoiceType.contains('payment') &&
                !i.invoiceType.contains('receipt'))
            .toList();

        // ─── KEY FIX ────────────────────────────────────────────────────────
        // Resolve the safe value for the DropdownButton synchronously,
        // BEFORE building it. If the stored ID is gone from this party's
        // pending list, treat it as null so the widget never asserts.
        final bool selectedIsValid =
            _selectedInvoiceId != null && pending.any((i) => i.id == _selectedInvoiceId);
        final int? effectiveId = selectedIsValid ? _selectedInvoiceId : null;

        // Schedule the state cleanup for next frame (safe: effectiveId already null above,
        // the dropdown won't crash, and the cleanup keeps _selectedInvoiceId in sync).
        if (!selectedIsValid && _selectedInvoiceId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedInvoiceId = null);
          });
        }
        // ────────────────────────────────────────────────────────────────────

        if (pending.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text('No pending bills for this party.', style: TextStyle(color: Colors.grey))),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Bill to Pay (Required)',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger)),
            const SizedBox(height: 4),
            const Text('You must select which bill this payment applies to.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: effectiveId,              // ← safe value, never causes assertion
              isExpanded: true,
              hint: const Text('Select bill...'),
              validator: (v) {
                if (_partyType != 'supplier' && v == null) return 'Please select a bill';
                return null;
              },
              items: pending
                  .map((i) => DropdownMenuItem(
                        value: i.id,
                        child: Text(
                          '${i.invoiceNumber} — Rem: ${CurrencyFormatter.formatPaisa(i.amountRemaining)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() {
                _selectedInvoiceId = v;
                if (v != null) {
                  final inv = pending.firstWhere((i) => i.id == v);
                  _amountController.text =
                      Money.fromPaisa(inv.amountRemaining).toDouble().toStringAsFixed(0);
                  
                  // Auto-toggle direction based on invoice type
                  if (inv.invoiceType.contains('return')) {
                    _paymentDirection = inv.invoiceType == 'return_supplier' ? 'money_in' : 'money_out';
                  } else {
                    _paymentDirection = inv.invoiceType == 'purchase' ? 'money_out' : 'money_in';
                  }
                }
              }),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary, width: 2)),
                errorBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.danger)),
                filled: true,
                fillColor: AppColors.primary.withOpacity(0.04),
              ),
            ),
            if (effectiveId != null) ...[
              const SizedBox(height: 8),
              Builder(builder: (ctx) {
                final inv = pending.firstWhere((i) => i.id == effectiveId);
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _infoRow('Bill Amount:', CurrencyFormatter.formatPaisa(inv.totalAmount)),
                      _infoRow('Already Paid:', CurrencyFormatter.formatPaisa(inv.amountPaid)),
                      const Divider(height: 12),
                      _infoRow('Remaining:', CurrencyFormatter.formatPaisa(inv.amountRemaining), isBold: true, color: AppColors.danger),
                    ],
                  ),
                );
              }),
            ],
          ],
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error loading bills: $e'),
    );
  }

  Widget _infoRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(value, style: TextStyle(
            fontSize: 13, 
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          )),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _paymentMethod,
          items: const [
            DropdownMenuItem(value: 'cash', child: Text('Cash (Naqad)')),
            DropdownMenuItem(value: 'online', child: Text('Online (Digital)')),
            DropdownMenuItem(value: 'mixed', child: Text('Mixed (Cash + Online)')),
          ],
          onChanged: (v) => setState(() => _paymentMethod = v!),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ],
    );
  }

  Widget _buildOnlineDetails() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _onlineMethod,
            items: const [
              DropdownMenuItem(value: 'easypaisa', child: Text('Easypaisa')),
              DropdownMenuItem(value: 'jazzcash', child: Text('JazzCash')),
              DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _onlineMethod = v!),
            decoration: const InputDecoration(labelText: 'Digital Platform', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _transactionIdController, decoration: const InputDecoration(labelText: 'Trans ID / Ref #', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextFormField(controller: _senderNameController, decoration: const InputDecoration(labelText: 'Sender/Bank Name', border: OutlineInputBorder())),
        ],
      ),
    );
  }

  Future<void> _savePayment() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0 || _selectedPartyId == null) return;

    if (_partyType != 'supplier' && _selectedInvoiceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a pending bill to apply this payment to.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);

      await db.paymentDao.recordPayment(
        method: _paymentMethod,
        amount: amount,
        supplierId: _partyType == 'supplier' ? _selectedPartyId : null,
        wholesalerId: _partyType == 'wholesaler' ? _selectedPartyId : null,
        customerId: _partyType == 'customer' ? _selectedPartyId : null,
        invoiceId: _selectedInvoiceId,
        onlineMethod: (_paymentMethod == 'online' || _paymentMethod == 'mixed') ? _onlineMethod : null,
        transId: _transactionIdController.text.isNotEmpty ? _transactionIdController.text : null,
        accountNumber: _accountNumberController.text.isNotEmpty ? _accountNumberController.text : null,
        senderName: _senderNameController.text.isNotEmpty ? _senderNameController.text : null,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        paymentDirection: _paymentDirection,
        partyType: _partyType,
      );

      // After successful save, invalidate dashboard so it reflects new data immediately.
      ref.invalidate(dashboardProvider);
      ref.invalidate(lowStockItemsProvider);

      if (mounted) {
        if (_selectedInvoiceId != null) {
          ref.invalidate(invoiceByIdProvider(_selectedInvoiceId!));
          // Correct invalidation for invoicesByPartyProvider family
          ref.invalidate(invoicesByPartyProvider((_partyType, _selectedPartyId!)));
        }
        ref.invalidate(dashboardProvider);
        if (_partyType == 'customer') {
          ref.invalidate(customerLedgerProvider(_selectedPartyId!));
          ref.invalidate(customerInvoicesProvider(_selectedPartyId!));
          ref.invalidate(customerByIdProvider(_selectedPartyId!));
        } else if (_partyType == 'wholesaler') {
          ref.invalidate(wholesalerLedgerProvider(_selectedPartyId!));
          ref.invalidate(wholesalerInvoicesProvider(_selectedPartyId!));
          ref.invalidate(wholesalerByIdProvider(_selectedPartyId!));
        } else if (_partyType == 'supplier') {
          ref.invalidate(supplierLedgerProvider(_selectedPartyId!));
          ref.invalidate(supplierInvoicesProvider(_selectedPartyId!));
          ref.invalidate(supplierByIdProvider(_selectedPartyId!));
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${CurrencyFormatter.format(amount)} payment saved'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
