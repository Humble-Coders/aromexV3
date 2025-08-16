import 'package:aromex/models/generic_firebase_object.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PhoneBrand extends GenericFirebaseObject<PhoneBrand> {
  String name;

  static const collectionName = "PhoneBrands";
  @override
  String get collName => collectionName;

  PhoneBrand({super.id, required this.name, super.snapshot});

  factory PhoneBrand.empty() {
    return PhoneBrand(id: "", name: "");
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {"name": name};
  }

  static PhoneBrand fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data();
      if (data == null) {
        throw ArgumentError('Document data is null');
      }
      
      final brandData = data as Map<String, dynamic>;
      
      return PhoneBrand(
        id: doc.id, 
        name: brandData["name"] ?? '', 
        snapshot: doc
      );
    } catch (e) {
      print('Error creating PhoneBrand from Firestore document ${doc.id}: $e');
      // Return a default brand if there's an error
      return PhoneBrand(
        name: "Unknown",
      );
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PhoneBrand) return false;
    return id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}
