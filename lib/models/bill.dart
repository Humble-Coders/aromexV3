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
      storeName: "Aromex Communication",
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
  final BillType billType;
  final double gst;
  final double pst;
  final double cashPaid;
  final double cardPaid;
  final double bankPaid;

  Bill({
    required this.adminInfo,
    required this.time,
    required this.customer,
    required this.orderNumber,
    required this.items,
    this.adjustment,
    this.note,
    required this.billType,
    this.gst = 0.0,
    this.pst = 0.0,
    this.bankPaid = 0.0,
    this.cardPaid = 0.0,
    this.cashPaid = 0.0,
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

  // Calculate GST amount from percentage
  double get gstAmount {
    return subtotal * (gst / 100);
  }

  // Calculate PST amount from percentage
  double get pstAmount {
    return subtotal * (pst / 100);
  }

  String get gstFormatted {
    return formatCurrency(gstAmount, decimals: 2, showTrail: true);
  }

  String get pstFormatted {
    return formatCurrency(pstAmount, decimals: 2, showTrail: true);
  }

  String get gstPercentageFormatted {
    return "${gst.toStringAsFixed(1)}%";
  }

  String get pstPercentageFormatted {
    return "${pst.toStringAsFixed(1)}%";
  }

  double get totalTax {
    return gstAmount + pstAmount;
  }

  String get totalTaxFormatted {
    return formatCurrency(totalTax, decimals: 2, showTrail: true);
  }

  double get total {
    return subtotal + totalTax - (adjustment ?? 0.0);
  }

  String get totalFormatted {
    return formatCurrency(total, decimals: 2, showTrail: true);
  }

  String get adjustmentFormatted {
    return formatCurrency(adjustment ?? 0.0, decimals: 2, showTrail: true);
  }

  String get cashPaidFormatted {
    return formatCurrency(cashPaid, decimals: 2, showTrail: true);
  }

  String get cardPaidFormatted {
    return formatCurrency(cardPaid, decimals: 2, showTrail: true);
  }

  String get bankPaidFormatted {
    return formatCurrency(bankPaid, decimals: 2, showTrail: true);
  }

  double get totalPaid {
    return cashPaid + cardPaid + bankPaid;
  }

  String get totalPaidFormatted {
    return formatCurrency(totalPaid, decimals: 2, showTrail: true);
  }

  double get balanceDue {
    return total - totalPaid;
  }

  String get balanceDueFormatted {
    return formatCurrency(balanceDue, decimals: 2, showTrail: true);
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
        return AdminInfo(
          storeName: "Aromex Communication",
          storeAddress: "13898 64 Ave,\nUnit 101",
          storePhone: "+1 672-699-0009",
        );
      }
    } catch (e) {
      print('Error fetching admin info: $e');
      return AdminInfo(
        storeName: "Aromex Communication",
        storeAddress: "13898 64 Ave,\nUnit 101",
        storePhone: "+1 672-699-0009",
      );
    }
  }
}

Future<void> generatePdfInvoice(Bill bill) async {
  final pdfData = await _generatePdfInvoice(bill);
  final fileName = "Invoice-${bill.orderNumber}-${formatDate(bill.time)}.pdf";
  print(fileName);
  await savePdfCrossPlatform(pdfData, fileName);
}

Future<Bill> createBillWithAdminInfo({
  required DateTime time,
  required BillCustomer customer,
  required String orderNumber,
  required List<BillItem> items,
  double? adjustment,
  String? note,
  required BillType billType,
  double gst = 0.0,
  double pst = 0.0,
  double cashPaid = 0.0,
  double bankPaid = 0.0,
  double cardPaid = 0.0,
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
    billType: billType,
    cashPaid: cashPaid,
    bankPaid: bankPaid,
    cardPaid: cardPaid,
    gst: gst,
    pst: pst,
  );
}

