import 'dart:io' as io;
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentery_app/core/constants/app_strings.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
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

    if (!kIsWeb) {
      final tempDir = await getTemporaryDirectory();
      final file = io.File('${tempDir.path}/items_export_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Hisab360 Inventory Export (Excel)');
    } else {
      debugPrint('[Export] Excel download not yet implemented for browser.');
    }
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

    if (!kIsWeb) {
      final tempDir = await getTemporaryDirectory();
      final file = io.File('${tempDir.path}/items_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvData);
      await Share.shareXFiles([XFile(file.path)], text: 'Hisab360 Inventory Export (CSV)');
    } else {
      debugPrint('[Export] CSV download not yet implemented for browser.');
    }
  }

  Future<void> exportToPdf() async {
    final items = await _db.itemDao.getAllItems();
    final categories = await _db.itemDao.watchCategories().first;
    final categoryMap = {for (var c in categories) c.id: c.name};
    final unitTypes = await _db.itemDao.watchUnitTypes().first;
    final unitTypeMap = {for (var u in unitTypes) u.id: u.name};

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(AppStrings.appName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Inventory Report', style: const pw.TextStyle(fontSize: 14)),
                  ],
                ),
                pw.Text('Date: ${DateTime.now().toString().split(' ')[0]}'),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
          ],
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headers: ['#', 'Item Name', 'Code', 'Category', 'Retail Price', 'Stock'],
            data: List.generate(items.length, (index) {
              final item = items[index];
              final unitName = unitTypeMap[item.unitTypeId] ?? '';
              return [
                (index + 1).toString(),
                item.name,
                item.itemCode ?? '-',
                categoryMap[item.categoryId] ?? '-',
                CurrencyFormatter.formatPaisa(item.retailPrice),
                '${item.currentStock} $unitName',
              ];
            }),
          ),
        ],
        footer: (context) => pw.Column(
          children: [
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Powered by Basit Ghani', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      name: 'Inventory_Report_${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}
