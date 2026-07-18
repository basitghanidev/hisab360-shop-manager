import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sentery_app/core/services/backup_service.dart';
import 'package:sentery_app/core/database/app_database.dart';

/// Professional service to handle Windows-specific events.
/// This class is refactored to be safe for Web.
class DesktopLifecycleService extends WindowListener {
  final AppDatabase db;
  DesktopLifecycleService(this.db);

  Future<void> init() async {
    // CRITICAL FIX: Ensure NO window_manager code is ever touched on Web
    if (kIsWeb) {
      debugPrint('[Lifecycle] Running on Web - Desktop safety active.');
      return;
    }

    if (io.Platform.isWindows) {
      await windowManager.ensureInitialized();
      windowManager.addListener(this);
      await windowManager.setPreventClose(true);
      debugPrint('[Lifecycle] Windows Protection Live.');
    }
  }

  @override
  void onWindowClose() async {
    if (kIsWeb) return;

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
