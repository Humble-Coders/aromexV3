import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { sale, purchase, self, unknown }

Map<TransactionType, String> transactionTypeTitles = {
  TransactionType.sale: 'Sale',
  TransactionType.purchase: 'Purchase',
  TransactionType.self: 'Self',
  TransactionType.unknown: 'Unknown',
};

class Transaction {
  static const collectionName = 'Transactions';
  final String? id;
  final double amount;
  final Timestamp time;
  final DocumentSnapshot? snapshot;
  final TransactionType type;
  final DocumentReference? saleRef;
  final DocumentReference? purchaseRef;
  final String? note;
  final String? category;
  final double? cashPaid;
  final double? bankPaid;
  final double? creditCardPaid;

  Transaction({
    required this.amount,
    required this.time,
    this.id,
    this.saleRef,
    this.purchaseRef,
    this.snapshot,
    this.bankPaid,
    this.cashPaid,
    this.creditCardPaid,
    this.type = TransactionType.unknown,
    this.category,
    this.note,
  }) : assert(
         type != TransactionType.purchase || purchaseRef != null,
         'Purchase transactions must have a purchaseRef',
       ),
       assert(
         type != TransactionType.sale || saleRef != null,
         'Sale transactions must have a saleRef',
       ),
       assert(
         type != TransactionType.unknown ||
             (saleRef == null && purchaseRef == null),
         'Unknown transactions must not have saleRef or purchaseRef',
       );

  factory Transaction.fromJson(String? id, Map<String, dynamic> json) {
    return Transaction(
      id: id,
      amount: (json['amount'] as num).toDouble(),
      time: json['time'] as Timestamp,
      saleRef: json['saleRef'],
      category: json['category'],
      purchaseRef: json['purchaseRef'],
      type:
          transactionTypeTitles.entries
              .firstWhere(
                (entry) => entry.value == json['type'],
                orElse: () => MapEntry(TransactionType.unknown, 'Unknown'),
              )
              .key,
      note: json['note'],
      cashPaid:
          json['cashPaid'] != null
              ? (json['cashPaid'] as num).toDouble()
              : null,
      bankPaid:
          json['bankPaid'] != null
              ? (json['bankPaid'] as num).toDouble()
              : null,
      creditCardPaid:
          json['creditCardPaid'] != null
              ? (json['creditCardPaid'] as num).toDouble()
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> data = {
      'amount': amount,
      'time': time,
      'saleRef': saleRef,
      'purchaseRef': purchaseRef,
      'type': transactionTypeTitles[type],
      'note': note,
      'category': category,
    };

    // Add payment fields only if they have values
    if (cashPaid != null && cashPaid! > 0) {
      data['cashPaid'] = cashPaid;
    }
    if (bankPaid != null && bankPaid! > 0) {
      data['bankPaid'] = bankPaid;
    }
    if (creditCardPaid != null && creditCardPaid! > 0) {
      data['creditCardPaid'] = creditCardPaid;
    }

    return data;
  }

  // Helper method to format payment source similar to sales
  String formatPaymentSource() {
    List<String> paymentParts = [];

    if (cashPaid != null && cashPaid! > 0) {
      paymentParts.add('Cash(${cashPaid!.toInt()})');
    }

    if (bankPaid != null && bankPaid! > 0) {
      paymentParts.add('Bank(${bankPaid!.toInt()})');
    }

    if (creditCardPaid != null && creditCardPaid! > 0) {
      paymentParts.add('Credit Card(${creditCardPaid!.toInt()})');
    }

    // If no specific payment amounts, return default
    if (paymentParts.isEmpty) {
      return "Not specified";
    }

    // Join multiple payment methods with comma and space
    return paymentParts.join(', ');
  }
}
