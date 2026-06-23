import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_strings.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/features/suppliers/providers/supplier_provider.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';

class SupplierListScreen extends ConsumerWidget {
  const SupplierListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(filteredSuppliersProvider);
    final searchController = TextEditingController(text: ref.read(supplierSearchProvider));

    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(
          english: AppStrings.suppliers,
          urdu: AppStrings.suppliersRoman,
          englishStyle: AppTextStyles.navTitle,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync), 
            onPressed: () => ref.invalidate(suppliersStreamProvider),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/suppliers/add'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: CupertinoSearchTextField(
              controller: searchController,
              placeholder: AppStrings.searchRoman,
              onChanged: (value) => ref.read(supplierSearchProvider.notifier).state = value,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(suppliersStreamProvider);
          ref.invalidate(supplierSearchProvider);
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: suppliersAsync.when(
          data: (suppliers) {
            if (suppliers.isEmpty) {
              return const Center(child: Text('No suppliers found'));
            }
            return ListView.builder(
              itemCount: suppliers.length,
              itemBuilder: (context, index) {
                final supplier = suppliers[index];
                final balancePaisa = supplier.currentBalance;
                final balanceColor = balancePaisa >= 0 ? AppColors.danger : AppColors.success;
                final balanceText = balancePaisa >= 0 ? AppStrings.weOweRoman : AppStrings.theyOweRoman;

                return AppCard(
                  onTap: () => context.push('/suppliers/${supplier.id}'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(supplier.name, style: AppTextStyles.cardTitle),
                            if (supplier.phone != null)
                              Text(supplier.phone!, style: AppTextStyles.subheadline.copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyFormatter.formatPaisa(balancePaisa.abs()),
                            style: AppTextStyles.body.copyWith(
                              color: balanceColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            balanceText,
                            style: AppTextStyles.caption.copyWith(color: balanceColor),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: AppColors.textLight),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }
}
