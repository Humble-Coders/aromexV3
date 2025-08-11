import 'package:aromex/constants.dart';
import 'package:aromex/models/customer.dart';
import 'package:aromex/models/order.dart' as aromex_order;
import 'package:aromex/models/phone.dart';
import 'package:aromex/models/phone_brand.dart';
import 'package:aromex/models/phone_model.dart';
import 'package:aromex/models/sale.dart';
import 'package:aromex/models/storage_location.dart';
import 'package:aromex/models/util.dart';
import 'package:aromex/pages/sale/main.dart';
import 'package:aromex/pages/sale/widgets/product_detail_dialog.dart';
import 'package:aromex/widgets/custom_product_table.dart';
import 'package:aromex/widgets/custom_text_field.dart';
import 'package:aromex/widgets/searchable_dropdown.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SalePageCard extends StatefulWidget {
  final Function(aromex_order.Order order) onSubmit;
  final SaleCardSavedState savedState;
  const SalePageCard({
    super.key,
    required this.onSubmit,
    required this.savedState,
  });

  @override
  State<SalePageCard> createState() => SalePageCardState();
}

class SalePageCardState extends State<SalePageCard> {
  List<Customer>? customers;
  Customer? selectedCustomer;
  DateTime? selectedDate;
  String? saleNumber;
  DateTime? _internalSelectedDate;
  final TextEditingController saleNumberController = TextEditingController();
  final TextEditingController puchaseDateController = TextEditingController();
  final TextEditingController customerController = TextEditingController();
  final FocusNode customerFocusNode = FocusNode();

  // List of phones
  List<Phone> phones = [];
  List<DocumentReference> phoneRefs = [];
  List<Phone>? allPhones;

  void buildFromSavedState() {
    if (widget.savedState.saleId != null) {
      saleNumber = widget.savedState.saleId;
      saleNumberController.text = saleNumber!;
    } else {
      saleNumberController.text = saleNumber ?? "Loading...";
      generateSaleNumber().then((value) {
        saleNumber = value;
        saleNumberController.text = saleNumber!;
        widget.savedState.saleId = saleNumber;
      });
    }

    if (widget.savedState.date != null) {
      selectedDate = widget.savedState.date;
      _internalSelectedDate = widget.savedState.internalSelectedDate;
      puchaseDateController.text = DateFormat(
        purchaseDateTimeFormat,
      ).format(selectedDate!);
    } else {
      _internalSelectedDate = DateTime.now();
      selectedDate = _internalSelectedDate;
      puchaseDateController.text = DateFormat(
        purchaseDateTimeFormat,
      ).format(selectedDate!);
      widget.savedState.date = selectedDate;
      widget.savedState.internalSelectedDate = _internalSelectedDate;
    }

    if (widget.savedState.customers != null) {
      customers = widget.savedState.customers;
      selectedCustomer = widget.savedState.selectedCustomer;
      if (selectedCustomer != null) {
        customerController.text = selectedCustomer!.name;
      }
    } else {
      selectedCustomer = null;
      customerController.clear();
      fetchCustomers();
    }

    // FIX: Create copies of the lists to avoid reference issues
    phones = List.from(widget.savedState.phones);
    phoneRefs = List.from(widget.savedState.phoneRefs);
    allPhones =
        widget.savedState.allPhones != null
            ? List.from(widget.savedState.allPhones!)
            : null;

    if (allPhones == null) getAllPhones();

    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    buildFromSavedState();
  }

