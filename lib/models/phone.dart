import 'package:aromex/models/generic_firebase_object.dart';
import 'package:aromex/models/phone_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Phone extends GenericFirebaseObject<Phone> {
  DocumentReference modelRef;
  DocumentSnapshot? model;
  DocumentReference? brandRef;
  DocumentSnapshot? brand;
  String color;
  double capacity;
  String imei;
  bool status;
  String carrier;
  DocumentReference? storageLocationRef;
  DocumentSnapshot? storageLocation;
  double price = 0.0;
  double? sellingPrice;
  DocumentReference? saleRef;
  DocumentReference? purchaseRef;

  String get collectionName => "${modelRef.path}/Phones";
  static String collectionNameByModel(PhoneModel model) {
    return "${model.collName}/${model.id}/Phones";
  }

  String get documentReference {
    return "${modelRef.path}/Phones/$id";
  }

  @override
  String get collName => collectionName;

  Phone({
    super.id,
    required this.modelRef,
    this.model,
    required this.color,
    required this.capacity,
    required this.price,
    required this.imei,
    required this.status,
    required this.carrier,
    required this.storageLocationRef,
    this.storageLocation,
    super.snapshot,
    this.brand,
    this.brandRef,
    this.sellingPrice,
    this.saleRef,
    this.purchaseRef,
  });

  Future<void> loadModel() async {
    model = await modelRef.get();
  }

  Future<void> loadBrand() async {
    if (brandRef != null) {
      brand = await brandRef!.get();
    }
  }

  Future<void> loadStorageLocation() async {
    if (storageLocationRef != null) {
      storageLocation = await storageLocationRef!.get();
    }
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      "color": color,
      "capacity": capacity,
      "price": price,
      "imei": imei,
      "status": status,
      "carrier": carrier,
      "storageLocationRef": storageLocationRef,
      "modelRef": modelRef,
      "brandRef": brandRef,
      "sellingPrice": sellingPrice,
      "saleRef": saleRef,
      "purchaseRef": purchaseRef,
    };
  }

  factory Phone.fromFirestore(DocumentSnapshot doc) {
    try {
      final data = doc.data();
      if (data == null) {
        throw ArgumentError('Document data is null');
      }
      
      final phoneData = data as Map<String, dynamic>;
      
      return Phone(
        id: doc.id,
        modelRef: doc.reference.parent.parent!,
        color: phoneData["color"] ?? '',
        capacity: (phoneData["capacity"] as num?)?.toDouble() ?? 0.0,
        price: (phoneData["price"] as num?)?.toDouble() ?? 0.0,
        imei: phoneData["imei"] ?? '',
        status: phoneData["status"] ?? false,
        carrier: phoneData["carrier"] ?? '',
        storageLocationRef: phoneData["storageLocationRef"] as DocumentReference? ?? 
            FirebaseFirestore.instance.collection('StorageLocations').doc('default'),
        snapshot: doc,
        brandRef: phoneData["brandRef"] as DocumentReference?,
        sellingPrice: (phoneData["sellingPrice"] as num?)?.toDouble(),
        saleRef: phoneData["saleRef"] as DocumentReference?,
        purchaseRef: phoneData["purchaseRef"] as DocumentReference?,
      );
    } catch (e) {
      print('Error creating Phone from Firestore document ${doc.id}: $e');
      // Return a default phone if there's an error
      return Phone(
        modelRef: FirebaseFirestore.instance.collection('PhoneModels').doc('default'),
        color: "Unknown",
        capacity: 0.0,
        price: 0.0,
        imei: "Unknown",
        status: false,
        carrier: "Unknown",
        storageLocationRef: FirebaseFirestore.instance.collection('StorageLocations').doc('default'),
      );
    }
  }

  @override
  String toString() {
    return "Phone: $id, ${modelRef.path}, $color, $capacity, $price, $imei, $status, $carrier, ${storageLocationRef?.path}, $sellingPrice";
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Phone) return false;
    return id == other.id;
  }

  @override
  int get hashCode {
    return id.hashCode;
  }
}
