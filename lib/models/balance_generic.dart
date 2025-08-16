import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aromex/models/transaction.dart' as AT;

enum BalanceType {
  creditCard,
  bank,
  cash,
  expenseRecord,
  totalDue,
  totalOwe,
  upi,
}

final Map<BalanceType, String> balanceTypeTitles = {
  BalanceType.creditCard: 'Credit Card',
  BalanceType.bank: 'Bank',
  BalanceType.cash: 'Cash',
  BalanceType.expenseRecord: 'Expense Record',
  BalanceType.totalDue: 'Total Due',
  BalanceType.totalOwe: 'Total Owe',
  BalanceType.upi: 'upi',
};

class Balance {
  static const collectionName = 'Balances';
  double amount;
  String? title;
  BalanceType? type;
  Timestamp lastTransaction;
  List<AT.Transaction>? transactions;
  String? note;

  Balance({required this.amount, required this.lastTransaction, this.type}) {
    if (type == null) return;
    String? title = balanceTypeTitles[type];
    if (title == null) {
      throw ArgumentError('Invalid BalanceType: $type');
    }
    this.title = title;
  }

  static Future<Balance> fromType(BalanceType type) async {
    final docRef = FirebaseFirestore.instance
        .collection(Balance.collectionName)
        .doc(balanceTypeTitles[type]);
    
    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      // Create a new balance document if it doesn't exist
      final newBalance = Balance(
        amount: 0.0,
        lastTransaction: Timestamp.now(),
        type: type,
      );
      
      await docRef.set(newBalance._toJson());
      return newBalance;
    }

