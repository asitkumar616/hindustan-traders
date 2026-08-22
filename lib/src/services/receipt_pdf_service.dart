import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptLine {
  const ReceiptLine({required this.name, required this.quantity, required this.unit, required this.price, required this.amount});

  final String name;
  final num quantity;
  final String unit;
  final num price;
  final num amount;
}

/// Builds and hands off a printable receipt PDF for one order/invoice.
/// Shared by the owner's Invoice Review screen and the customer's Order
/// detail view -- same document shape, just different callers.
class ReceiptPdfService {
  static Future<Uint8List> buildReceipt({
    required String businessName,
    required String customerName,
    required String documentNumber,
    required DateTime date,
    required List<ReceiptLine> items,
    required num total,
    num? paid,
    num? balance,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(businessName, style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Receipt: $documentNumber'),
              pw.Text('Date: ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'),
              pw.SizedBox(height: 4),
              pw.Text('Customer: $customerName'),
              pw.Divider(height: 20),
              pw.Table(
                columnWidths: const {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(1.2),
                  2: pw.FlexColumnWidth(1.2),
                  3: pw.FlexColumnWidth(1.4),
                },
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.only(bottom: 6), child: pw.Text('Item', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.only(bottom: 6), child: pw.Text('Qty', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.only(bottom: 6), child: pw.Text('Price', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.only(bottom: 6), child: pw.Text('Amount', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  ...items.map(
                    (item) => pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4), child: pw.Text(item.name)),
                        pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4), child: pw.Text('${item.quantity} ${item.unit}')),
                        pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4), child: pw.Text('Rs ${item.price}')),
                        pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4), child: pw.Text('Rs ${item.amount}')),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Divider(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Total: Rs $total', style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    if (paid != null) pw.Text('Paid: Rs $paid'),
                    if (balance != null) pw.Text('Balance: Rs $balance'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  /// Opens the platform print/share sheet for the given PDF bytes -- lets
  /// the user print to a connected printer, save as a PDF, or share it,
  /// all from the one native dialog.
  static Future<void> printOrShare(Uint8List bytes, {required String fileName}) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: fileName);
  }
}
