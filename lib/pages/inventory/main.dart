import 'package:aromex/models/phone.dart';
import 'package:aromex/models/phone_brand.dart';
import 'package:aromex/models/phone_model.dart';
import 'package:aromex/models/storage_location.dart';
import 'package:aromex/models/util.dart';
import 'package:aromex/pages/inventory/widgets/location_brand_filter.dart';
import 'package:aromex/pages/inventory/widgets/location_inventory_brands.dart';
import 'package:aromex/pages/inventory/widgets/location_inventory_models.dart';
import 'package:aromex/pages/inventory/widgets/location_phone_filter.dart';
import 'package:aromex/pages/inventory/widgets/location_phones.dart';
import 'package:aromex/pages/inventory/widgets/phone_model_filter.dart';
import 'package:aromex/util.dart';
import 'package:aromex/widgets/custom_text_field.dart';
import 'package:aromex/widgets/generic_custom_table.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class InventoryPage extends StatefulWidget {
  final VoidCallback? onBack;
  const InventoryPage({super.key, this.onBack});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  // Storage Locations
  List<StorageLocation>? storageLocations;
  StorageLocation? __selectedStorageLocation;
  StorageLocation? selectedStorageLocation;

  // Phones and related
  List<Phone>? phones;
  List<PhoneBrand>? phoneBrands;
  PhoneBrand? __selectedPhoneBrand;
  PhoneBrand? selectedPhoneBrand;

  int? selectedCapacity;
  String? selectedColor;
  String? selectedCarrier;
  bool? selectedIsActive;

  // Mapping Phones to Locations
  Map<StorageLocation, List<Phone>> locationPhoneMap = {};

  // Page 1 - Location Brand
  // Page 2 - Phone Model
  // Page 3 - Phone
  int currentPage = 1;

  String phoneModelSearchQuery = "";
  TextEditingController phoneModelSearchController = TextEditingController();
  PhoneModel? selectedPhoneModel;

  @override
  void initState() {
    super.initState();

    // Load all storage locations and phone brands parallelly
    loadStorageLocations().then((locations) {
      setState(() {
        storageLocations = locations;
        __selectedStorageLocation = null;
      });
    });
    loadAllPhones().then((phones) {
      setState(() {
        this.phones = phones[0] as List<Phone>;
        phoneBrands = phones[1] as List<PhoneBrand>;

        // Populate the locationPhoneMap
        locationPhoneMap = {};
        for (var phone in this.phones!) {
          if (phone.storageLocation != null) {
            if (!locationPhoneMap.containsKey(
              StorageLocation.fromFirestore(phone.storageLocation!),
            )) {
              locationPhoneMap[StorageLocation.fromFirestore(
                    phone.storageLocation!,
                  )] =
                  [];
            }
            locationPhoneMap[StorageLocation.fromFirestore(
                  phone.storageLocation!,
                )]!
                .add(phone);
          }
        }

        __selectedPhoneBrand = null;
      });
    });
  }

  Future<List<StorageLocation>> loadStorageLocations() async {
    final locations = await FirestoreHelper.getAll(
      StorageLocation.fromFirestore,
      FirebaseFirestore.instance.collection(StorageLocation.collectionName),
    );

    return locations;
  }

  Future<List<dynamic>> loadAllPhones() async {
    // 0. Load storage locations
    final storageLocations = await FirestoreHelper.getAll(
      StorageLocation.fromFirestore,
      FirebaseFirestore.instance.collection(StorageLocation.collectionName),
    );
    // DocumentRef vs Location
    final Map<String, DocumentSnapshot> storageLocationCache = {};
    for (var location in storageLocations) {
      storageLocationCache[location.snapshot!.reference.path] =
          location.snapshot!;
    }

    // 1. Get all brands
    List<PhoneBrand> brands = await FirestoreHelper.getAll(
      PhoneBrand.fromFirestore,
      FirebaseFirestore.instance.collection(PhoneBrand.collectionName),
    );

    List<Phone> allPhones = [];

    // 2. For each brand, in parallel fetch models
    await Future.wait(
      brands.map((brand) async {
        List<PhoneModel> models = await FirestoreHelper.getAll(
          PhoneModel.fromFirestore,
          FirebaseFirestore.instance.collection(
            PhoneModel.collectionNameByBrand(brand.id!),
          ),
        );

        // 3. For each model, in parallel fetch phones
        await Future.wait(
          models.map((model) async {
            List<Phone> phones = await FirestoreHelper.getAll(
              Phone.fromFirestore,
              FirebaseFirestore.instance.collection(
                Phone.collectionNameByModel(model),
              ),
              whereNull: "saleRef",
            );

            for (var phone in phones) {
              phone.storageLocation =
                  storageLocationCache[phone.storageLocationRef!.path];
              phone.brand = brand.snapshot;
              phone.model = model.snapshot;
              allPhones.add(phone);
            }
          }),
        );
      }),
    );
    return [allPhones, brands];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Card(
        margin: const EdgeInsets.all(12),
        color: colorScheme.secondary,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main back button (similar to PurchaseRecord)
              if (currentPage == 1)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: widget.onBack,
                  ),
                )
              // Navigation back button (for internal pages)
              else
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 12,
                  ),
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        if (currentPage == 2) {
                          currentPage = 1;
                          selectedStorageLocation = __selectedStorageLocation;
                          selectedPhoneBrand = __selectedPhoneBrand;

                          phoneModelSearchQuery = "";
                          phoneModelSearchController.clear();
                        } else if (currentPage == 3) {
                          currentPage = 2;
                          selectedPhoneModel = null;
                        }
                      });
                    },
                    icon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          currentPage == 2
                              ? "Back to Brands"
                              : "Back to Models",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),

              if (currentPage == 1) const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child:
                    currentPage == 1
                        ? LocationBrandFilter(
                          storageLocations: storageLocations,
                          phoneBrands: phoneBrands,
                          onLocationSelected: (selectedLocation) {
                            setState(() {
                              __selectedStorageLocation = selectedLocation;
                              selectedStorageLocation = selectedLocation;
                            });
                          },
                          onBrandSelected: (selectedBrand) {
                            setState(() {
                              __selectedPhoneBrand = selectedBrand;
                              selectedPhoneBrand = selectedBrand;
                            });
                          },
                          selectedStorageLocation: __selectedStorageLocation,
                          selectedPhoneBrand: __selectedPhoneBrand,
                        )
                        : currentPage == 2
                        ? PhoneModelFilter(
                          onModelSearchChanged: (p0) {
                            setState(() {
                              phoneModelSearchQuery = p0;
                            });
                          },
                          phoneModelSearchController:
                              phoneModelSearchController,
                        )
                        : LocationPhoneFilter(
                          onFilterChanged: (capacity, color, carrier, status) {
                            setState(() {
                              selectedCapacity = capacity;
                              selectedColor = color;
                              selectedCarrier = carrier;
                              selectedIsActive = status;
                            });
                          },
                          capacities:
                              filter(
                                    phones!,
                                    selectedStorageLocation,
                                    selectedPhoneBrand,
                                    selectedPhoneModel,
                                    selectedCapacity,
                                    selectedColor,
                                    selectedCarrier,
                                    selectedIsActive,
                                  )
                                  .map((phone) => phone.capacity.toInt())
                                  .toSet()
                                  .toList(),
                          colors:
                              filter(
                                phones!,
                                selectedStorageLocation,
                                selectedPhoneBrand,
                                selectedPhoneModel,
                                selectedCapacity,
                                selectedColor,
                                selectedCarrier,
                                selectedIsActive,
                              ).map((phone) => phone.color).toSet().toList(),
                          carriers:
                              filter(
                                phones!,
                                selectedStorageLocation,
                                selectedPhoneBrand,
                                selectedPhoneModel,
                                selectedCapacity,
                                selectedColor,
                                selectedCarrier,
                                selectedIsActive,
                              ).map((phone) => phone.carrier).toSet().toList(),
                          isActive:
                              filter(
                                phones!,
                                selectedStorageLocation,
                                selectedPhoneBrand,
                                selectedPhoneModel,
                                selectedCapacity,
                                selectedColor,
                                selectedCarrier,
                                selectedIsActive,
                              ).map((phone) => phone.status).toSet().toList(),
                        ),
              ),
              const SizedBox(height: 24),
              currentPage == 1
                  ? GridView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.5,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount:
                        __selectedStorageLocation != null
                            ? 1
                            : storageLocations?.length ?? 0,
                    itemBuilder: (context, index) {
                      StorageLocation location =
                          __selectedStorageLocation ?? storageLocations![index];

                      // Get count for brands for this location
                      List<LocationInventoryData> data = [];
                      Map<PhoneBrand, int> brandCountMap = {};
                      for (var phone in locationPhoneMap[location] ?? []) {
                        PhoneBrand brand = PhoneBrand.fromFirestore(
                          phone.brand,
                        );
                        if (__selectedPhoneBrand != null &&
                            brand.id != __selectedPhoneBrand!.id) {
                          continue; // Skip if brand doesn't match
                        }
                        if (brandCountMap.containsKey(brand)) {
                          brandCountMap[brand] = brandCountMap[brand]! + 1;
                        } else {
                          brandCountMap[brand] = 1;
                        }
                      }
                      for (var entry in brandCountMap.entries) {
                        data.add(
                          LocationInventoryData(
                            phoneBrands: entry.key,
                            count: entry.value,
                          ),
                        );
                      }

                      // Sort data by brand name (ascending)
                      data.sort(
                        (a, b) =>
                            a.phoneBrands.name.compareTo(b.phoneBrands.name),
                      );

                      return LocationInventoryBrands(
                        storageLocation: location,
                        data: phones != null ? data : null,
                        onBrandSelected:
                            (location, brand) => {
                              selectedStorageLocation = location,
                              selectedPhoneBrand = brand,
                              setState(() {
                                currentPage = 2; // Move to Phone Model page
                              }),
                            },
                      );
                    },
                  )
                  : currentPage == 2
                  // Keep aspect ratio of 1.5 for Phone Model page
                  ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: LocationInventoryModels(
                      storageLocation: selectedStorageLocation!,
                      phoneBrand: selectedPhoneBrand!,
                      data:
                          phones != null
                              ? filter(
                                    locationPhoneMap[selectedStorageLocation]!,
                                    selectedStorageLocation,
                                    selectedPhoneBrand,
                                    null,
                                    null,
                                    null,
                                    null,
                                    null,
                                  )
                                  .where(
                                    (phone) =>
                                        phone.model != null &&
                                        PhoneModel.fromFirestore(
                                          phone.model!,
                                        ).name.toLowerCase().contains(
                                          phoneModelSearchQuery.toLowerCase(),
                                        ),
                                  )
                                  .map(
                                    (phone) => LocationInventoryDataModels(
                                      phoneModel: PhoneModel.fromFirestore(
                                        phone.model!,
                                      ),
                                      count:
                                          1, // Assuming each phone is counted once
                                    ),
                                  )
                                  .toList()
                              : null,
                      onModelSelected: (model) {
                        setState(() {
                          currentPage = 3; // Move to Phone page
                          selectedPhoneModel = model;
                        });
                      },
                    ),
                  )
                  : SelectableRegion(
                    selectionControls: MaterialTextSelectionControls(),
                    focusNode: FocusNode(),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: LocationPhones(
                        phones: filter(
                          phones!,
                          selectedStorageLocation,
                          selectedPhoneBrand,
                          selectedPhoneModel,
                          selectedCapacity,
                          selectedColor,
                          selectedCarrier,
                          selectedIsActive,
                        ),
                        storageLocation: selectedStorageLocation!,
                        phoneBrand: selectedPhoneBrand!,
                        phoneModel: selectedPhoneModel!,
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  List<Phone> filter(
    List<Phone> phones,
    StorageLocation? storageLocation,
    PhoneBrand? phoneBrand,
    PhoneModel? phoneModel,
    int? capacity,
    String? color,
    String? carrier,
    bool? isActive,
  ) {
    return phones.where((phone) {
      if (storageLocation != null &&
          StorageLocation.fromFirestore(phone.storageLocation!) !=
              storageLocation) {
        return false; // Phone not from selected storage location
      }
      if (phoneBrand != null &&
          PhoneBrand.fromFirestore(phone.brand!) != phoneBrand) {
        return false; // Phone not from selected brand
      }
      if (phoneModel != null &&
          PhoneModel.fromFirestore(phone.model!) != phoneModel) {
        return false; // Phone not from selected model
      }
      if (capacity != null && phone.capacity.toInt() != capacity) {
        return false;
      }
      if (color != null && phone.color != color) {
        return false;
      }
      if (carrier != null && phone.carrier != carrier) {
        return false;
      }
      if (isActive != null && phone.status != isActive) {
        return false;
      }
      return true;
    }).toList();
  }
}