    return Balance.fromFirestore(snapshot);
  }

  factory Balance.fromFirestore(DocumentSnapshot doc) {
    try {
      final json = doc.data();
      if (json == null) {
        throw ArgumentError('Document data is null');
      }
      
      final data = json as Map<String, dynamic>;
      
      return Balance(
        type: BalanceType.values.firstWhere(
          (e) => balanceTypeTitles[e] == doc.id,
          orElse: () => throw ArgumentError('Invalid BalanceType: ${doc.id}'),
        ),
        amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
        lastTransaction: (data['last_transaction'] as Timestamp?) ?? Timestamp.now(),
      )..note = data['note'] as String?;
    } catch (e) {
      print('Error creating Balance from Firestore document ${doc.id}: $e');
      // Return a default balance if there's an error
      return Balance(
        amount: 0.0,
        lastTransaction: Timestamp.now(),
        type: BalanceType.bank, // Default type
      );
    }
  }

  Future<void> addAmount(
    double amount, {
    AT.TransactionType transactionType = AT.TransactionType.unknown,
    DocumentReference? purchaseRef,
    DocumentReference? saleRef,
    String? category,
    String? expenseNote,
    // Add payment breakdown parameters
    double? cashPaid,
    double? bankPaid,
    double? creditCardPaid,
  }) async {
    assert(
      type == null || type != BalanceType.expenseRecord || category != null,
    );

    Timestamp transactionTime = Timestamp.now();

    await Future.wait([
      _createTransaction(
        amount,
        transactionTime,
        transactionType,
        purchaseRef,
        saleRef,
        category,
        expenseNote,
        cashPaid: cashPaid,
        bankPaid: bankPaid,
        creditCardPaid: creditCardPaid,
      ),
      _updateAmountAndTime(this.amount + amount, transactionTime),
    ]);
  }

  Future<void> removeAmount(
    double amount, {
    AT.TransactionType transactionType = AT.TransactionType.unknown,
    DocumentReference? purchaseRef,
    DocumentReference? saleRef,
    String? category,

    String? expenseNote,
  }) async {
    assert(
      type == null || type != BalanceType.expenseRecord || category != null,
    );
    Timestamp transactionTime = Timestamp.now();
    await Future.wait([
      _createTransaction(
        -amount,
        transactionTime,
        transactionType,
        purchaseRef,
        saleRef,
        category,
        expenseNote,
      ),
      _updateAmountAndTime(this.amount - amount, transactionTime),
    ]);
  }

  Future<void> setAmount(
    double amount, {
    String? note,
    String? category,
    String? expenseNote,
    AT.TransactionType transactionType = AT.TransactionType.unknown,
  }) async {
    this.note = note;

    if (this.amount < amount) {
      await addAmount(
        amount - this.amount,
        category: category,
        expenseNote: expenseNote,
        transactionType: transactionType,
      );
    } else if (this.amount > amount) {
      await removeAmount(
        this.amount - amount,
        category: category,
        expenseNote: expenseNote,
        transactionType: transactionType,
      );
    }

    await _save();
  }

  void clearTransactions() {
    transactions?.clear();
  }

  Future<void> loadTransactions(
    int limit, {
    DateTime? startTime,
    DateTime? endTime,
    bool descending = true,
  }) async {
    final query = FirebaseFirestore.instance
        .collection(Balance.collectionName)
        .doc(balanceTypeTitles[type])
        .collection(AT.Transaction.collectionName)
        .where('time', isGreaterThanOrEqualTo: startTime ?? DateTime(2000))
        .where('time', isLessThanOrEqualTo: endTime ?? DateTime.now())
        .orderBy('time', descending: descending)
        .limit(limit);

    if (this.transactions != null && this.transactions!.isNotEmpty) {
      query.startAfter([this.transactions!.last.time]);
    }

    final snapshot = await query.get();

    final transactions =
        snapshot.docs.map((doc) {
          return AT.Transaction.fromJson(doc.id, doc.data());
        }).toList();

    this.transactions ??= [];
    this.transactions!.addAll(transactions);
  }

  void _addTransaction(AT.Transaction transaction) {
    transactions ??= [];
    transactions!.add(transaction);
  }

  void _removeTransaction(AT.Transaction transaction) {
    transactions?.remove(transaction);
  }

  Future<void> _updateAmountAndTime(double amount, Timestamp time) async {
    this.amount = amount;
    lastTransaction = time;
    await _save();
  }

  Future<void> _save() async {
    final json = _toJson();
    final docRef = FirebaseFirestore.instance
        .collection(Balance.collectionName)
        .doc(balanceTypeTitles[type]);

    await docRef.set(json, SetOptions(merge: true));
  }

  Map<String, dynamic> _toJson() {
    return {
      'amount': amount,
      'last_transaction': lastTransaction,
      if (note != null) 'note': note,
    };
  }

  Future<void> _createTransaction(
    double amount,
    Timestamp transactionTime,
    AT.TransactionType transactionType,
    DocumentReference? purchaseRef,
    DocumentReference? saleRef,
    String? category,
    String? expenseNote, {
    double? cashPaid,
    double? bankPaid,
    double? creditCardPaid,
  }) async {
    try {
      // Create the transaction object
      AT.Transaction transaction = AT.Transaction(
        amount: amount,
        time: transactionTime,
        type: transactionType,
        purchaseRef: purchaseRef,
        saleRef: saleRef,
        category: category,
        note: expenseNote,
        cashPaid: cashPaid,
        bankPaid: bankPaid,
        creditCardPaid: creditCardPaid,
      );

      // Add the transaction to the balance-specific subcollection
      await FirebaseFirestore.instance
          .collection(Balance.collectionName) // 'Balances'
          .doc(balanceTypeTitles[type]) // e.g., 'Expense Record'
          .collection(AT.Transaction.collectionName) // 'Transactions'
          .add(transaction.toJson());
          
      print('Created transaction for ${balanceTypeTitles[type]}: amount=$amount, type=$transactionType');
    } catch (e) {
      print('Error creating transaction for ${balanceTypeTitles[type]}: $e');
      // Don't throw the error to prevent the entire operation from failing
    }
  }

  Future<List<AT.Transaction>> getTransactions({
    DateTime? startTime,
    DateTime? endTime,
    int? limit,
    bool descending = true,
    DocumentSnapshot? startAfter,
  }) async {
    if (type == null) {
      throw StateError('Cannot get transactions for Balance without type');
    }

    var query = FirebaseFirestore.instance
        .collection(Balance.collectionName)
        .doc(balanceTypeTitles[type])
        .collection(AT.Transaction.collectionName)
        .where('time', isGreaterThanOrEqualTo: startTime ?? DateTime(2000))
        .where('time', isLessThanOrEqualTo: endTime ?? DateTime.now());
    query = query.orderBy('time', descending: descending);

    if (limit != null) {
      query = query.limit(limit);
    }
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      return AT.Transaction.fromJson(doc.id, doc.data());
    }).toList();
  }
}
