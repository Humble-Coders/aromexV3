import 'dart:convert';
import 'package:aromex/models/balance_generic.dart';
import 'package:aromex/models/generic_firebase_object.dart';
import 'package:aromex/models/bill.dart';
import 'package:aromex/models/bill_customer.dart';
import 'package:aromex/models/bill_item.dart';
import 'package:aromex/models/supplier.dart';
import 'package:aromex/models/phone.dart';
import 'package:aromex/models/phone_brand.dart';
import 'package:aromex/models/phone_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Purchase extends GenericFirebaseObject<Purchase> {
  final String orderNumber;
  final DateTime date;
  final DocumentReference supplierRef;
  final List<DocumentReference> phones;
  final double amount;
  final double gst;
  final double pst;
  final BalanceType? paymentSource;
  final double total;
  final double paid;
  final double credit;
  final String supplierName;

  // Payment fields - using consistent naming
  final double? bankPaid;
  final double? cardPaid;
  final double? cashPaid;

  Purchase({
    super.id,
    super.snapshot,
    required this.orderNumber,
    required this.phones,
    required this.supplierRef,
    required this.amount,
    required this.gst,
    required this.pst,
    this.paymentSource = BalanceType.cash,
    required this.date,
    this.total = 0.0,
    this.paid = 0.0,
    this.credit = 0.0,
    required this.supplierName,
    this.bankPaid,
    this.cardPaid,
    this.cashPaid,
  });

  static const collectionName = "Purchases";

  @override
  String get collName => collectionName;

  @override
  Map<String, dynamic> toFirestore() {
    Map<String, dynamic> data = {
      "orderNumber": orderNumber,
      "phones": phones,
      "supplierId": supplierRef,
      "amount": amount,
      "gst": gst,
      "pst": pst,
      "date": date,
      "total": total,
      "paid": paid,
      "credit": credit,
      "supplierName": supplierName,
    };

    // Add payment source if not null
    if (paymentSource != null) {
      data["paymentSource"] = paymentSource.toString().split('.').last;
    }

    // Add payment fields if they are not null and greater than 0
    if (bankPaid != null && bankPaid! > 0) {
      data["bankPaid"] = bankPaid!;
    }
    if (cardPaid != null && cardPaid! > 0) {
      data["cardPaid"] = cardPaid!;
    }
    if (cashPaid != null && cashPaid! > 0) {
      data["cashPaid"] = cashPaid!;
    }

    return data;
  }

  factory Purchase.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data();
      if (data == null) {
        throw ArgumentError('Document data is null for Purchase ${doc.id}');
      }

      final purchaseData = data as Map<String, dynamic>;

      return Purchase(
        id: doc.id,
        orderNumber: purchaseData["orderNumber"] ?? '',
        phones:
            (purchaseData['phones'] as List<dynamic>?)
                ?.cast<DocumentReference>() ??
            [],
        supplierRef:
            purchaseData["supplierId"] ??
            FirebaseFirestore.instance.collection('Suppliers').doc('default'),
        amount: (purchaseData["amount"] as num?)?.toDouble() ?? 0.0,
        gst: (purchaseData["gst"] as num?)?.toDouble() ?? 0.0,
        pst: (purchaseData["pst"] as num?)?.toDouble() ?? 0.0,
        paymentSource:
            purchaseData["paymentSource"] != null
                ? BalanceType.values.firstWhere(
                  (type) =>
                      type.toString() ==
                      'BalanceType.${purchaseData["paymentSource"]}',
                  orElse: () => BalanceType.cash,
                )
                : BalanceType.cash,
        date: (purchaseData["date"] as Timestamp?)?.toDate() ?? DateTime.now(),
        total: (purchaseData["total"] as num?)?.toDouble() ?? 0.0,
        paid: (purchaseData["paid"] as num?)?.toDouble() ?? 0.0,
        credit: (purchaseData["credit"] as num?)?.toDouble() ?? 0.0,
        snapshot: doc,
        supplierName: purchaseData["supplierName"] ?? "",
        // Payment field mapping - consistent with field names
        bankPaid:
            purchaseData["bankPaid"] != null
                ? (purchaseData["bankPaid"] as num).toDouble()
                : null,
        cardPaid:
            purchaseData["cardPaid"] != null
                ? (purchaseData["cardPaid"] as num).toDouble()
                : null,
        cashPaid:
            purchaseData["cashPaid"] != null
                ? (purchaseData["cashPaid"] as num).toDouble()
                : null,
      );
    } catch (e) {
      print('Error creating Purchase from Firestore document ${doc.id}: $e');
      //    print('Document data: ${data.toString()}');

      // Return a default purchase if there's an error
      return Purchase(
        id: doc.id,
        orderNumber: "ERROR-${doc.id}",
        phones: [],
        supplierRef: FirebaseFirestore.instance
            .collection('Suppliers')
            .doc('default'),
        amount: 0.0,
        gst: 0.0,
        pst: 0.0,
        paymentSource: BalanceType.cash,
        date: DateTime.now(),
        total: 0.0,
        paid: 0.0,
        credit: 0.0,
        supplierName: "Error Loading Supplier",
      );
    }
  }

  // Helper method to create a copy with updated values
  Purchase copyWith({
    String? orderNumber,
    DateTime? date,
    DocumentReference? supplierRef,
    List<DocumentReference>? phones,
    double? amount,
    double? gst,
    double? pst,
    BalanceType? paymentSource,
    double? total,
    double? paid,
    double? credit,
    String? supplierName,
    double? bankPaid,
    double? cardPaid,
    double? cashPaid,
  }) {
    return Purchase(
      id: id,
      snapshot: snapshot,
      orderNumber: orderNumber ?? this.orderNumber,
      date: date ?? this.date,
      supplierRef: supplierRef ?? this.supplierRef,
      phones: phones ?? this.phones,
      amount: amount ?? this.amount,
      gst: gst ?? this.gst,
      pst: pst ?? this.pst,
      paymentSource: paymentSource ?? this.paymentSource,
      total: total ?? this.total,
      paid: paid ?? this.paid,
      credit: credit ?? this.credit,
      supplierName: supplierName ?? this.supplierName,
      bankPaid: bankPaid ?? this.bankPaid,
      cardPaid: cardPaid ?? this.cardPaid,
      cashPaid: cashPaid ?? this.cashPaid,
    );
  }

  // Helper method to get total payment amount
  double get totalPaymentAmount {
    double totalPay = 0.0;
    if (bankPaid != null) totalPay += bankPaid!;
    if (cardPaid != null) totalPay += cardPaid!;
    if (cashPaid != null) totalPay += cashPaid!;
    return totalPay;
  }

  // Helper method to check if any payment method is used
  bool get hasPaymentDetails {
    return (bankPaid != null && bankPaid! > 0) ||
        (cardPaid != null && cardPaid! > 0) ||
        (cashPaid != null && cashPaid! > 0);
  }

  // Helper methods to get formatted payment amounts
  String get bankPaidFormatted {
    return bankPaid != null ? "\$${bankPaid!.toStringAsFixed(2)}" : "\$0.00";
  }

  String get cardPaidFormatted {
    return cardPaid != null ? "\$${cardPaid!.toStringAsFixed(2)}" : "\$0.00";
  }

  String get cashPaidFormatted {
    return cashPaid != null ? "\$${cashPaid!.toStringAsFixed(2)}" : "\$0.00";
  }

  String get totalFormatted {
    return "\$${total.toStringAsFixed(2)}";
  }

  String get amountFormatted {
    return "\$${amount.toStringAsFixed(2)}";
  }

  String get totalPaymentFormatted {
    return "\$${totalPaymentAmount.toStringAsFixed(2)}";
  }

  // Helper method to get balance due
  double get balanceDue {
    return total - totalPaymentAmount;
  }

  String get balanceDueFormatted {
    return "\$${balanceDue.toStringAsFixed(2)}";
  }

  // Debug method to print payment details
  void debugPaymentDetails() {
    print('=== Payment Details for Purchase ${orderNumber} ===');
    print('  Cash Paid: ${cashPaidFormatted} (Raw: ${cashPaid})');
    print('  Card Paid: ${cardPaidFormatted} (Raw: ${cardPaid})');
    print('  Bank Paid: ${bankPaidFormatted} (Raw: ${bankPaid})');
    print('  Total Payment: ${totalPaymentFormatted}');
    print('  Purchase Total: ${totalFormatted}');
    print('  Balance Due: ${balanceDueFormatted}');
    print('  Has Payment Details: ${hasPaymentDetails}');
    print('  Payment Source: ${paymentSource}');
    print('========================================');
  }

  // Helper method to validate purchase data
  bool get isValid {
    return orderNumber.isNotEmpty &&
        supplierName.isNotEmpty &&
        amount >= 0 &&
        total >= 0;
  }

  // Helper method to get a summary string
  String get summary {
    return 'Purchase ${orderNumber}: ${supplierName} - ${totalFormatted} (${phones.length} phones)';
  }

  @override
  String toString() {
    return 'Purchase(id: $id, orderNumber: $orderNumber, supplier: $supplierName, total: $total, date: $date)';
  }
}

