import 'package:aromex/models/balance_generic.dart';
import 'package:aromex/models/sale.dart';
import 'package:aromex/models/transaction.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> deleteSaleWithReversal(Sale sale) async {
  if (sale.id == null || sale.id!.isEmpty) {
    throw Exception('Sale ID cannot be null or empty');
  }

  final saleRef = FirebaseFirestore.instance.collection('Sales').doc(sale.id);

  try {
    // 1. Reverse customer balance
    final customerRef = sale.customerRef;
    final customerDoc = await customerRef.get();
    if (!customerDoc.exists) {
      throw Exception('Customer not found: ${customerRef.id}');
    }

    final customerData = customerDoc.data() as Map<String, dynamic>?;
    if (customerData == null) {
      throw Exception('Customer data is null');
    }

    final currentBalance = (customerData['balance'] ?? 0.0) as num;
    final creditAmount = sale.credit;

    await customerRef.update({'balance': currentBalance - creditAmount});

    // 2. Reverse each payment method's balance
    Future<void> reversePayment(BalanceType type, double paid) async {
      if (paid > 0) {
        final balance = await Balance.fromType(type);
        await balance.removeAmount(
          paid,
          transactionType: TransactionType.sale,
          saleRef: saleRef,
        );
      }
    }

    await Future.wait([
      reversePayment(BalanceType.cash, sale.cashPaid ?? 0),
      reversePayment(BalanceType.bank, sale.bankPaid ?? 0),
      reversePayment(BalanceType.upi, sale.upiPaid ?? 0),
    ]);

    // 3. Reverse Total Owe if credit was used
    if (creditAmount != 0) {
      final totalOwe = await Balance.fromType(BalanceType.totalOwe);
      await totalOwe.removeAmount(
        creditAmount,
        transactionType: TransactionType.sale,
        saleRef: saleRef,
      );
    }

    // 4. Remove saleRef from phones and delete them
    for (final phoneRef in sale.phones) {
      final phoneDoc = await phoneRef.get();
      if (phoneDoc.exists) {
        await phoneRef.update({'saleRef': null});
        await phoneRef.delete();
      }
    }

    // 5. Remove saleRef from customer transaction history
    await customerRef.update({
      'transactionHistory': FieldValue.arrayRemove([saleRef]),
    });

    // 6. Update totals
    final totalsDoc =
        await FirebaseFirestore.instance.collection('Data').doc('Totals').get();

    if (totalsDoc.exists) {
      final totalsData = totalsDoc.data();
      if (totalsData != null) {
        final newTotalSales = ((totalsData['totalSales'] ?? 0) - 1).clamp(
          0,
          double.infinity,
        );
        final newTotalAmount = ((totalsData['totalAmount'] ?? 0.0) - sale.total)
            .clamp(0.0, double.infinity);

        await totalsDoc.reference.update({
          'totalSales': newTotalSales,
          'totalAmount': newTotalAmount,
        });
      }
    }

    // 7. Delete the sale document
    await saleRef.delete();
  } catch (e) {
    print('Error deleting sale: $e');
    rethrow;
  }
}
