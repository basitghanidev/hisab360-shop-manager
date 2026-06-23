import 'package:flutter/material.dart';
import 'package:sentery_app/core/constants/app_strings.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';
import 'package:sentery_app/features/suppliers/screens/supplier_list_screen.dart';
import 'package:sentery_app/features/wholesalers/screens/wholesaler_list_screen.dart';
import 'package:sentery_app/features/customers/screens/customer_list_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/features/suppliers/providers/supplier_provider.dart';
import 'package:sentery_app/features/wholesalers/providers/wholesaler_provider.dart';
import 'package:sentery_app/features/customers/providers/customer_provider.dart';

import 'package:sentery_app/core/widgets/animated_sync_icon.dart';

class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const BilingualLabel(
            english: 'People Management',
            urdu: AppStrings.partiesRoman,
            englishStyle: AppTextStyles.navTitle,
          ),
          actions: [
            AnimatedSyncIcon(
              onPressed: () {
                ref.invalidate(suppliersStreamProvider);
                ref.invalidate(wholesalersStreamProvider);
                ref.invalidate(customersStreamProvider);
              }
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Suppliers'),
              Tab(text: 'Wholesalers'),
              Tab(text: 'Customers'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SupplierListScreen(),
            WholesalerListScreen(),
            CustomerListScreen(),
          ],
        ),
      ),
    );
  }
}
