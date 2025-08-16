import 'package:aromex/models/balance_generic.dart';
import 'package:aromex/models/bill.dart';
import 'package:aromex/models/bill_customer.dart';
import 'package:aromex/models/bill_item.dart';
import 'package:aromex/models/customer.dart';
import 'package:aromex/models/generic_firebase_object.dart';
import 'package:aromex/models/phone.dart';
import 'package:aromex/models/phone_brand.dart';
import 'package:aromex/models/phone_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Sale extends GenericFirebaseObject<Sale> {
  final String orderNumber;
  final DateTime date;
  final double amount;
  final double gst;
  final double pst;
  final double total;
  final double paid;
  final double credit;
  final DocumentReference customerRef;
  final List<DocumentReference> phones;
  final DocumentReference? middlemanRef;
  final double mTotal;
  final double mPaid;
  final double mCredit;
  final String? customerName;
  final double originalPrice;

  // New nullable payment fields
  final double? bankPaid;
  final double? upiPaid;
  final double? cashPaid;

  Sale({
    super.id,
    super.snapshot,
    required this.orderNumber,
    required this.amount,
    required this.gst,
    required this.pst,
    required this.date,
    required this.total,
    required this.paid,
    required this.credit,
    required this.customerRef,
    required this.phones,
    this.middlemanRef,
    this.mTotal = 0.0,
    this.mPaid = 0.0,
    this.mCredit = 0.0,
    required this.customerName,
    required this.originalPrice,
    // Nullable payment fields
    this.bankPaid,
    this.upiPaid,
    this.cashPaid,
  });

  static const collectionName = "Sales";
  @override
  String get collName => collectionName;

  @override
  Map<String, dynamic> toFirestore() {
    Map<String, dynamic> data = {
      "orderNumber": orderNumber,
      "originalPrice": originalPrice,
      "amount": amount,
      "gst": gst,
      "pst": pst,
      "date": date,
      "total": total,
      "paid": paid,
      "credit": credit,
      "customerId": customerRef,
      "phones": phones,
      "middlemanId": middlemanRef,
      "mTotal": mTotal,
      "mPaid": mPaid,
      "mCredit": mCredit,
      "customerName": customerName,
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

  factory Sale.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data();
      if (data == null) {
        throw ArgumentError('Document data is null');
      }

      final saleData = data as Map<String, dynamic>;

      return Sale(
        id: doc.id,
        orderNumber: saleData["orderNumber"] ?? "",
        originalPrice: (saleData["originalPrice"] ?? 0.0).toDouble(),
        amount: (saleData['amount'] ?? 0.0).toDouble(),
        gst: (saleData['gst'] ?? 0.0).toDouble(),
        pst: (saleData['pst'] ?? 0.0).toDouble(),
        date: (saleData['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        total: (saleData['total'] ?? 0.0).toDouble(),
        paid: (saleData['paid'] ?? 0.0).toDouble(),
        credit: (saleData['credit'] ?? 0.0).toDouble(),
        customerRef: saleData["customerId"],
        phones:
            (saleData['phones'] as List<dynamic>?)
                ?.map((e) => e as DocumentReference)
                .toList() ??
            [],
        snapshot: doc,
        middlemanRef: saleData["middlemanId"],
        mTotal: (saleData['mTotal'] ?? 0.0).toDouble(),
        mPaid: (saleData['mPaid'] ?? 0.0).toDouble(),
        mCredit: (saleData['mCredit'] ?? 0.0).toDouble(),
        customerName: saleData["customerName"] ?? "",
        // Handle nullable payment fields - keep as null if not present
        bankPaid:
            saleData["bankPaid"] != null
                ? (saleData["bankPaid"] as num).toDouble()
                : null,
        upiPaid:
            saleData["cardPaid"] != null
                ? (saleData["cardPaid"] as num).toDouble()
                : null,
        cashPaid:
            saleData["cashPaid"] != null
                ? (saleData["cashPaid"] as num).toDouble()
                : null,
      );
    } catch (e) {
      print('Error creating Sale from Firestore document ${doc.id}: $e');
      // Return a default sale if there's an error
      return Sale(
        orderNumber: "",
        amount: 0.0,
        gst: 0.0,
        pst: 0.0,
        date: DateTime.now(),
        total: 0.0,
        paid: 0.0,
        credit: 0.0,
        customerRef: FirebaseFirestore.instance
            .collection('Customers')
            .doc('default'),
        phones: [],
        customerName: "",
        originalPrice: 0.0,
      );
    }
  }

  // Helper method to create a copy with updated values
  Sale copyWith({
    String? orderNumber,
    DateTime? date,
    double? amount,
    double? gst,
    double? pst,
    BalanceType? paymentSource,
    double? total,
    double? paid,
    double? credit,
    DocumentReference? customerRef,
    List<DocumentReference>? phones,
    DocumentReference? middlemanRef,
    double? mTotal,
    double? mPaid,
    double? mCredit,
    String? customerName,
    double? originalPrice,
    double? bankPaid,
    double? upiPaid,
    double? cashPaid,
  }) {
    return Sale(
      id: id,
      snapshot: snapshot,
      orderNumber: orderNumber ?? this.orderNumber,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      gst: gst ?? this.gst,
      pst: pst ?? this.pst,
      total: total ?? this.total,
      paid: paid ?? this.paid,
      credit: credit ?? this.credit,
      customerRef: customerRef ?? this.customerRef,
      phones: phones ?? this.phones,
      middlemanRef: middlemanRef ?? this.middlemanRef,
      mTotal: mTotal ?? this.mTotal,
      mPaid: mPaid ?? this.mPaid,
      mCredit: mCredit ?? this.mCredit,
      customerName: customerName ?? this.customerName,
      originalPrice: originalPrice ?? this.originalPrice,
      bankPaid: bankPaid ?? this.bankPaid,
      upiPaid: upiPaid ?? this.upiPaid,
      cashPaid: cashPaid ?? this.cashPaid,
    );
  }

  // Helper method to get total payment amount
  double get totalPaymentAmount {
    double total = 0.0;
    if (bankPaid != null) total += bankPaid!;
    if (upiPaid != null) total += upiPaid!;
    if (cashPaid != null) total += cashPaid!;
    return total;
  }

  // Helper method to check if any payment method is used
  bool get hasPaymentDetails {
    return bankPaid != null || upiPaid != null || cashPaid != null;
  }
}

Future<void> generateBill({
  required Sale sale,
  required Customer customer,
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

  // Create the bill with dynamic admin info including GST and PST percentages from sale
  Bill bill = await createBillWithAdminInfo(
    time: sale.date,
    customer: BillCustomer(
      name: customer.name,
      address: customer.address.replaceAll(",", "\n"),
    ),
    orderNumber: sale.orderNumber,
    items: items,
    note: note,
    adjustment: adjustment,
    billType: BillType.sale, // Specify as sale bill
    gst: sale.gst, // Pass GST percentage from sale
    pst: sale.pst, // Pass PST percentage from sale
  );

  await generatePdfInvoice(bill);
}
