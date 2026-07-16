import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/constants/app_strings.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';
import 'package:drift/drift.dart' as drift;
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/features/items/providers/item_provider.dart';
import 'package:sentery_app/features/settings/providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(
          english: 'App Settings',
          urdu: AppStrings.settingsRoman,
          englishStyle: AppTextStyles.navTitle,
        ),
      ),
      body: settingsAsync.when(
        data: (settings) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSection('Audit & Security'),
            AppCard(
              child: Column(
                children: [
                  _buildTile(Icons.history_edu, 'Activity Audit Logs', 'View every change', () => context.push('/settings/audit-logs')),
                  const Divider(),
                  _buildTile(Icons.cloud_upload_outlined, 'Data Backup & Sync', 'Cloud Protection', () => context.push('/backup')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSection('Item Management'),
            AppCard(
              child: Column(
                children: [
                  _buildTile(
                    Icons.category_outlined,
                    'Manage Item Categories',
                    'Add or remove maal ki aqsaam',
                    () => context.push('/settings/categories'),
                  ),
                  const Divider(),
                  _buildTile(
                    Icons.outbond_outlined,
                    'Manage Expense Categories',
                    'Add or remove kharchay ki aqsaam',
                    () => context.push('/settings/expense-categories'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSection('Business Identity'),
            AppCard(
              child: _buildTile(
                Icons.store_mall_directory_outlined, 'Shop Profile',
                settings?.shopName ?? 'Set Shop Details',
                () => context.push('/settings/shop-profile'),
              ),
            ),
            const SizedBox(height: 16),
            _buildSection('Technical Preferences'),
            AppCard(
              child: Column(
                children: [
                  _buildTile(Icons.calculate_outlined, 'Inventory Costing', settings?.costingMethod == 'fifo' ? 'FIFO (Oldest First)' : 'Average Cost',
                      () => _showCostingMethodPicker(context, ref, settings)),
                  const Divider(),
                  _buildTile(Icons.language_outlined, 'System Language', settings?.language == 'ur' ? 'Roman Urdu' : 'English (Primary)',
                      () => _showLanguagePicker(context, ref, settings)),
                  const Divider(),
                  _buildTile(Icons.print_outlined, 'Invoice Print Format', _formatPageSize(settings?.pdfPageSize),
                      () => _showPageSizePicker(context, ref, settings)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Text(
                    'Hisab360 - Shop Manager',
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text('Version 1.1.0', style: AppTextStyles.caption),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.code, size: 14, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text(
                          'Powered by Basit Ghani',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(title.toUpperCase(), style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
    );
  }

  Widget _buildTile(IconData icon, String title, String value, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
      title: Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(value, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
      onTap: onTap,
    );
  }

  void _showCostingMethodPicker(BuildContext context, WidgetRef ref, AppSetting? settings) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Inventory Costing Method'),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              await ref.read(settingsDaoProvider).updateSettings(const AppSettingsCompanion(costingMethod: drift.Value('average')));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Average Cost (Weighted Average)'),
          ),
          SimpleDialogOption(
            onPressed: () async {
              await ref.read(settingsDaoProvider).updateSettings(const AppSettingsCompanion(costingMethod: drift.Value('fifo')));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('FIFO (First In, First Out)'),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref, AppSetting? settings) {
    // ... same content ...
  }

  void _showPageSizePicker(BuildContext context, WidgetRef ref, AppSetting? settings) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Invoice Print Format'),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              await ref.read(settingsDaoProvider).updateSettings(const AppSettingsCompanion(pdfPageSize: drift.Value('A4')));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('A4 Paper (Standard Printer)'),
          ),
          SimpleDialogOption(
            onPressed: () async {
              await ref.read(settingsDaoProvider).updateSettings(const AppSettingsCompanion(pdfPageSize: drift.Value('Roll80')));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('80mm Roll (Thermal Printer)'),
          ),
          SimpleDialogOption(
            onPressed: () async {
              await ref.read(settingsDaoProvider).updateSettings(const AppSettingsCompanion(pdfPageSize: drift.Value('Roll58')));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('58mm Roll (Small Thermal Printer)'),
          ),
        ],
      ),
    );
  }

  String _formatPageSize(String? size) {
    switch (size) {
      case 'A4': return 'A4 Standard';
      case 'Roll80': return '80mm Thermal Roll';
      case 'Roll58': return '58mm Thermal Roll';
      default: return 'A4 Standard';
    }
  }
}
