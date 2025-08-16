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
  if (middleman == null || credit == 0) return;

  try {
    final docRef = FirebaseFirestore.instance
        .collection('Middlemen')
        .doc(middleman.id);
    final snapshot = await docRef.get();
    
    if (!snapshot.exists) {
      print('Warning: Middleman document does not exist: ${middleman.id}');
      return;
    }
    
    final data = snapshot.data();
    if (data == null) {
      print('Warning: Middleman document data is null: ${middleman.id}');
      return;
    }
    
    final currentBalance = (data['balance'] ?? 0.0) as num;
    final newBalance = currentBalance + credit;
    
    await docRef.update({
      'balance': newBalance,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    print('Updated middleman ${middleman.id} balance: $currentBalance -> $newBalance (credit: $credit)');
  } catch (e) {
    print('Error updating middleman balance: $e');
    // Don't throw the error to prevent the entire sale from failing
  }
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

  try {
    await Future.wait([
      // Add to Bank balance
      if ((bankPaid ?? 0) > 0)
        Balance.fromType(BalanceType.bank).then((balance) async {
          try {
            await balance.addAmount(
              bankPaid!,
              transactionType: TransactionType.sale,
              saleRef: saleRef,
            );
          } catch (e) {
            print('Error updating bank balance: $e');
          }
        }),

      // Add to Cash balance
      if ((cashPaid ?? 0) > 0)
        Balance.fromType(BalanceType.cash).then((balance) async {
          try {
            await balance.addAmount(
              cashPaid!,
              transactionType: TransactionType.sale,
              saleRef: saleRef,
            );
          } catch (e) {
            print('Error updating cash balance: $e');
          }
        }),

      // Add to UPI balance
      if ((upiPaid ?? 0) > 0)
        Balance.fromType(BalanceType.upi).then((balance) async {
          try {
            await balance.addAmount(
              upiPaid!,
              transactionType: TransactionType.sale,
              saleRef: saleRef,
            );
          } catch (e) {
            print('Error updating UPI balance: $e');
          }
        }),

      // Handle credit
      if (credit > 0)
        Balance.fromType(BalanceType.totalOwe).then((balance) async {
          try {
            await balance.addAmount(
              credit,
              transactionType: TransactionType.sale,
              saleRef: saleRef,
            );
          } catch (e) {
            print('Error updating total owe balance: $e');
          }
        }),
    ]);
  } catch (e) {
    print('Error in addBalance: $e');
    // Don't throw the error to prevent the entire sale from failing
  }
}

Future<void> addCreditToCustomer(
  DocumentReference customer,
  double credit,
) async {
  try {
    final docRef = FirebaseFirestore.instance
        .collection('Customers')
        .doc(customer.id);

    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      print('Warning: Customer document does not exist: ${customer.id}');
      return;
    }
    
    final data = snapshot.data();
    if (data == null) {
      print('Warning: Customer document data is null: ${customer.id}');
      return;
    }
    
    final currentBalance = (data['balance'] ?? 0.0) as num;
    final newBalance = currentBalance + credit;
    
    await docRef.update({
      'balance': newBalance,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    print('Updated customer ${customer.id} balance: $currentBalance -> $newBalance (credit: $credit)');
  } catch (e) {
    print('Error updating customer balance: $e');
    // Don't throw the error to prevent the entire sale from failing
  }
}

Future<void> addSaleToCustomer(
  DocumentReference customer,
  DocumentReference saleRef,
) async {
  try {
    await FirebaseFirestore.instance
        .collection('Customers')
        .doc(customer.id)
        .update({
          'transactionHistory': FieldValue.arrayUnion([saleRef]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
    
    print('Added sale ${saleRef.id} to customer ${customer.id} transaction history');
  } catch (e) {
    print('Error adding sale to customer transaction history: $e');
    // Don't throw the error to prevent the entire sale from failing
  }
}

Future<void> addSaleToMiddleman(
  DocumentReference? middleman,
  DocumentReference saleRef,
) async {
  if (middleman == null) return;
  
  try {
    await FirebaseFirestore.instance
        .collection('Middlemen')
        .doc(middleman.id)
        .update({
          'transactionHistory': FieldValue.arrayUnion([saleRef]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
    
    print('Added sale ${saleRef.id} to middleman ${middleman.id} transaction history');
  } catch (e) {
    print('Error adding sale to middleman transaction history: $e');
    // Don't throw the error to prevent the entire sale from failing
  }
}

Future<void> updateSaleStats(double amount, DocumentReference customer) async {
  try {
    final totalsRef = FirebaseFirestore.instance.collection('Data').doc('Totals');

    final totalsSnapshot = await totalsRef.get();

    if (!totalsSnapshot.exists) {
      await totalsRef.set({
        'totalSales': 1,
        'totalSaleAmount': amount,
        'customerIds': [customer.id],
        'totalCustomers': 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Created new totals document with first sale');
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
    
    print('Updated sale stats: totalSales=${currentTotalSales + 1}, totalAmount=${currentTotalAmount + amount}');
  } catch (e) {
    print('Error updating sale stats: $e');
    // Don't throw the error to prevent the entire sale from failing
  }
}
