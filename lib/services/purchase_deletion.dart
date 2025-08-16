import 'package:aromex/models/balance_generic.dart';
import 'package:aromex/models/purchase.dart';
import 'package:aromex/models/transaction.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> deletePurchaseWithReversal(Purchase purchase) async {
  if (purchase.id == null || purchase.id!.isEmpty) {
    throw Exception('Purchase ID cannot be null or empty');
  }

  final purchaseRef = FirebaseFirestore.instance
      .collection('Purchases')
      .doc(purchase.id);

  try {
    // 1. Reverse supplier balance
    final supplierRef = purchase.supplierRef;
    final supplierDoc = await supplierRef.get();
    if (!supplierDoc.exists) {
      throw Exception('Supplier not found: ${supplierRef.id}');
    }

    final supplierData = supplierDoc.data() as Map<String, dynamic>?;
    if (supplierData == null) {
      throw Exception('Supplier data is null');
    }

    final currentBalance = (supplierData['balance'] ?? 0.0) as num;
    final creditAmount = purchase.credit;

    await supplierRef.update({'balance': currentBalance - creditAmount});

    // 2. Reverse each payment method's balance
    Future<void> reversePayment(BalanceType type, double paid) async {
      if (paid > 0) {
        final balance = await Balance.fromType(type);
        await balance.addAmount(
          paid,
          transactionType: TransactionType.purchase,
          purchaseRef: purchaseRef,
        );
      }
    }

    await Future.wait([
      reversePayment(BalanceType.cash, purchase.cashPaid ?? 0),
      reversePayment(BalanceType.bank, purchase.bankPaid ?? 0),
      reversePayment(BalanceType.upi, purchase.cardPaid ?? 0),
    ]);

    // 3. Reverse Total Due if credit was used
    if (creditAmount != 0) {
      final totalDue = await Balance.fromType(BalanceType.totalDue);
      await totalDue.removeAmount(
        creditAmount,
        transactionType: TransactionType.purchase,
        purchaseRef: purchaseRef,
      );
    }

    // 4. Remove purchaseRef from phones and delete them
    for (final phoneRef in purchase.phones) {
      final phoneDoc = await phoneRef.get();
      if (phoneDoc.exists) {
        await phoneRef.update({'purchaseRef': null});
        await phoneRef.delete();
      }
    }

    // 5. Remove purchaseRef from supplier's transaction history
    await supplierRef.update({
      'transactionHistory': FieldValue.arrayRemove([purchaseRef]),
    });

    // 6. Update totals
    final totalsDoc =
        await FirebaseFirestore.instance.collection('Data').doc('Totals').get();

    if (totalsDoc.exists) {
      final totalsData = totalsDoc.data();
      if (totalsData != null) {
        final newTotalPurchases = ((totalsData['totalPurchases'] ?? 0) - 1)
            .clamp(0, double.infinity);
        final newTotalAmount = ((totalsData['totalAmount'] ?? 0.0) -
                purchase.amount)
            .clamp(0.0, double.infinity);

        await totalsDoc.reference.update({
          'totalPurchases': newTotalPurchases,
          'totalAmount': newTotalAmount,
        });
      }
    }

    // 7. Delete the purchase document
    await purchaseRef.delete();
  } catch (e) {
    print('Error deleting purchase: $e');
    rethrow;
  }
}
