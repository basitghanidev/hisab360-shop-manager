import 'dart:io' as io;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sentery_app/core/constants/app_colors.dart';
import 'package:sentery_app/core/constants/app_text_styles.dart';
import 'package:sentery_app/core/database/database_provider.dart';
import 'package:sentery_app/core/services/backup_service.dart';
import 'package:sentery_app/core/services/google_drive_service.dart';
import 'package:sentery_app/core/widgets/app_card.dart';
import 'package:sentery_app/core/widgets/bilingual_label.dart';
import 'package:shared_preferences/shared_preferences.dart';

final googleDriveServiceProvider = Provider<GoogleDriveService>((_) => GoogleDriveService());

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _isWorking = false;
  String? _workingLabel;
  String? _persistedEmail;
  String? _persistedName;
  String? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _loadPersistedState();
  }

  Future<void> _loadPersistedState() async {
    // CRITICAL FIX: Avoid Platform check on Web
    final isDesktop = !kIsWeb && io.Platform.isWindows;
    if (isDesktop) return; // Google Sign-in not supported on Windows

    final service = ref.read(googleDriveServiceProvider);
    final email = await service.persistedEmail;
    final name = await service.persistedName;
    final prefs = await SharedPreferences.getInstance();
    final syncTime = prefs.getString('last_drive_sync');

    if (mounted) {
      setState(() {
        _persistedEmail = email;
        _persistedName = name;
        _lastSyncTime = syncTime;
      });
    }
  }

  void _setWorking(bool working, {String? label}) {
    if (mounted) setState(() { _isWorking = working; _workingLabel = label; });
  }

  @override
  Widget build(BuildContext context) {
    // CRITICAL FIX: Avoid Platform check on Web
    final isDesktop = !kIsWeb && io.Platform.isWindows;

    return Scaffold(
      appBar: AppBar(
        title: const BilingualLabel(
          english: 'Backup & Restore',
          urdu: 'Data Mehfooz Karein',
          englishStyle: AppTextStyles.navTitle,
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isDesktop) ...[
                  _buildDriveSection(),
                  const SizedBox(height: 16),
                ] else ...[
                  _buildDesktopCloudBanner(),
                  const SizedBox(height: 16),
                ],
                _buildManualExportCard(),
                const SizedBox(height: 16),
                _buildRestoreCard(),
                const SizedBox(height: 32),
              ],
            ),
          ),

          if (_isWorking)
            Container(
              color: Colors.black26,
              child: Center(
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _workingLabel ?? 'Please wait...',
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDriveSection() {
    final isConnected = _persistedEmail != null && _persistedEmail!.isNotEmpty;

    return AppCard(
      color: Colors.blue.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_sync, color: Colors.blue, size: 28),
              SizedBox(width: 10),
              Text('Google Drive Backup', style: AppTextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: 12),

          if (!isConnected) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: const Text(
                'Connect your Google account to back up your shop data to Google Drive.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isWorking ? null : _handleSignIn,
                icon: const Icon(Icons.login, color: Colors.white),
                label: const Text('Connect Google Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.success,
                    radius: 18,
                    child: Icon(Icons.check, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_persistedName?.isNotEmpty == true ? _persistedName! : 'Connected', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(_persistedEmail!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            if (_lastSyncTime != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Last sync: $_lastSyncTime', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ),
            ],

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isWorking ? null : _handleDriveSync,
                    icon: const Icon(Icons.backup, color: Colors.white, size: 18),
                    label: const Text('Backup Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isWorking ? null : _handleDriveRestore,
                    icon: const Icon(Icons.settings_backup_restore, color: Colors.white, size: 18),
                    label: const Text('Restore Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isWorking ? null : _handleSignOut,
                icon: const Icon(Icons.logout, color: AppColors.danger, size: 18),
                label: const Text('Disconnect Account', style: TextStyle(color: AppColors.danger, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.danger),
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManualExportCard() {
    return AppCard(
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.share, color: Colors.teal, size: 28),
              SizedBox(width: 10),
              Text('Manual Backup & Share', style: AppTextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Export your shop data as a JSON file to share via Email.', style: AppTextStyles.caption),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isWorking ? null : _handleManualExport,
              icon: const Icon(Icons.ios_share, color: Colors.white),
              label: const Text('Export & Share', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreCard() {
    return AppCard(
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.upload_file, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text('Restore from File', style: AppTextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Select a .json backup file from your phone to restore data.', style: AppTextStyles.caption),
          const SizedBox(height: 4),
          const Text('⚠️ WARNING: Deletes all current data!', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isWorking ? null : _handleFileRestore,
              icon: const Icon(Icons.file_open, color: Colors.white),
              label: const Text('Select Backup File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopCloudBanner() {
    return AppCard(
      color: Colors.blue.shade50,
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.blue, size: 28),
              SizedBox(width: 10),
              Text('Cloud Sync (Mobile Only)', style: AppTextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Google Drive Cloud Sync is currently optimized for mobile phones.\n\n'
            'For your laptop, please use "Manual Backup" to save data and '
            '"Restore from File" to move it between devices.',
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  // ─── HANDLERS ───────────────────────────────────────────────────────────────

  Future<void> _handleSignIn() async {
    _setWorking(true, label: 'Connecting to Google...');
    try {
      final account = await ref.read(googleDriveServiceProvider).signIn();
      if (account != null) {
        await _loadPersistedState();
        _showSnackBar('Connected: ${account.email}', color: AppColors.success, icon: Icons.check_circle);
      }
    } on GoogleSignInException catch (e) {
      _showSnackBar(e.message, color: AppColors.danger);
    } catch (e) {
      _showSnackBar('Error: $e', color: AppColors.danger);
    } finally {
      _setWorking(false);
    }
  }

  Future<void> _handleSignOut() async {
    await ref.read(googleDriveServiceProvider).signOut();
    await _loadPersistedState();
    _showSnackBar('Account disconnected.', color: Colors.grey);
  }

  Future<void> _handleDriveSync() async {
    _setWorking(true, label: 'Uploading to Google Drive...');
    try {
      final db = ref.read(databaseProvider);
      final path = await BackupService(db).createBackupFile();
      final result = await ref.read(googleDriveServiceProvider).uploadBackup(io.File(path));

      if (result.success) {
        final syncTimeStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_drive_sync', syncTimeStr);
        await _loadPersistedState();
        _showSnackBar(result.isUpdate ? 'Backup updated!' : 'Backup created!', color: AppColors.success);
      } else {
        _showSnackBar(result.errorMessage ?? 'Upload failed.', color: AppColors.danger);
      }
    } catch (e) {
      _showSnackBar('Sync error: $e', color: AppColors.danger);
    } finally {
      _setWorking(false);
    }
  }

  Future<void> _handleDriveRestore() async {
    final confirmed = await _showConfirmRestoreDialog();
    if (confirmed != true) return;

    _setWorking(true, label: 'Downloading from Google Drive...');
    try {
      final file = await ref.read(googleDriveServiceProvider).downloadBackup();
      if (file == null) {
        _showSnackBar('No backup file found on Google Drive.', color: Colors.orange);
        return;
      }

      _setWorking(true, label: 'Restoring data...');
      final db = ref.read(databaseProvider);
      await BackupService(db).restoreBackup(file);
      _showSnackBar('Restore successful! Please restart app.', color: AppColors.success, duration: 8);
    } catch (e) {
      _showSnackBar('Restore failed: $e', color: AppColors.danger);
    } finally {
      _setWorking(false);
    }
  }

  Future<void> _handleManualExport() async {
    _setWorking(true, label: 'Preparing backup...');
    try {
      final db = ref.read(databaseProvider);
      await BackupService(db).exportAndShare();
    } catch (e) {
      _showSnackBar('Export failed: $e', color: AppColors.danger);
    } finally {
      _setWorking(false);
    }
  }

  Future<void> _handleFileRestore() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (result == null || result.files.single.path == null) return;

    final confirmed = await _showConfirmRestoreDialog();
    if (confirmed != true) return;

    _setWorking(true, label: 'Restoring from file...');
    try {
      final file = io.File(result.files.single.path!);
      final db = ref.read(databaseProvider);
      await BackupService(db).restoreBackup(file);
      _showSnackBar('Restore successful! Please restart app.', color: AppColors.success, duration: 8);
    } catch (e) {
      _showSnackBar('Restore failed: $e', color: AppColors.danger);
    } finally {
      _setWorking(false);
    }
  }

  Future<bool?> _showConfirmRestoreDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Restore'),
        content: const Text('This will DELETE all current data and replace it with the backup. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Restore Everything', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {Color color = AppColors.primary, int duration = 3, IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [if (icon != null) ...[Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 8)], Expanded(child: Text(message))]),
        backgroundColor: color,
        duration: Duration(seconds: duration),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
