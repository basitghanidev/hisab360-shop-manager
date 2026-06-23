import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';
import 'package:sentery_app/features/invoices/providers/invoice_provider.dart';
import 'package:sentery_app/core/database/database_provider.dart';
import 'package:intl/intl.dart';

class DraftsListScreen extends ConsumerStatefulWidget {
  const DraftsListScreen({super.key});
  @override
  ConsumerState<DraftsListScreen> createState() => _DraftsListScreenState();
}

class _DraftsListScreenState extends ConsumerState<DraftsListScreen> {
  Map<String, dynamic>? _saleDraft;
  Map<String, dynamic>? _purchaseDraft;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final service = ref.read(draftServiceProvider);
    _saleDraft = await service.getSaleDraft();
    _purchaseDraft = await service.getPurchaseDraft();
    setState(() => _loading = false);
  }

  double _draftTotal(Map<String, dynamic> draft) {
    final items = (draft['items'] as List?) ?? [];
    double total = 0.0;
    for (final i in items) {
      final qty = (i['quantity'] as num?)?.toDouble() ?? 0.0;
      final price = (i['unitPrice'] as num?)?.toDouble() ?? 0.0;
      final discount = (i['discount'] as num?)?.toDouble() ?? 0.0;
      total += (qty * price) - discount;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(english: 'Unsaved Drafts', urdu: 'Adhoori Bills', englishStyle: AppTextStyles.navTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_saleDraft == null && _purchaseDraft == null)
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.drafts_outlined, size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      const Text('No unsaved drafts right now', style: AppTextStyles.body),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_saleDraft != null) _buildDraftTile(
                      title: 'New Sale (draft)',
                      icon: Icons.point_of_sale,
                      color: AppColors.primary,
                      draft: _saleDraft!,
                      onOpen: () => context.push('/invoice/sale'),
                      onDelete: () async {
                        await ref.read(draftServiceProvider).clearSaleDraft();
                        _load();
                      },
                    ),
                    if (_purchaseDraft != null) _buildDraftTile(
                      title: 'New Purchase (draft)',
                      icon: Icons.shopping_bag_outlined,
                      color: AppColors.accent,
                      draft: _purchaseDraft!,
                      onOpen: () => context.push('/invoice/purchase'),
                      onDelete: () async {
                        await ref.read(draftServiceProvider).clearPurchaseDraft();
                        _load();
                      },
                    ),
                  ],
                ),
    );
  }

  Widget _buildDraftTile({
    required String title,
    required IconData icon,
    required Color color,
    required Map<String, dynamic> draft,
    required VoidCallback onOpen,
    required VoidCallback onDelete,
  }) {
    final items = (draft['items'] as List?) ?? [];
    final total = _draftTotal(draft);
    final timestamp = draft['timestamp'] != null ? DateTime.tryParse(draft['timestamp']) : null;
    final timeStr = timestamp != null ? DateFormat('dd MMM, hh:mm a').format(timestamp) : '';

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onOpen,
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.cardTitle),
                Text('${items.length} item(s)  •  $timeStr', style: AppTextStyles.caption),
                Text(CurrencyFormatter.format(total),
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: () {
              showCupertinoDialog(
                context: context,
                builder: (ctx) => CupertinoAlertDialog(
                  title: const Text('Delete this draft?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    CupertinoDialogAction(child: const Text('Cancel'), onPressed: () => Navigator.pop(ctx)),
                    CupertinoDialogAction(
                      isDestructiveAction: true,
                      child: const Text('Delete'),
                      onPressed: () { Navigator.pop(ctx); onDelete(); },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
