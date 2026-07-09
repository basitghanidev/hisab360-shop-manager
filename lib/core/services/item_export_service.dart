import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/money_utils.dart';
import 'package:share_plus/share_plus.dart';

class ItemExportService {
  final AppDatabase _db;
  ItemExportService(this._db);

  Future<void> exportToExcel() async {
    final items = await _db.itemDao.getAllItems();
    final categories = await _db.itemDao.watchCategories().first;
    final categoryMap = {for (var c in categories) c.id: c.name};

    final excel = Excel.createExcel();
    final sheet = excel.sheets[excel.getDefaultSheet()!]!;

    // Header
    sheet.appendRow([
      TextCellValue('Name'),
      TextCellValue('Code'),
      TextCellValue('Purchase Price'),
      TextCellValue('Retail Price'),
      TextCellValue('Stock'),
      TextCellValue('Category'),
    ]);

    for (final item in items) {
      sheet.appendRow([
        TextCellValue(item.name),
        TextCellValue(item.itemCode ?? ''),
        DoubleCellValue(Money.fromPaisa(item.purchasePrice).toDouble()),
        DoubleCellValue(Money.fromPaisa(item.retailPrice).toDouble()),
        DoubleCellValue(item.currentStock),
        TextCellValue(categoryMap[item.categoryId] ?? ''),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/items_export_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles([XFile(file.path)], text: 'Hisab360 Inventory Export (Excel)');
  }

  Future<void> exportToCsv() async {
    final items = await _db.itemDao.getAllItems();
    final categories = await _db.itemDao.watchCategories().first;
    final categoryMap = {for (var c in categories) c.id: c.name};

    List<List<dynamic>> rows = [];
    
    // Header
    rows.add(['Name', 'Code', 'Purchase Price', 'Retail Price', 'Stock', 'Category']);

    for (final item in items) {
      rows.add([
        item.name,
        item.itemCode ?? '',
        Money.fromPaisa(item.purchasePrice).toDouble(),
        Money.fromPaisa(item.retailPrice).toDouble(),
        item.currentStock,
        categoryMap[item.categoryId] ?? '',
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/items_export_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csvData);

    await Share.shareXFiles([XFile(file.path)], text: 'Hisab360 Inventory Export (CSV)');
  }
}
