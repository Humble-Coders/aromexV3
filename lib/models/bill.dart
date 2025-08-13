import 'package:aromex/models/bill_customer.dart';
import 'package:aromex/models/bill_item.dart';
import 'package:aromex/util.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Enum to define bill types
enum BillType { sale, purchase }

extension BillTypeExtension on BillType {
  String get displayName {
    switch (this) {
      case BillType.sale:
        return 'SALE INVOICE';
      case BillType.purchase:
        return 'PURCHASE INVOICE';
    }
  }
}

// Model class to hold admin information
class AdminInfo {
  final String storeName;
  final String storeAddress;
  final String storePhone;

  AdminInfo({
    required this.storeName,
    required this.storeAddress,
    required this.storePhone,
  });

  factory AdminInfo.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final address = data['address'] as Map<String, dynamic>;

    // Construct the store address from the address fields
    String storeAddress = '';
    if (address['line1'] != null && address['line1'].toString().isNotEmpty) {
      storeAddress += address['line1'].toString();
    }
    if (address['line2'] != null && address['line2'].toString().isNotEmpty) {
      if (storeAddress.isNotEmpty) storeAddress += ',\n';
      storeAddress += address['line2'].toString();
    }
    if (address['city'] != null && address['city'].toString().isNotEmpty) {
      if (storeAddress.isNotEmpty) storeAddress += ',\n';
      storeAddress += address['city'].toString();
    }
    if (address['state'] != null && address['state'].toString().isNotEmpty) {
      storeAddress += ', ${address['state']}';
    }
    if (address['postalCode'] != null &&
        address['postalCode'].toString().isNotEmpty) {
      storeAddress += ' ${address['postalCode']}';
    }

    return AdminInfo(
      storeName:
          "Aromex Communication", // You can also make this dynamic if needed
      storeAddress: storeAddress,
      storePhone: data['phone']?.toString() ?? "",
    );
  }
}

class Bill {
  final AdminInfo adminInfo;
  final DateTime time;
  final BillCustomer customer;
  final String orderNumber;
  List<BillItem> items;
  String? note;
  final double? adjustment;
  final BillType billType; // Added bill type

  Bill({
    required this.adminInfo,
    required this.time,
    required this.customer,
    required this.orderNumber,
    required this.items,
    this.adjustment,
    this.note,
    required this.billType, // Required bill type
  });

  // Getter methods for backward compatibility
  String get storeName => adminInfo.storeName;
  String get storeAddress => adminInfo.storeAddress;
  String get storePhone => adminInfo.storePhone;

  double get subtotal {
    return items.fold(0.0, (sum, item) => sum + item.totalPriceValue);
  }

  String get subtotalFormatted {
    return formatCurrency(subtotal, decimals: 2, showTrail: true);
  }

  double get total {
    return subtotal - (adjustment ?? 0.0);
  }

  String get totalFormatted {
    return formatCurrency(total, decimals: 2, showTrail: true);
  }

  String get adjustmentFormatted {
    return formatCurrency(adjustment ?? 0.0, decimals: 2, showTrail: true);
  }
}

// Service class to handle admin data fetching
class AdminService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<AdminInfo> getAdminInfo() async {
    try {
      final adminDoc =
          await _firestore.collection('AdminInfo').doc('admin').get();

      if (adminDoc.exists) {
        return AdminInfo.fromFirestore(adminDoc);
      } else {
        // Fallback to default values if admin document doesn't exist
        return AdminInfo(
          storeName: "Aromex Communication",
          storeAddress: "13898 64 Ave,\nUnit 101",
          storePhone: "+1 672-699-0009",
        );
      }
    } catch (e) {
      print('Error fetching admin info: $e');
      // Return default values in case of error
      return AdminInfo(
        storeName: "Aromex Communication",
        storeAddress: "13898 64 Ave,\nUnit 101",
        storePhone: "+1 672-699-0009",
      );
    }
  }
}

// Updated function to generate PDF with dynamic admin info
Future<void> generatePdfInvoice(Bill bill) async {
  final pdfData = await _generatePdfInvoice(bill);
  final fileName = "Invoice-${bill.orderNumber}-${formatDate(bill.time)}.pdf";
  print(fileName);
  await savePdfCrossPlatform(pdfData, fileName);
}

