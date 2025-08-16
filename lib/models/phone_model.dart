import 'package:aromex/models/generic_firebase_object.dart';
import 'package:aromex/models/phone_brand.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PhoneModel extends GenericFirebaseObject<PhoneModel> {
  String name;
  DocumentReference brand;

  static String collectionName(DocumentReference brandRef) =>
      "${PhoneBrand.collectionName}/${brandRef.id}/Models";
  static String collectionNameByBrand(String brand) =>
      "${PhoneBrand.collectionName}/$brand/Models";
  @override
  String get collName => collectionName(brand);

  PhoneModel({
    super.id,
    required this.name,
    required this.brand,
    super.snapshot,
  });

  factory PhoneModel.empty(DocumentReference brandRef) {
    return PhoneModel(id: "", name: "", brand: brandRef);
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {"name": name, "brand": brand};
  }

  static PhoneModel fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data();
      if (data == null) {
        throw ArgumentError('Document data is null');
      }
      
      final modelData = data as Map<String, dynamic>;
      
      return PhoneModel(
        id: doc.id,
        name: modelData["name"] ?? '',
        brand: doc.reference.parent.parent!,
        snapshot: doc,
      );
    } catch (e) {
      print('Error creating PhoneModel from Firestore document ${doc.id}: $e');
      // Return a default model if there's an error
      return PhoneModel(
        name: "Unknown",
        brand: FirebaseFirestore.instance.collection('PhoneBrands').doc('default'),
      );
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PhoneModel) return false;
    return id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}