// Purchase Bill Generation Functions

Future<void> generatePurchaseBill({
  required Purchase purchase,
  required Supplier supplier,
  required List<Phone> phones,
  double? adjustment,
  String? note,
}) async {
  try {
    // Debug payment details
    print('Generating purchase bill for: ${purchase.orderNumber}');
    purchase.debugPaymentDetails();

    List<BillItem> items = await _processPhonesToBillItems(phones);

    // Create the bill with payment details from purchase
    Bill bill = await createBillWithAdminInfo(
      time: purchase.date,
      customer: BillCustomer(
        name: supplier.name,
        address: supplier.address.replaceAll(",", "\n"),
      ),
      orderNumber: purchase.orderNumber,
      items: items,
      note: note,
      adjustment: adjustment,
      billType: BillType.purchase,
      gst: purchase.gst,
      pst: purchase.pst,
      // Pass payment details - use 0.0 if null
      cashPaid: purchase.cashPaid ?? 0.0,
      cardPaid: purchase.cardPaid ?? 0.0,
      bankPaid: purchase.bankPaid ?? 0.0,
    );

    print('Purchase bill created with payment details:');
    print('  Cash: ${bill.cashPaidFormatted}');
    print('  Card: ${bill.cardPaidFormatted}');
    print('  Bank: ${bill.bankPaidFormatted}');

    await generatePdfInvoice(bill);
    print('Purchase bill PDF generated successfully');
  } catch (e) {
    print('Error generating purchase bill: $e');
    rethrow;
  }
}