// Updated helper function to create a Bill with admin info and bill type
Future<Bill> createBillWithAdminInfo({
  required DateTime time,
  required BillCustomer customer,
  required String orderNumber,
  required List<BillItem> items,
  double? adjustment,
  String? note,
  required BillType billType, // Added required bill type parameter
}) async {
  final adminInfo = await AdminService.getAdminInfo();

  return Bill(
    adminInfo: adminInfo,
    time: time,
    customer: customer,
    orderNumber: orderNumber,
    items: items,
    adjustment: adjustment,
    note: note,
    billType: billType, // Pass bill type
  );
}

Future<void> savePdfCrossPlatform(Uint8List bytes, String fileName) async {
  try {
    if (kIsWeb) {
      // Web platform
      final file = XFile.fromData(
        bytes,
        name: fileName,
        mimeType: 'application/pdf',
      );
      await file.saveTo(file.name);
    } else {
      // Desktop platforms (Windows, macOS, Linux)
      final location = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: [
          const XTypeGroup(label: 'PDF files', extensions: ['pdf']),
        ],
      );

      if (location != null) {
        // Write the file directly using dart:io
        final file = File(location.path);
        await file.writeAsBytes(bytes);
        print('PDF saved successfully to: ${location.path}');
      } else {
        print('Save operation was cancelled by user');
      }
    }
  } catch (e) {
    print('Error saving PDF: $e');
    rethrow;
  }
}

Future<Uint8List> _generatePdfInvoice(Bill bill) async {
  final pdf = pw.Document();

  final baseTextStyle = pw.TextStyle(fontSize: 10);
  final bold = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
  final title = pw.TextStyle(
    fontSize: 24,
    color: PdfColors.blue900,
    fontWeight: pw.FontWeight.bold,
  );
  final billTypeStyle = pw.TextStyle(
    fontSize: 14,
    fontWeight: pw.FontWeight.bold,
    color:
        bill.billType == BillType.sale
            ? PdfColors.green800
            : PdfColors.orange800,
  );

  pdf.addPage(
    pw.MultiPage(
      margin: const pw.EdgeInsets.all(32),
      footer:
          (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: baseTextStyle,
            ),
          ),
      build:
          (context) => [
            /// Header
            pw.Text(bill.storeName, style: bold.copyWith(fontSize: 14)),
            pw.Text(bill.storeAddress, style: baseTextStyle),
            pw.Text(bill.storePhone, style: baseTextStyle),
            pw.SizedBox(height: 16),

            /// Invoice Title + Bill Type + Metadata
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Invoice', style: title),
                pw.SizedBox(height: 8),
                // Added bill type line
                pw.Text(bill.billType.displayName, style: billTypeStyle),
                pw.SizedBox(height: 4),
                pw.Text(
                  formatDate(bill.time),
                  style: pw.TextStyle(color: PdfColors.red, fontSize: 12),
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          bill.billType == BillType.sale
                              ? 'Invoice for'
                              : 'Purchase from',
                          style: bold,
                        ),
                        pw.Text(bill.customer.name, style: baseTextStyle),
                        pw.Text(bill.customer.address, style: baseTextStyle),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Invoice #', style: bold),
                        pw.Text(bill.orderNumber, style: baseTextStyle),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            /// Table Header
            pw.Container(
              color: PdfColors.grey300,
              padding: pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text("Description", style: bold),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      "Qty",
                      style: bold,
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      "Unit price",
                      style: bold,
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      "Total price",
                      style: bold,
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),

            /// Product Rows
            ...bill.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isEven = index % 2 == 1;
              final bgColor = isEven ? PdfColors.grey100 : PdfColors.white;

              return pw.Container(
                color: bgColor,
                padding: pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 4,
                      child: pw.Text(
                        item.title,
                        style: baseTextStyle,
                        softWrap: true,
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        "${item.quantity}",
                        textAlign: pw.TextAlign.right,
                        style: baseTextStyle,
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        item.unitPrice,
                        textAlign: pw.TextAlign.right,
                        style: baseTextStyle,
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        item.totalPrice,
                        textAlign: pw.TextAlign.right,
                        style: baseTextStyle,
                      ),
                    ),
                  ],
                ),
              );
            }),

            pw.SizedBox(height: 8),
            pw.Divider(),

            /// Notes
            if (bill.note != null)
              pw.Text("Notes: ${bill.note}", style: baseTextStyle),
            pw.SizedBox(height: 16),

            /// Totals
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text("Subtotal:  ", style: bold),
                        pw.Text(bill.subtotalFormatted),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.Text("Adjustments:  ", style: bold),
                        pw.Text(bill.adjustmentFormatted),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      bill.totalFormatted,
                      style: bold.copyWith(
                        fontSize: 18,
                        color: PdfColors.pink800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
    ),
  );

  return pdf.save();
}
