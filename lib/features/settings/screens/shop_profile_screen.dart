import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/features/settings/providers/settings_provider.dart';
import 'package:drift/drift.dart' as drift;

class ShopProfileScreen extends ConsumerStatefulWidget {
  const ShopProfileScreen({super.key});
  @override
  ConsumerState<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends ConsumerState<ShopProfileScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _loadIfNeeded(AppSetting? settings) {
    if (_loaded || settings == null) return;
    _nameController.text = settings.shopName;
    _addressController.text = settings.address ?? '';
    _phoneController.text = settings.phone ?? '';
    _loaded = true;
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Shop Profile')),
      body: settingsAsync.when(
        data: (settings) {
          _loadIfNeeded(settings);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Shop Name', style: AppTextStyles.caption),
                const SizedBox(height: 4),
                TextField(controller: _nameController, decoration: const InputDecoration(border: OutlineInputBorder())),
                const SizedBox(height: 16),
                const Text('Address', style: AppTextStyles.caption),
                const SizedBox(height: 4),
                TextField(controller: _addressController, maxLines: 2, decoration: const InputDecoration(border: OutlineInputBorder())),
                const SizedBox(height: 16),
                const Text('Contact Number', style: AppTextStyles.caption),
                const SizedBox(height: 4),
                TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(border: OutlineInputBorder())),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await ref.read(settingsDaoProvider).updateSettings(AppSettingsCompanion(
                        shopName: drift.Value(_nameController.text),
                        address: drift.Value(_addressController.text),
                        phone: drift.Value(_phoneController.text),
                      ));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shop profile saved')));
                        context.pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(double.infinity, 50)),
                    child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
