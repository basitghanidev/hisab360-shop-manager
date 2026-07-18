import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sentery_app/core/services/backup_service.dart';
import 'package:sentery_app/core/database/app_database.dart';

class DesktopLifecycleService with WindowListener {
  final AppDatabase db;
  DesktopLifecycleService(this.db);

  Future<void> init() async {
    // CRITICAL FIX: Avoid Platform check on Web
    if (!kIsWeb && io.Platform.isWindows) {
      await windowManager.ensureInitialized();
      windowManager.addListener(this);
      // Prevent automatic exit so we can backup first
      await windowManager.setPreventClose(true);
    }
  }

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      try {
        debugPrint('[Lifecycle] App closing, starting auto-backup...');
        final backupService = BackupService(db);
        await backupService.createBackupFile();
        debugPrint('[Lifecycle] Auto-backup completed successfully.');
      } catch (e) {
        debugPrint('[Lifecycle] Auto-backup failed: $e');
      } finally {
        await windowManager.destroy();
      }
    }
  }
}
