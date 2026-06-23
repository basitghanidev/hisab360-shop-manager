import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_strings.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/features/customers/providers/customer_provider.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';

class CustomerListScreen extends ConsumerWidget {
  const CustomerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(filteredCustomersProvider);
    final searchController = TextEditingController(text: ref.read(customerSearchProvider));

    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(
          english: AppStrings.customers,
          urdu: AppStrings.customersRoman,
          englishStyle: AppTextStyles.navTitle,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync), 
            onPressed: () => ref.invalidate(customersStreamProvider),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/customers/add'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: CupertinoSearchTextField(
              controller: searchController,
              placeholder: AppStrings.searchRoman,
              onChanged: (value) => ref.read(customerSearchProvider.notifier).state = value,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(customersStreamProvider);
          ref.invalidate(customerSearchProvider);
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: customersAsync.when(
          data: (customers) {
            if (customers.isEmpty) {
              return const Center(child: Text('No customers found'));
            }
            return ListView.builder(
              itemCount: customers.length,
              itemBuilder: (context, index) {
                final customer = customers[index];
                final balancePaisa = customer.currentBalance;
                final balanceColor = balancePaisa >= 0 ? AppColors.success : AppColors.danger;
                final balanceText = balancePaisa >= 0 ? AppStrings.theyOweRoman : AppStrings.weOweRoman;

                return AppCard(
                  onTap: () => context.push('/customers/${customer.id}'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(customer.name, style: AppTextStyles.cardTitle),
                            if (customer.phone != null)
                              Text(customer.phone!, style: AppTextStyles.subheadline.copyWith(color: AppColors.textSecondary)),
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
