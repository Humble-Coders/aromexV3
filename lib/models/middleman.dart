import 'package:aromex/models/generic_firebase_object.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Middleman extends GenericFirebaseObject<Middleman> {
  final String name;
  final String phone;
  final String email;
  final String address;
  final double commission;
  final DateTime createdAt;
  final double balance;
  final Timestamp? updatedAt;
  final List<DocumentReference>? transactionHistory;

  static const collectionName = "Middlemen";
  @override
  String get collName => collectionName;

  Middleman({
    super.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.address = '',
    required this.commission,
    required this.createdAt,
    this.balance = 0.0,
    this.transactionHistory,
    super.snapshot,
    this.updatedAt,
  });

  @override
  factory Middleman.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data();
      if (data == null) {
        throw ArgumentError('Document data is null');
      }
      
      final middlemanData = data as Map<String, dynamic>;
      
      return Middleman(
        id: doc.id,
        name: middlemanData['name'] ?? '',
        phone: middlemanData['phone'] ?? '',
        email: middlemanData['email'] ?? '',
        address: middlemanData['address'] ?? '',
        commission: (middlemanData['commission'] ?? 0.0).toDouble(),
        createdAt: (middlemanData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        balance: (middlemanData['balance'] ?? 0.0).toDouble(),
        transactionHistory: (middlemanData['transactionHistory'] as List<dynamic>?)
                ?.cast<DocumentReference>(),
        snapshot: doc,
        updatedAt: (middlemanData['updatedAt'] as Timestamp?),
      );
    } catch (e) {
      print('Error creating Middleman from Firestore document ${doc.id}: $e');
      // Return a default middleman if there's an error
      return Middleman(
        name: "Unknown",
        phone: "",
        commission: 0.0,
        createdAt: DateTime.now(),
      );
    }
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'commission': commission,
      'createdAt': Timestamp.fromDate(createdAt),
      'balance': balance,
      'transactionHistory': transactionHistory ?? [],
      'updatedAt': Timestamp.now(),
    };
  }
}
