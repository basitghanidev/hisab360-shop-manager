import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:excel/excel.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/money_utils.dart';

class ItemImportService {
  final AppDatabase _db;
  ItemImportService(this._db);

  Future<ImportResult> importFromFile(File file) async {
    final extension = file.path.split('.').last.toLowerCase();
    
    try {
      if (extension == 'xlsx') {
        return _importFromExcel(file);
      } else if (extension == 'csv') {
        return _importFromCsv(file);
      } else {
        return ImportResult.failure('Unsupported file format. Please use .xlsx or .csv');
      }
    } catch (e) {
      return ImportResult.failure('Import error: $e');
    }
  }

  Future<ImportResult> _importFromExcel(File file) async {
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    
    final sheetName = excel.tables.keys.first;
    final table = excel.tables[sheetName]!;
    
    if (table.maxRows <= 1) return ImportResult.failure('The file is empty.');

    int successCount = 0;
    int failCount = 0;

    // Assuming Header: Name, Code, Purchase Price, Retail Price, Stock, Category
    for (int i = 1; i < table.maxRows; i++) {
      final row = table.rows[i];
      if (row.isEmpty) continue;

      final success = await _processRow(
        name: row[0]?.value?.toString(),
        code: row[1]?.value?.toString(),
        purchasePrice: row[2]?.value?.toString(),
        retailPrice: row[3]?.value?.toString(),
        stock: row[4]?.value?.toString(),
        categoryName: row[5]?.value?.toString(),
      );

      if (success) successCount++; else failCount++;
    }

    return ImportResult.success(successCount, failCount);
  }

  Future<ImportResult> _importFromCsv(File file) async {
    final input = file.openRead();
    final fields = await input.transform(utf8.decoder).transform(const CsvToListConverter()).toList();

    if (fields.length <= 1) return ImportResult.failure('The file is empty.');

    int successCount = 0;
    int failCount = 0;

    for (int i = 1; i < fields.length; i++) {
      final row = fields[i];
      if (row.isEmpty) continue;

      final success = await _processRow(
        name: row[0]?.toString(),
        code: row[1]?.toString(),
        purchasePrice: row[2]?.toString(),
        retailPrice: row[3]?.toString(),
        stock: row[4]?.toString(),
        categoryName: row[5]?.toString(),
      );

      if (success) successCount++; else failCount++;
    }

    return ImportResult.success(successCount, failCount);
  }

  Future<bool> _processRow({
    String? name,
    String? code,
    String? purchasePrice,
    String? retailPrice,
    String? stock,
    String? categoryName,
  }) async {
    if (name == null || name.trim().isEmpty) return false;

    try {
      final pPaisa = Money.fromDouble(double.tryParse(purchasePrice ?? '0') ?? 0).paisa;
      final rPaisa = Money.fromDouble(double.tryParse(retailPrice ?? '0') ?? 0).paisa;
      final currentStock = double.tryParse(stock ?? '0') ?? 0.0;

      int? categoryId;
      if (categoryName != null && categoryName.trim().isNotEmpty) {
        // Try to find category or create it
        final existing = await (_db.select(_db.itemCategories)..where((t) => t.name.equals(categoryName.trim()))).getSingleOrNull();
        if (existing != null) {
          categoryId = existing.id;
        } else {
          categoryId = await _db.into(_db.itemCategories).insert(ItemCategoriesCompanion.insert(name: categoryName.trim()));
        }
      }

      // Get default unit type or create one
      int? unitTypeId;
      final defaultUnit = await (_db.select(_db.unitTypes)..limit(1)).getSingleOrNull();
      if (defaultUnit != null) {
        unitTypeId = defaultUnit.id;
      } else {
        unitTypeId = await _db.into(_db.unitTypes).insert(const UnitTypesCompanion(name: Value('Piece')));
      }

      await _db.itemDao.insertItem(ItemsCompanion.insert(
        name: name.trim(),
        itemCode: Value(code?.trim()),
        purchasePrice: Value(pPaisa),
        retailPrice: Value(rPaisa),
        currentStock: Value(currentStock),
        categoryId: Value(categoryId),
        unitTypeId: unitTypeId,
        isActive: const Value(true),
      ));
      
      return true;
    } catch (_) {
      return false;
    }
  }
}

class ImportResult {
  final bool success;
  final int count;
  final int failed;
  final String? message;

  ImportResult.success(this.count, this.failed) : success = true, message = null;
  ImportResult.failure(this.message) : success = false, count = 0, failed = 0;
}
