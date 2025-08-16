import 'package:aromex/models/generic_firebase_object.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Supplier extends GenericFirebaseObject<Supplier> {
  final String name;
  final String phone;
  final String email;
  final String address;
  final DateTime createdAt;
  final Timestamp? updatedAt;
  final double balance;
  final List<DocumentReference>? transactionHistory;
  final String notes;

  static const collectionName = "Suppliers";
  @override
  String get collName => collectionName;

  Supplier({
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
  factory Supplier.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data();
      if (data == null) {
        throw ArgumentError('Document data is null');
      }
      
      final supplierData = data as Map<String, dynamic>;
      
      return Supplier(
        id: doc.id,
        name: supplierData['name'] ?? '',
        phone: supplierData['phone'] ?? '',
        email: supplierData['email'] ?? '',
        address: supplierData['address'] ?? '',
        createdAt: (supplierData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        balance: (supplierData['balance'] ?? 0.0).toDouble(),
        transactionHistory: (supplierData['transactionHistory'] as List<dynamic>?)
                ?.cast<DocumentReference>(),
        snapshot: doc,
        updatedAt: (supplierData['updatedAt'] as Timestamp?),
        notes: supplierData['notes'] ?? '',
      );
    } catch (e) {
      print('Error creating Supplier from Firestore document ${doc.id}: $e');
      // Return a default supplier if there's an error
      return Supplier(
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
