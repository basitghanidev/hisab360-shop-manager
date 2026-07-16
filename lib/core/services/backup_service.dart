import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

class BackupService {
  final AppDatabase _db;
  final String? testTempPath; // Allow injecting a temp path for unit tests

  BackupService(this._db, {this.testTempPath});

  // Hardcoded table names in dependency order for resilience across all DB types.
  static const List<String> _tableNames = [
    'app_settings',
    'suppliers',
    'wholesalers',
    'customers',
    'item_categories',
    'unit_types',
    'items',
    'wholesaler_item_prices',
    'price_log',
    'stock_batches',
    'stock_movements',
    'invoices',
    'invoice_items',
    'payments',
    'ledger_entries',
    'audit_logs',
    'draft_invoices',
  ];

  /// Creates the backup file and returns its path.
  /// Does NOT open a share sheet. Used by Google Drive upload and unit tests.
  Future<String> createBackupFile() async {
    final data = await _buildBackupPayload();
    final jsonString = jsonEncode(data);

    final String tempDir;
    if (testTempPath != null) {
      tempDir = testTempPath!;
    } else {
      final directory = await getTemporaryDirectory();
      tempDir = directory.path;
    }

    // Use a FIXED filename so each Drive sync overwrites the previous backup
    // instead of creating a new file every time (prevents Drive storage clutter).
    const filename = 'hisab360_backup.json';
    final file = File('$tempDir/$filename');
    await file.writeAsString(jsonString);
    return file.path;
  }

  /// Creates the backup file AND opens the OS share sheet (Mobile) or Save As (Desktop).
  /// Used by the "Manual Backup & Share" button only.
  Future<String> exportAndShare() async {
    final path = await createBackupFile();
    final file = File(path);

    if (!kIsWeb && Platform.isWindows) {
      // Professional "Save As" for Windows
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup File',
        fileName: 'hisab360_backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (outputFile != null) {
        await file.copy(outputFile);
      }
    } else {
      // Mobile: Standard share sheet
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Hisab360 Backup — ${DateTime.now().toLocal().toString().split('.')[0]}',
      );
    }

    return path;
  }

  /// Export all data to a JSON file and share it.
  Future<String> exportBackup() => exportAndShare();

  /// Helper for automated testing.
  Future<String> exportBackupAsString() async {
    final data = await _buildBackupPayload();
    return jsonEncode(data);
  }

  Future<Map<String, dynamic>> _buildBackupPayload() async {
    final Map<String, dynamic> payload = {
      'version': '3.0',
      'timestamp': DateTime.now().toIso8601String(),
    };

    for (final tableName in _tableNames) {
      payload[tableName] = await _getTableData(tableName);
    }

    return payload;
  }

  /// Read a table's rows as raw Maps using customSelect.
  Future<List<Map<String, dynamic>>> _getTableData(String tableName) async {
    try {
      final result = await _db.customSelect('SELECT * FROM "$tableName"').get();
      return result.map((row) {
        final rawData = row.data;
        final map = <String, dynamic>{};
        rawData.forEach((key, value) {
          if (value is DateTime) {
            map[key] = value.toIso8601String();
          } else {
            map[key] = value;
          }
        });
        return map;
      }).toList();
    } catch (e) {
      debugPrint('Error backing up table $tableName: $e');
      return [];
    }
  }

  /// Restore from a JSON backup file or string content.
  Future<void> restoreBackup(dynamic source) async {
    final Map<String, dynamic> data;
    if (source is String) {
      data = jsonDecode(source);
    } else if (source is File) {
      final content = await source.readAsString();
      data = jsonDecode(content);
    } else {
      throw ArgumentError('Source must be String or File');
    }

    await _db.transaction(() async {
      // Delete in reverse dependency order.
      for (final tableName in _tableNames.reversed) {
        try {
          await _db.customStatement('DELETE FROM "$tableName"');
        } catch (_) {} 
      }

      // Restore in dependency order.
      for (final tableName in _tableNames) {
        final rows = data[tableName];
        if (rows == null || rows is! List) continue;
        await _restoreTable(tableName, rows);
      }
    });
  }

  /// Insert rows into a table using raw SQL so types are preserved exactly.
  Future<void> _restoreTable(String tableName, List<dynamic> rows) async {
    for (final rowData in rows) {
      if (rowData is! Map) continue;
      final map = Map<String, dynamic>.from(rowData);
      if (map.isEmpty) continue;

      final cols = map.keys.map((k) => '"$k"').join(', ');
      final placeholders = List.filled(map.length, '?').join(', ');
      final variables = map.values.map((v) {
        if (v == null) return Variable<Object>(null);
        if (v is int) return Variable.withInt(v);
        if (v is double) return Variable.withReal(v);
        if (v is bool) return Variable.withInt(v ? 1 : 0);
        return Variable.withString(v.toString());
      }).toList();

      try {
        await _db.customInsert(
          'INSERT OR REPLACE INTO "$tableName" ($cols) VALUES ($placeholders)',
          variables: variables,
        );
      } catch (e) {
        debugPrint('Restore row failed for $tableName: $e');
      }
    }
  }
}
