import 'package:aromex/models/balance_generic.dart';
import 'package:aromex/models/sale.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> deleteSaleWithReversal(Sale sale) async {
  final saleRef = FirebaseFirestore.instance.collection('Sales').doc(sale.id);

  try {
    // 1. Reverse customer balance
    final customerRef = sale.customerRef;
    final customerDoc = await customerRef.get();

    if (!customerDoc.exists) {
      throw Exception('Customer document not found: ${customerRef.id}');
    }

    final customerData = customerDoc.data();
    if (customerData == null) {
      throw Exception('Customer data is null for: ${customerRef.id}');
    }

    final customerMap = customerData as Map<String, dynamic>;
    final currentBalance = (customerMap['balance'] ?? 0.0) as num;
    await customerRef.update({'balance': currentBalance - sale.credit});

    // 2. Reverse middleman balance if applicable and document exists
    if (sale.middlemanRef != null) {
      final middlemanDoc = await sale.middlemanRef!.get();

      if (middlemanDoc.exists) {
        final middlemanData = middlemanDoc.data();
        if (middlemanData != null) {
          final middlemanMap = middlemanData as Map<String, dynamic>;
          final middlemanBalance = (middlemanMap['balance'] ?? 0.0) as num;
          await sale.middlemanRef!.update({
            'balance': middlemanBalance - sale.mCredit,
          });
        } else {
          print('Middleman data is null for: ${sale.middlemanRef!.id}');
        }
      } else {
        print('Middleman document not found: ${sale.middlemanRef!.id}');
      }
    }

    // 3. Reverse payment source balance
    final paymentSourceName = balanceTypeTitles[sale.paymentSource];
    if (paymentSourceName == null) {
      throw Exception('Invalid payment source: ${sale.paymentSource}');
    }

    final balanceDoc =
        await FirebaseFirestore.instance
            .collection('Balances')
            .doc(paymentSourceName)
            .get();

    if (!balanceDoc.exists) {
      throw Exception(
        'Balance document not found: ${sale.paymentSource?.name}',
      );
    }

    final balanceData = balanceDoc.data();
    if (balanceData == null) {
      throw Exception('Balance data is null for: $paymentSourceName');
    }

    final balanceAmount = (balanceData['amount'] ?? 0.0) as num;
    await balanceDoc.reference.update({
      'amount': balanceAmount + (sale.amount - sale.credit),
    });

    // 4. Reverse totalOwe if credit was used
    if (sale.credit != 0) {
      final oweDoc =
          await FirebaseFirestore.instance
              .collection('Balances')
              .doc('Total Owe')
              .get();

      if (!oweDoc.exists) {
        throw Exception('TotalOwe document not found');
      }

      final oweData = oweDoc.data();
      if (oweData == null) {
        throw Exception('TotalOwe data is null');
      }

      final oweAmount = (oweData['amount'] ?? 0.0) as num;
      await oweDoc.reference.update({'amount': oweAmount - sale.credit});
    }
    // 5. Remove saleRef from phones
    for (final phoneRef in sale.phones) {
      final phoneDoc = await phoneRef.get();
      if (phoneDoc.exists) {
        await phoneRef.update({'saleRef': null});
      } else {
        print('Phone doc not found: ${phoneRef.path}');
      }
    }

    // 6. Remove saleRef from customer's transactionHistory
    await customerRef.update({
      'transactionHistory': FieldValue.arrayRemove([saleRef]),
    });

    // 7. Update totals
    final totalsDoc =
        await FirebaseFirestore.instance.collection('Data').doc('Totals').get();

    if (totalsDoc.exists && totalsDoc.data() != null) {
      final totalsData = totalsDoc.data()!;
      final totalSales = (totalsData['totalSales'] ?? 0).toInt() - 1;
      final totalSaleAmount =
          (totalsData['totalSaleAmount'] ?? 0.0).toDouble() - sale.amount;

      await FirebaseFirestore.instance.collection('Data').doc('Totals').update({
        'totalSales': totalSales,
        'totalSaleAmount': totalSaleAmount,
      });
    }

    // 8. Delete the sale document
    await saleRef.delete();
  } catch (e) {
    print('Error deleting sale: $e');
    rethrow;
  }
}
