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
    return {
      "orderNumber": orderNumber,
      "phones": phones,
      "supplierId": supplierRef,
      "amount": amount,
      "gst": gst,
      "pst": pst,
      "paymentSource": balanceTypeTitles[paymentSource],
      "date": date,
      // Only add payment fields if they are not null
      if (bankPaid != null) "bankPaid": bankPaid,
      if (upiPaid != null) "cardPaid": upiPaid,
      if (cashPaid != null) "cashPaid": cashPaid,
      "total": total,
      "paid": paid,
      "credit": credit,
      "supplierName": supplierName,
    };
  }

  factory Purchase.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Purchase(
      id: doc.id,
      orderNumber: data["orderNumber"],
      phones: (data['phones'] as List<dynamic>).cast<DocumentReference>(),
      supplierRef: data["supplierId"],
      amount: data["amount"].toDouble(),
      gst: data["gst"].toDouble(),
      pst: data["pst"].toDouble(),
      paymentSource: BalanceType.values.firstWhere(
        (type) => type.toString() == 'BalanceType.${data["paymentSource"]}',
        orElse: () => BalanceType.cash,
      ),
      date: (data["date"] as Timestamp).toDate(),
      total: (data["total"] ?? 0.0).toDouble(),
      paid: (data["paid"] ?? 0.0).toDouble(),
      credit: (data["credit"] ?? 0.0).toDouble(),
      snapshot: doc,
      supplierName: data["supplierName"] ?? "",
      bankPaid:
          data["bankPaid"] != null
              ? (data["bankPaid"] as num).toDouble()
              : null,
      upiPaid:
          data["cardPaid"] != null
              ? (data["cardPaid"] as num).toDouble()
              : null,
      cashPaid:
          data["cashPaid"] != null
              ? (data["cashPaid"] as num).toDouble()
              : null,
    );
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

  // Create the bill with dynamic admin info
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
}) async {
  // This function should be implemented similar to createBillWithAdminInfo
  // but adapted for purchase bills. You'll need to implement this based on
  // your existing bill creation logic.

  // For now, calling the existing function - you may want to create a separate one
  return await createBillWithAdminInfo(
    time: time,
    customer: supplier, // Using supplier as customer for now
    orderNumber: orderNumber,
    items: items,
    note: note,
    adjustment: adjustment,
    billType: BillType.purchase,
  );
}