Future<Bill> createPurchaseBillWithAdminInfo({
  required DateTime time,
  required BillCustomer supplier,
  required String orderNumber,
  required List<BillItem> items,
  String? note,
  double? adjustment,
  double gst = 0.0,
  double pst = 0.0,
  double cashPaid = 0.0,
  double cardPaid = 0.0,
  double bankPaid = 0.0,
}) async {
  try {
    // Get admin info for the purchase bill
    final adminInfo = await AdminService.getAdminInfo();

    return Bill(
      adminInfo: adminInfo,
      time: time,
      customer: supplier,
      orderNumber: orderNumber,
      items: items,
      note: note,
      adjustment: adjustment,
      billType: BillType.purchase,
      gst: gst,
      pst: pst,
      cashPaid: cashPaid,
      bankPaid: bankPaid,
      cardPaid: cardPaid,
    );
  } catch (e) {
    print('Error creating purchase bill with admin info: $e');
    rethrow;
  }
}

// Alternative helper function that directly uses Purchase object
Future<void> generatePurchaseBillFromPurchase({
  required Purchase purchase,
  required Supplier supplier,
  required List<Phone> phones,
  double? adjustment,
  String? note,
}) async {
  try {
    // Debug payment details
    print('Generating purchase bill from purchase: ${purchase.orderNumber}');
    purchase.debugPaymentDetails();

    List<BillItem> items = await _processPhonesToBillItems(phones);

    // Create purchase bill using the dedicated function
    Bill bill = await createPurchaseBillWithAdminInfo(
      time: purchase.date,
      supplier: BillCustomer(
        name: supplier.name,
        address: supplier.address.replaceAll(",", "\n"),
      ),
      orderNumber: purchase.orderNumber,
      items: items,
      note: note,
      adjustment: adjustment,
      gst: purchase.gst,
      pst: purchase.pst,
      cashPaid: purchase.cashPaid ?? 0.0,
      cardPaid: purchase.cardPaid ?? 0.0,
      bankPaid: purchase.bankPaid ?? 0.0,
    );

    print('Purchase bill created with payment details:');
    print('  Cash: ${bill.cashPaidFormatted}');
    print('  Card: ${bill.cardPaidFormatted}');
    print('  Bank: ${bill.bankPaidFormatted}');

    await generatePdfInvoice(bill);
    print('Purchase bill PDF generated successfully');
  } catch (e) {
    print('Error generating purchase bill from purchase: $e');
    rethrow;
  }
}

