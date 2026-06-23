import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:share_plus/share_plus.dart';

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

  /// Export all data to a JSON file and share it.
  Future<String> exportBackup() async {
    final data = await _buildBackupPayload();
    final jsonString = jsonEncode(data);
    
    final String tempDir;
    if (testTempPath != null) {
      tempDir = testTempPath!;
    } else {
      final directory = await getTemporaryDirectory();
      tempDir = directory.path;
    }

    final filename = 'sentery_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('$tempDir/$filename');
    await file.writeAsString(jsonString);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Sentery POS Data Backup — ${DateTime.now().toLocal().toString().split('.')[0]}',
    );

    return file.path;
  }

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

  /// Restore from a JSON backup file.
  Future<void> restoreBackup(String jsonContent) async {
    final Map<String, dynamic> data = jsonDecode(jsonContent);

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
