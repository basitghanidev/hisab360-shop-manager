import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_strings.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/features/wholesalers/providers/wholesaler_provider.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';

class WholesalerListScreen extends ConsumerWidget {
  const WholesalerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wholesalersAsync = ref.watch(filteredWholesalersProvider);
    final searchController = TextEditingController(text: ref.read(wholesalerSearchProvider));

    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(
          english: AppStrings.wholesalers,
          urdu: AppStrings.wholesalersRoman,
          englishStyle: AppTextStyles.navTitle,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync), 
            onPressed: () => ref.invalidate(wholesalersStreamProvider),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/wholesalers/add'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: CupertinoSearchTextField(
              controller: searchController,
              placeholder: AppStrings.searchRoman,
              onChanged: (value) => ref.read(wholesalerSearchProvider.notifier).state = value,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(wholesalersStreamProvider);
          ref.invalidate(wholesalerSearchProvider);
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: wholesalersAsync.when(
          data: (wholesalers) {
            if (wholesalers.isEmpty) {
              return const Center(child: Text('No wholesalers found'));
            }
            return ListView.builder(
              itemCount: wholesalers.length,
              itemBuilder: (context, index) {
                final wholesaler = wholesalers[index];
                final balancePaisa = wholesaler.currentBalance;
                final balanceColor = balancePaisa >= 0 ? AppColors.success : AppColors.danger;
                final balanceText = balancePaisa >= 0 ? AppStrings.theyOweRoman : AppStrings.weOweRoman;

                return AppCard(
                  onTap: () => context.push('/wholesalers/${wholesaler.id}'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(wholesaler.name, style: AppTextStyles.cardTitle),
                            if (wholesaler.phone != null)
                              Text(wholesaler.phone!, style: AppTextStyles.subheadline.copyWith(color: AppColors.textSecondary)),
                            if (wholesaler.area != null)
                              Text(wholesaler.area!, style: AppTextStyles.caption.copyWith(color: AppColors.textLight)),
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