// Helper function to process phones into bill items (extracted for reusability)
Future<List<BillItem>> _processPhonesToBillItems(List<Phone> phones) async {
  List<BillItem> items = [];
  Map<Phone, bool> processedPhones = {};

  try {
    for (var phone in phones) {
      if (processedPhones[phone] == true) continue;

      // Find similar phones
      List<Phone> similarPhones =
          phones
              .where(
                (p) =>
                    p.modelRef == phone.modelRef &&
                    p.color == phone.color &&
                    p.capacity == phone.capacity &&
                    p.price == phone.price &&
                    !processedPhones.containsKey(p),
              )
              .toList();

      // Get phone model and brand information
      PhoneModel? phoneModel;
      PhoneBrand? phoneBrand;

      try {
        if (phone.model != null) {
          phoneModel = PhoneModel.fromFirestore(phone.model!);
        }
        if (phone.brand != null) {
          phoneBrand = PhoneBrand.fromFirestore(phone.brand!);
        }
      } catch (e) {
        print('Error loading phone model/brand for phone ${phone.id}: $e');
      }

      // Create bill item with fallback names
      String itemTitle = '';
      if (phoneBrand != null && phoneModel != null) {
        itemTitle =
            "${phoneBrand.name} ${phoneModel.name}, ${phone.color}, ${phone.capacity}GB";
      } else {
        itemTitle = "Phone ${phone.color}, ${phone.capacity}GB";
      }

      items.add(
        BillItemImpl(
          quantity: similarPhones.length,
          title: itemTitle,
          unitPrice: phone.price,
        ),
      );

      // Mark similar phones as processed
      for (var similarPhone in similarPhones) {
        processedPhones[similarPhone] = true;
      }
    }
  } catch (e) {
    print('Error processing phones to bill items: $e');
    rethrow;
  }

  return items;
}

// Utility functions for Purchase operations

// Function to calculate purchase totals with tax
Map<String, double> calculatePurchaseTotals({
  required double amount,
  required double gstPercentage,
  required double pstPercentage,
  double adjustment = 0.0,
}) {
  double gstAmount = amount * (gstPercentage / 100);
  double pstAmount = amount * (pstPercentage / 100);
  double totalTax = gstAmount + pstAmount;
  double total = amount + totalTax - adjustment;

  return {
    'amount': amount,
    'gstAmount': gstAmount,
    'pstAmount': pstAmount,
    'totalTax': totalTax,
    'total': total,
    'adjustment': adjustment,
  };
}

// Function to validate purchase data before saving
List<String> validatePurchaseData({
  required String orderNumber,
  required String supplierName,
  required double amount,
  required double total,
  required List<DocumentReference> phones,
}) {
  List<String> errors = [];

  if (orderNumber.isEmpty) {
    errors.add('Order number cannot be empty');
  }

  if (supplierName.isEmpty) {
    errors.add('Supplier name cannot be empty');
  }

  if (amount < 0) {
    errors.add('Amount cannot be negative');
  }

  if (total < 0) {
    errors.add('Total cannot be negative');
  }

  if (phones.isEmpty) {
    errors.add('At least one phone must be included in the purchase');
  }

  return errors;
}
