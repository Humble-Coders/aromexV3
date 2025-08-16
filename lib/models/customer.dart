import 'package:aromex/models/generic_firebase_object.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Customer extends GenericFirebaseObject<Customer> {
  final String name;
  final String phone;
  final String email;
  final String address;
  final double balance;
  final DateTime createdAt;
  final Timestamp? updatedAt;
  final String notes;
  final List<DocumentReference>? transactionHistory;

  static const collectionName = "Customers";
  @override
  String get collName => collectionName;

  Customer({
    super.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.address = '',
    required this.createdAt,
    this.balance = 0.0,
    this.transactionHistory,
    super.snapshot,
    required this.updatedAt,
    this.notes = '',
  });

  @override
  factory Customer.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data();
      if (data == null) {
        throw ArgumentError('Document data is null');
      }
      
      final customerData = data as Map<String, dynamic>;
      
      return Customer(
        id: doc.id,
        name: customerData['name'] ?? '',
        phone: customerData['phone'] ?? '',
        email: customerData['email'] ?? '',
        address: customerData['address'] ?? '',
        createdAt: (customerData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        balance: (customerData['balance'] ?? 0.0).toDouble(),
        transactionHistory: (customerData['transactionHistory'] as List<dynamic>?)
                ?.cast<DocumentReference>(),
        snapshot: doc,
        updatedAt: (customerData['updatedAt'] as Timestamp?),
        notes: customerData['notes'] ?? '',
      );
    } catch (e) {
      print('Error creating Customer from Firestore document ${doc.id}: $e');
      // Return a default customer if there's an error
      return Customer(
        name: "Unknown",
        phone: "",
        createdAt: DateTime.now(),
        updatedAt: Timestamp.now(),
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
      'createdAt': Timestamp.fromDate(createdAt),
      'balance': balance,
      'transactionHistory': transactionHistory ?? [],
      'updatedAt': Timestamp.now(),
      'notes': notes,
    };
  }
}
