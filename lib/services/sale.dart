import 'package:aromex/models/balance_generic.dart';
import 'package:aromex/models/order.dart' as aromex_order;
import 'package:aromex/models/sale.dart';
import 'package:aromex/models/transaction.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> createSale(aromex_order.Order order, Sale sale) async {
  final saleRef = await sale.create();

  for (final phone in order.phoneList) {
    phone.saleRef = saleRef;
    await phone.save();
  }

  await addBalance(
    sale.bankPaid,
    sale.cashPaid,
    sale.upiPaid,
    sale.total,
    sale.credit,
    saleRef,
  );
  await addCreditToCustomer(order.scref!, sale.credit);
  await addSaleToCustomer(order.scref!, saleRef);
  await updateSaleStats(sale.total, order.scref!);
  await addSaleToMiddleman(sale.middlemanRef, saleRef);
  await addCreditToMiddleman(sale.middlemanRef, sale.mCredit);
}

Future<void> addCreditToMiddleman(
  DocumentReference? middleman,
  double credit,
) async {
  if (middleman == null) return;

  final docRef = FirebaseFirestore.instance
      .collection('Middlemen')
      .doc(middleman.id);
  final snapshot = await docRef.get();
  final data = snapshot.data()!;
  final currentBalance = (data['balance'] ?? 0.0) as num;

  await docRef.update({'balance': currentBalance + credit});
}

Future<void> addBalance(
  double? bankPaid,
  double? cashPaid,
  double? upiPaid,
  double total,
  double credit,
  DocumentReference saleRef,
) async {
  total -= credit;

  await Future.wait([
    // Add to Bank balance
    if ((bankPaid ?? 0) > 0)
      Balance.fromType(BalanceType.bank).then((balance) async {
        await balance.addAmount(
          bankPaid!,
          transactionType: TransactionType.sale,
          saleRef: saleRef,
        );
      }),

    // Add to Cash balance
    if ((cashPaid ?? 0) > 0)
      Balance.fromType(BalanceType.cash).then((balance) async {
        await balance.addAmount(
          cashPaid!,
          transactionType: TransactionType.sale,
          saleRef: saleRef,
        );
      }),

    // Add to UPI balance
    if ((upiPaid ?? 0) > 0)
      Balance.fromType(BalanceType.upi).then((balance) async {
        await balance.addAmount(
          upiPaid!,
          transactionType: TransactionType.sale,
          saleRef: saleRef,
        );
      }),

    // Handle credit
    if (credit > 0)
      Balance.fromType(BalanceType.totalOwe).then((balance) async {
        await balance.addAmount(
          credit,
          transactionType: TransactionType.sale,
          saleRef: saleRef,
        );
      }),
  ]);
}

Future<void> addCreditToCustomer(
  DocumentReference customer,
  double credit,
) async {
  final docRef = FirebaseFirestore.instance
      .collection('Customers')
      .doc(customer.id);

  final snapshot = await docRef.get();
  final data = snapshot.data()!;
  final currentBalance = (data['balance'] ?? 0.0) as num;

  await docRef.update({'balance': currentBalance + credit});
}

Future<void> addSaleToCustomer(
  DocumentReference customer,
  DocumentReference saleRef,
) async {
  await FirebaseFirestore.instance
      .collection('Customers')
      .doc(customer.id)
      .update({
        'transactionHistory': FieldValue.arrayUnion([saleRef]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
}

Future<void> addSaleToMiddleman(
  DocumentReference? middleman,
  DocumentReference saleRef,
) async {
  if (middleman == null) return;
  await FirebaseFirestore.instance
      .collection('Middlemen')
      .doc(middleman.id)
      .update({
        'transactionHistory': FieldValue.arrayUnion([saleRef]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
}

Future<void> updateSaleStats(double amount, DocumentReference customer) async {
  final totalsRef = FirebaseFirestore.instance.collection('Data').doc('Totals');

  try {
    final totalsSnapshot = await totalsRef.get();

    if (!totalsSnapshot.exists) {
      await totalsRef.set({
        'totalSales': 1,
        'totalSaleAmount': amount,
        'customerIds': [customer.id],
        'totalCustomers': 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final data = totalsSnapshot.data()!;
    final currentTotalSales = (data['totalSales'] ?? 0) as num;
    final currentTotalAmount = (data['totalSaleAmount'] ?? 0.0) as num;

    List<String> customerIds = List<String>.from(data['customerIds'] ?? []);
    bool isNewCustomer = !customerIds.contains(customer.id);

    if (isNewCustomer) {
      customerIds.add(customer.id);
    }

    await totalsRef.update({
      'totalSales': currentTotalSales + 1,
      'totalSaleAmount': currentTotalAmount + amount,
      'customerIds': customerIds,
      'totalCustomers': customerIds.length,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    print('Error updating sale stats: $e');
  }
}
