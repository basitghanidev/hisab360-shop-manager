import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/database/database_provider.dart';
import 'package:sentery_app/core/services/backup_service.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _isWorking = false;
  String? _lastBackupPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(
          english: 'Backup & Restore',
          urdu: 'Data Mehfooz Karein',
          englishStyle: AppTextStyles.navTitle,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AppCard(
              child: Column(
                children: [
                  const Icon(Icons.cloud_upload, size: 64, color: Colors.teal),
                  const SizedBox(height: 16),
                  const Text('Manual JSON Backup', style: AppTextStyles.cardTitle),
                  const SizedBox(height: 8),
                  const Text(
                    'Export your shop data to a JSON file. You can share this file to Google Drive or WhatsApp.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isWorking ? null : _handleExport,
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: Text(_isWorking ? 'Exporting...' : 'Backup Now (Export)'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, minimumSize: const Size(double.infinity, 50)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                children: [
                  const Icon(Icons.settings_backup_restore, size: 64, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text('Restore from JSON', style: AppTextStyles.cardTitle),
                  const SizedBox(height: 8),
                  const Text(
                    'Paste the JSON content from your backup file to restore all data.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isWorking ? null : _showRestoreDialog,
                    icon: const Icon(Icons.upload, color: Colors.white),
                    label: const Text('Restore Data (Import)'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size(double.infinity, 50)),
                  ),
                ],
              ),
            ),
            if (_lastBackupPath != null) ...[
              const SizedBox(height: 24),
              Text('Last Backup Saved To:', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SelectableText(_lastBackupPath!, textAlign: TextAlign.center, style: AppTextStyles.caption),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleExport() async {
    setState(() => _isWorking = true);
    try {
      final db = ref.read(databaseProvider);
      final path = await BackupService(db).exportBackup();
      setState(() => _lastBackupPath = path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup successful! File shared.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  void _showRestoreDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Paste the JSON content from your backup file here:', style: AppTextStyles.caption),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 10,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '{"version": "2.1", ...}'),
            ),
            const SizedBox(height: 12),
            const Text('WARNING: This will delete ALL current data!', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              Navigator.pop(context);
              _handleRestore(controller.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Restore Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRestore(String content) async {
    setState(() => _isWorking = true);
    try {
      final db = ref.read(databaseProvider);
      await BackupService(db).restoreBackup(content);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restore successful! Restart app to see changes.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }
}
