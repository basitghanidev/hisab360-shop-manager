import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sentery_app/core/database/app_database.dart';
import 'package:sentery_app/core/utils/currency_formatter.dart';
import 'package:sentery_app/core/constants/app_strings.dart';

class InvoicePdfService {
  final AppDatabase db;
  InvoicePdfService(this.db);

  Future<Uint8List> generateInvoicePdf(int invoiceId) async {
    try {
      final invoice = await db.invoiceDao.getInvoiceById(invoiceId);
      if (invoice == null) throw Exception('Invoice not found');
      final items = await db.invoiceDao.getInvoiceItems(invoiceId);
      
      final settings = await db.settingsDao.getSettings();
      final pageSize = settings?.pdfPageSize ?? 'A4';

      String partyName = invoice.partyNameSnapshot ?? AppStrings.walkInCustomer;
      String partyType = invoice.partyTypeSnapshot ?? AppStrings.customer;

      final pdf = pw.Document();

      final pageFormat = _getPageFormat(pageSize);

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pageSize == 'A4' ? const pw.EdgeInsets.all(32) : const pw.EdgeInsets.all(8),
          build: (pw.Context context) {
            if (invoice.invoiceType.contains('_payment_receipt')) {
              return _buildReceiptPdfContent(invoice, partyName, partyType, pageSize);
            }
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(AppStrings.appName, style: pw.TextStyle(fontSize: pageSize == 'A4' ? 24 : 18, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Professional Shop Management', style: pw.TextStyle(fontSize: pageSize == 'A4' ? 12 : 9)),
                    ],
                  ),
                ),
                pw.SizedBox(height: pageSize == 'A4' ? 24 : 12),
                
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Invoice #: ${invoice.invoiceNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Text('Date: ${invoice.invoiceDate.toString().split(' ')[0]}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.SizedBox(height: 8),

                pw.Text('Bill To: $partyName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                pw.Text('Type: $partyType', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                
                pw.SizedBox(height: 12),
                pw.Divider(thickness: 1),

                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: pageSize == 'A4' ? 10 : 8),
                  cellStyle: pw.TextStyle(fontSize: pageSize == 'A4' ? 9 : 7),
                  headers: pageSize == 'A4' ? ['#', 'Item Name', 'Qty', 'Rate', 'Total'] : ['Item', 'Qty', 'Rate', 'Total'],
                  data: List.generate(items.length, (index) {
                    final i = items[index];
                    final row = [
                      i.itemNameSnapshot,
                      '${i.quantity} ${i.unitTypeSnapshot}',
                      CurrencyFormatter.formatPaisa(i.salePrice),
                      CurrencyFormatter.formatPaisa(i.lineTotal),
                    ];
                    if (pageSize == 'A4') {
                      row.insert(0, (index + 1).toString());
                    }
                    return row;
                  }),
                ),
                pw.Divider(thickness: 1),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: pageSize == 'A4' ? 200 : 160,
                      child: pw.Column(
                        children: [
                          _buildSummaryRow(AppStrings.previousBalance, invoice.previousBalance, fontSize: pageSize == 'A4' ? 10 : 8),
                          _buildSummaryRow(AppStrings.newBill, invoice.totalAmount, fontSize: pageSize == 'A4' ? 10 : 8),
                          _buildSummaryRow(AppStrings.paidToday, invoice.amountPaid, fontSize: pageSize == 'A4' ? 10 : 8),
                          pw.Divider(thickness: 0.5),
                          _buildSummaryRow(AppStrings.totalRemaining, invoice.totalBalanceAfter, isBold: true, fontSize: pageSize == 'A4' ? 11 : 9),
                        ],
                      ),
                    ),
                  ],
                ),
                
                if (invoice.notes != null) ...[
                  pw.SizedBox(height: 12),
                  pw.Text('Notes:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.Text(invoice.notes!, style: const pw.TextStyle(fontSize: 8)),
                ],

                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text('Thank you for your business!', 
                    style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
                ),
              ],
            );
          },
        ),
      );

      return pdf.save();
    } catch (e) {
      debugPrint('[PDF] Critical error during generation: $e');
      rethrow;
    }
  }

  PdfPageFormat _getPageFormat(String pageSize) {
    switch (pageSize) {
      case 'Roll80':
        return const PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 5 * PdfPageFormat.mm,
        );
      case 'Roll58':
        return const PdfPageFormat(
          58 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 3 * PdfPageFormat.mm,
        );
      case 'A4':
      default:
        return PdfPageFormat.a4;
    }
  }

  pw.Widget _buildSummaryRow(String label, int paisa, {bool isBold = false, double fontSize = 10}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(CurrencyFormatter.formatPaisa(paisa), style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  pw.Widget _buildReceiptPdfContent(Invoice invoice, String partyName, String partyType, String pageSize) {
    final bool isA4 = pageSize == 'A4';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(AppStrings.appName, style: pw.TextStyle(fontSize: isA4 ? 24 : 18, fontWeight: pw.FontWeight.bold)),
              pw.Text('Payment Receipt / Adaigi ki Raseed', style: pw.TextStyle(fontSize: isA4 ? 12 : 9)),
            ],
          ),
        ),
        pw.SizedBox(height: isA4 ? 24 : 12),

        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Receipt #: ${invoice.invoiceNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.Text('Date: ${invoice.invoiceDate.toString().split(' ')[0]}', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
        pw.SizedBox(height: 12),

        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Received From / Paid To:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.Text(partyName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.Text('Type: ${partyType.toUpperCase()}', style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        pw.Text('PAYMENT DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.Divider(),
        _buildSummaryRowRaw('Payment Method', (invoice.paymentMethod ?? 'Cash').toUpperCase(), fontSize: isA4 ? 10 : 8),
        if (invoice.onlineMethod != null)
          _buildSummaryRowRaw('Online Method', invoice.onlineMethod!.toUpperCase(), fontSize: isA4 ? 10 : 8),
        if (invoice.transactionId != null)
          _buildSummaryRowRaw('Transaction ID', invoice.transactionId!, fontSize: isA4 ? 10 : 8),
        pw.SizedBox(height: 12),

        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
          child: pw.Column(
            children: [
              _buildSummaryRow('Previous Balance', invoice.receiptPreviousRemaining ?? 0, fontSize: isA4 ? 10 : 8),
              _buildSummaryRow('Amount Paid Today', invoice.totalAmount, isBold: true, fontSize: isA4 ? 11 : 9),
              pw.Divider(thickness: 0.5),
              _buildSummaryRow('Net Balance After', invoice.receiptFinalRemaining ?? 0, isBold: true, fontSize: isA4 ? 11 : 9),
            ],
          ),
        ),

        if (invoice.notes != null) ...[
          pw.SizedBox(height: 12),
          pw.Text('Notes:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          pw.Text(invoice.notes!, style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
        ],

        pw.Spacer(),
        pw.Column(
          children: [
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Thank you for your business!',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
                pw.Text(
                  'Powered by Basit Ghani',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildSummaryRowRaw(String label, String value, {bool isBold = false, double fontSize = 10}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  Future<void> previewInvoice(int invoiceId) async {
    final bytes = await generateInvoicePdf(invoiceId);
    
    if (Platform.isIOS) {
      // iOS: print/share dialog via Printing — works natively
      await Printing.layoutPdf(onLayout: (format) => bytes);
    } else {
      // Android: share via OS share sheet — much more user-friendly
      await shareInvoice(invoiceId);
    }
  }

  Future<void> printInvoice(int invoiceId) async {
    final bytes = await generateInvoicePdf(invoiceId);
    await Printing.layoutPdf(onLayout: (format) => bytes);
  }

  Future<void> shareInvoice(int invoiceId) async {
    final bytes = await generateInvoicePdf(invoiceId);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/Invoice_$invoiceId.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Shop Management - Bill Share',
    );
  }
}
