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
  final double? bankPaid;
  final double? upiPaid;
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
    this.upiPaid,
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

    // Only add payment fields if they are not null
    if (bankPaid != null) {
      data["bankPaid"] = bankPaid!;
    }
    if (upiPaid != null) {
      data["cardPaid"] = upiPaid!;
    }
    if (cashPaid != null) {
      data["cashPaid"] = cashPaid!;
    }

    return data;
  }

  factory Purchase.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data();
      if (data == null) {
        throw ArgumentError('Document data is null');
      }

      final purchaseData = data as Map<String, dynamic>;

      return Purchase(
        id: doc.id,
        orderNumber: purchaseData["orderNumber"] ?? '',
        phones:
            (purchaseData['phones'] as List<dynamic>?)
                ?.cast<DocumentReference>() ??
            [],
        supplierRef: purchaseData["supplierId"],
        amount: (purchaseData["amount"] as num?)?.toDouble() ?? 0.0,
        gst: (purchaseData["gst"] as num?)?.toDouble() ?? 0.0,
        pst: (purchaseData["pst"] as num?)?.toDouble() ?? 0.0,
        paymentSource: BalanceType.values.firstWhere(
          (type) =>
              type.toString() == 'BalanceType.${purchaseData["paymentSource"]}',
          orElse: () => BalanceType.cash,
        ),
        date: (purchaseData["date"] as Timestamp?)?.toDate() ?? DateTime.now(),
        total: (purchaseData["total"] ?? 0.0).toDouble(),
        paid: (purchaseData["paid"] ?? 0.0).toDouble(),
        credit: (purchaseData["credit"] ?? 0.0).toDouble(),
        snapshot: doc,
        supplierName: purchaseData["supplierName"] ?? "",
        bankPaid:
            purchaseData["bankPaid"] != null
                ? (purchaseData["bankPaid"] as num).toDouble()
                : null,
        upiPaid:
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
      // Return a default purchase if there's an error
      return Purchase(
        orderNumber: "",
        phones: [],
        supplierRef: FirebaseFirestore.instance
            .collection('Suppliers')
            .doc('default'),
        amount: 0.0,
        gst: 0.0,
        pst: 0.0,
        paymentSource: BalanceType.cash,
        date: DateTime.now(),
        supplierName: "",
      );
    }
  }
}

Future<void> generatePurchaseBill({
  required Purchase purchase,
  required Supplier supplier,
  required List<Phone> phones,
  double? adjustment,
  String? note,
}) async {
  List<BillItem> items = [];
  Map<Phone, bool> processedPhones = {};

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

    PhoneModel phoneModel = PhoneModel.fromFirestore(phone.model!);
    PhoneBrand phoneBrand = PhoneBrand.fromFirestore(phone.brand!);

    items.add(
      BillItemImpl(
        quantity: similarPhones.length,
        title:
            "${phoneBrand.name} ${phoneModel.name}, ${phone.color}, ${phone.capacity}GB",
        unitPrice: phone.price,
      ),
    );

    for (var similarPhone in similarPhones) {
      processedPhones[similarPhone] = true;
    }
  }

  // Create the bill with dynamic admin info including GST and PST percentages from purchase
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
    billType: BillType.purchase, // Specify as purchase bill
    gst: purchase.gst, // Pass GST percentage from purchase
    pst: purchase.pst, // Pass PST percentage from purchase
  );

  await generatePdfInvoice(bill);
}

Future<Bill> createPurchaseBillWithAdminInfo({
  required DateTime time,
  required BillCustomer supplier, // Using BillCustomer structure for supplier
  required String orderNumber,
  required List<BillItem> items,
  String? note,
  double? adjustment,
  double gst = 0.0, // Added GST percentage parameter
  double pst = 0.0, // Added PST percentage parameter
}) async {
  // Get admin info for the purchase bill
  final adminInfo = await AdminService.getAdminInfo();

  return Bill(
    adminInfo: adminInfo,
    time: time,
    customer: supplier, // Using supplier as customer for purchase bill
    orderNumber: orderNumber,
    items: items,
    note: note,
    adjustment: adjustment,
    billType: BillType.purchase,
    gst: gst, // Pass GST
    pst: pst, // Pass PST
  );
}

// Alternative helper function that directly uses Purchase object
Future<void> generatePurchaseBillFromPurchase({
  required Purchase purchase,
  required Supplier supplier,
  required List<Phone> phones,
  double? adjustment,
  String? note,
}) async {
  List<BillItem> items = [];
  Map<Phone, bool> processedPhones = {};

  // Process phones to create bill items
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

    PhoneModel phoneModel = PhoneModel.fromFirestore(phone.model!);
    PhoneBrand phoneBrand = PhoneBrand.fromFirestore(phone.brand!);

    items.add(
      BillItemImpl(
        quantity: similarPhones.length,
        title:
            "${phoneBrand.name} ${phoneModel.name}, ${phone.color}, ${phone.capacity}GB",
        unitPrice: phone.price,
      ),
    );

    for (var similarPhone in similarPhones) {
      processedPhones[similarPhone] = true;
    }
  }

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
    gst: purchase.gst, // Pass GST percentage from purchase
    pst: purchase.pst, // Pass PST percentage from purchase
  );

  await generatePdfInvoice(bill);
}