  Future<void> getAllPhones() async {
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

    allPhones = [];

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
              allPhones!.add(phone);
            }
          }),
        );
      }),
    );

    // FIX: Update saved state with loaded phones
    widget.savedState.allPhones = List.from(allPhones!);
    setState(() {});
  }

  Future<String> generateSaleNumber() async {
    final count = await FirestoreHelper.count(Sale.collectionName);
    return 'ORD-${count + 1}';
  }

  Future<void> fetchCustomers() async {
    try {
      customers = await FirestoreHelper.getAll(
        Customer.fromFirestore,
        FirebaseFirestore.instance.collection(Customer.collectionName),
      );
    } catch (e) {
      customers = [];
    }
    widget.savedState.customers = customers;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      color: colorScheme.secondary,
      child: Padding(
        padding: const EdgeInsets.all(36.0),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.secondary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.onSurfaceVariant.withAlpha(50),
            ),
          ),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      title: "Sale number",
                      textController: saleNumberController,
                      description: "Unique sale number for this purchase",
                      isReadOnly: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      title: "Date",
                      textController: puchaseDateController,
                      description: "The date when this sale was made",
                      isReadOnly: true,
                      suffixIcon: Icon(Icons.calendar_month_outlined),
                      onTap: () async {
                        FocusScope.of(context).requestFocus(FocusNode());
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );

                        if (pickedDate != null) {
                          setState(() {
                            puchaseDateController.text = DateFormat(
                              purchaseDateTimeFormat,
                            ).format(pickedDate);
                            selectedDate = pickedDate;
                            widget.savedState.date = pickedDate;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SearchableDropdown<Customer>(
                          title: "Customer",
                          description: "The customer of the product",
                          items: customers,
                          selectedItem: selectedCustomer,
                          controller: customerController,
                          onChanged: (customer) {
                            setState(() {
                              selectedCustomer = customer;
                              widget.savedState.selectedCustomer = customer;
                            });
                          },
                          getLabel: (customer) => customer.name,
                          onClear: () {
                            setState(() {
                              selectedCustomer = null;
                              widget.savedState.selectedCustomer = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed:
                      allPhones == null
                          ? null
                          : () {
                            showAddProductDialog();
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.secondary,
                    padding: EdgeInsets.symmetric(horizontal: 60, vertical: 24),
                    side: BorderSide(color: colorScheme.primary),
                  ),
                  child: Text(
                    "Add product",
                    style: textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: CustomProductTable(
                  phones: phones,
                  onRemove: (idx) {
                    setState(() {
                      allPhones!.add(phones[idx]);
                      phones.removeAt(idx);
                      phoneRefs.removeAt(idx);

                      // FIX: Update saved state when removing products
                      widget.savedState.phones = List.from(phones);
                      widget.savedState.phoneRefs = List.from(phoneRefs);
                      widget.savedState.allPhones = List.from(allPhones!);
                    });
                  },
                  onCopy: (idx) {
                    showAddProductDialog(prefillWith: phones[idx]);
                  },
                ),
              ),
              const SizedBox(height: 36),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed:
                        allEmpty()
                            ? null
                            : () {
                              widget.savedState.clear();
                              buildFromSavedState();
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      padding: EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 16,
                      ),
                    ),
                    child: Text(
                      "Cancel",
                      style: TextStyle(color: colorScheme.onPrimary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed:
                        (!validate())
                            ? null
                            : () async {
                              widget.onSubmit(
                                aromex_order.Order(
                                  orderNumber: saleNumber,
                                  scref: selectedCustomer!.snapshot!.reference,
                                  date: selectedDate,
                                  phones: phoneRefs,
                                  scName: selectedCustomer!.name,
                                  amount: phones.fold(
                                    0.0,
                                    (total, phone) =>
                                        total + phone.sellingPrice!,
                                  ),
                                  phoneList: List<Phone>.from(phones),
                                  originalPrice: phones.fold(
                                    0.0,
                                    (total, phone) => total! + phone.price,
                                  ),
                                ),
                              );
                            },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 16,
                      ),
                      backgroundColor: colorScheme.primary,
                    ),
                    child: Text(
                      "Add Sale",
                      style: TextStyle(color: colorScheme.onPrimary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool validate() {
    return saleNumberController.text.trim().isNotEmpty &&
        puchaseDateController.text.trim().isNotEmpty &&
        phones.isNotEmpty &&
        selectedCustomer != null;
  }

  void showAddProductDialog({Phone? prefillWith}) {
    showDialog(
      context: context,
      builder: (context) {
        return Align(
          alignment: Alignment.center,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width * 0.125,
              vertical: MediaQuery.of(context).size.height * 0.125,
            ),
            child: ProductDetailDialog(
              // FIX: Only prefill when explicitly copying a product
              prefillWith: prefillWith,
              onProductAdded: (product) {
                Navigator.pop(context);
                setState(() {
                  phones.add(product);
                  phoneRefs.add(product.snapshot!.reference);
                  allPhones!.remove(product);

                  // FIX: Update saved state when adding products
                  widget.savedState.phones = List.from(phones);
                  widget.savedState.phoneRefs = List.from(phoneRefs);
                  widget.savedState.allPhones = List.from(allPhones!);
                });
              },
              allPhones: allPhones!,
            ),
          ),
        );
      },
    );
  }

  bool allEmpty() {
    return selectedCustomer == null &&
        phones.isEmpty &&
        selectedDate == _internalSelectedDate;
  }
}