Future<void> savePdfCrossPlatform(Uint8List bytes, String fileName) async {
  try {
    if (kIsWeb) {
      final file = XFile.fromData(
        bytes,
        name: fileName,
        mimeType: 'application/pdf',
      );
      await file.saveTo(file.name);
    } else {
      final location = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: [
          const XTypeGroup(label: 'PDF files', extensions: ['pdf']),
        ],
      );

      if (location != null) {
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
  final sectionHeader = pw.TextStyle(
    fontSize: 12,
    fontWeight: pw.FontWeight.bold,
    color: PdfColors.blue800,
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
            /// Header Section
            pw.Container(
              padding: pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blue900, width: 2),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        bill.storeName,
                        style: bold.copyWith(fontSize: 16),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(bill.storeAddress, style: baseTextStyle),
                      pw.Text(bill.storePhone, style: baseTextStyle),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Invoice', style: title),
                      pw.Text(bill.billType.displayName, style: billTypeStyle),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            /// Invoice Details Section
            pw.Container(
              padding: pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        bill.billType == BillType.sale
                            ? 'Invoice To:'
                            : 'Purchase From:',
                        style: bold.copyWith(fontSize: 12),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(bill.customer.name, style: baseTextStyle),
                      pw.Text(bill.customer.address, style: baseTextStyle),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text('Invoice #: ', style: bold),
                          pw.Text(bill.orderNumber, style: baseTextStyle),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text('Date: ', style: bold),
                          pw.Text(formatDate(bill.time), style: baseTextStyle),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            /// Items Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: pw.FlexColumnWidth(4),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(2),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.blue900),
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(
                        "Description",
                        style: bold.copyWith(color: PdfColors.white),
                      ),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(
                        "Qty",
                        style: bold.copyWith(color: PdfColors.white),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(
                        "Unit Price",
                        style: bold.copyWith(color: PdfColors.white),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text(
                        "Taxable Value",
                        style: bold.copyWith(color: PdfColors.white),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                // Item rows
                ...bill.items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isEven = index % 2 == 0;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isEven ? PdfColors.white : PdfColors.grey50,
                    ),
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(item.title, style: baseTextStyle),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          "${item.quantity}",
                          style: baseTextStyle,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          item.unitPrice,
                          style: baseTextStyle,
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          item.totalPrice,
                          style: baseTextStyle,
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),

            /// Notes Section
            if (bill.note != null && bill.note!.isNotEmpty)
              pw.Container(
                width: double.infinity,
                padding: pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.yellow50,
                  border: pw.Border.all(color: PdfColors.yellow300),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Notes:", style: bold),
                    pw.SizedBox(height: 4),
                    pw.Text(bill.note!, style: baseTextStyle),
                  ],
                ),
              ),
            if (bill.note != null && bill.note!.isNotEmpty)
              pw.SizedBox(height: 20),

            /// Financial Summary Section
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                /// Payment Details (Left Side)
                pw.Expanded(
                  flex: 1,
                  child: pw.Container(
                    padding: pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Payment Details", style: sectionHeader),
                        pw.SizedBox(height: 8),
                        _buildPaymentRow(
                          "Cash Paid:",
                          bill.cashPaidFormatted,
                          bill.cashPaid > 0,
                        ),
                        _buildPaymentRow(
                          "Card Paid:",
                          bill.cardPaidFormatted,
                          bill.cardPaid > 0,
                        ),
                        _buildPaymentRow(
                          "Bank Transfer:",
                          bill.bankPaidFormatted,
                          bill.bankPaid > 0,
                        ),
                        pw.Divider(),
                        _buildPaymentRow(
                          "Total Paid:",
                          bill.totalPaidFormatted,
                          true,
                          isBold: true,
                        ),
                        pw.SizedBox(height: 8),
                        if (bill.balanceDue != 0)
                          _buildPaymentRow(
                            bill.balanceDue > 0
                                ? "Balance Due:"
                                : "Overpayment:",
                            bill.balanceDueFormatted,
                            true,
                            isBold: true,
                            textColor:
                                bill.balanceDue > 0
                                    ? PdfColors.red800
                                    : PdfColors.green800,
                          ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 20),

                /// Invoice Summary (Right Side)
                pw.Expanded(
                  flex: 1,
                  child: pw.Container(
                    padding: pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("Invoice Summary", style: sectionHeader),
                        pw.SizedBox(height: 8),
                        _buildSummaryRow(
                          "Taxable Amount:",
                          bill.subtotalFormatted,
                        ),
                        if (bill.gst > 0)
                          _buildSummaryRow(
                            "GST (${bill.gstPercentageFormatted}):",
                            bill.gstFormatted,
                          ),
                        if (bill.pst > 0)
                          _buildSummaryRow(
                            "PST (${bill.pstPercentageFormatted}):",
                            bill.pstFormatted,
                          ),
                        if (bill.totalTax > 0)
                          _buildSummaryRow(
                            "Total Tax:",
                            bill.totalTaxFormatted,
                          ),
                        if (bill.adjustment != null && bill.adjustment! != 0)
                          _buildSummaryRow(
                            "Adjustments:",
                            bill.adjustmentFormatted,
                          ),
                        pw.Divider(),
                        pw.Container(
                          padding: pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue50,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                "SUBTOTAL:",
                                style: bold.copyWith(fontSize: 14),
                              ),
                              pw.Text(
                                bill.totalFormatted,
                                style: bold.copyWith(
                                  fontSize: 16,
                                  color: PdfColors.blue900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            /// Footer Section
            pw.Container(
              width: double.infinity,
              padding: pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    "This is an electronically generated invoice",
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    "No signature required",
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey700,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
    ),
  );

  return pdf.save();
}

// Helper function to build payment rows
pw.Widget _buildPaymentRow(
  String label,
  String amount,
  bool show, {
  bool isBold = false,
  PdfColor? textColor,
}) {
  if (!show && !isBold) return pw.SizedBox.shrink();

  final textStyle = pw.TextStyle(
    fontSize: 10,
    fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
    color: textColor ?? PdfColors.black,
  );

  return pw.Padding(
    padding: pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: textStyle),
        pw.Text(amount, style: textStyle),
      ],
    ),
  );
}

// Helper function to build summary rows
pw.Widget _buildSummaryRow(String label, String amount) {
  return pw.Padding(
    padding: pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 10)),
        pw.Text(amount, style: pw.TextStyle(fontSize: 10)),
      ],
    ),
  );
}
