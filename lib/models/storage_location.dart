import 'package:aromex/models/generic_firebase_object.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StorageLocation extends GenericFirebaseObject<StorageLocation> {
  String name;

  StorageLocation({super.id, required this.name, super.snapshot});

  factory StorageLocation.empty() {
    return StorageLocation(name: "");
  }

  static const String collectionName = "StorageLocations";
  @override
  String get collName => collectionName;

  @override
  Map<String, dynamic> toFirestore() {
    return {"name": name};
  }

  static StorageLocation fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data();
      if (data == null) {
        throw ArgumentError('Document data is null');
      }
      
      final locationData = data as Map<String, dynamic>;
      
      return StorageLocation(
        id: doc.id, 
        name: locationData["name"] ?? '', 
        snapshot: doc
      );
    } catch (e) {
      print('Error creating StorageLocation from Firestore document ${doc.id}: $e');
      // Return a default location if there's an error
      return StorageLocation(
        name: "Unknown",
      );
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! StorageLocation) return false;
    return id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}
