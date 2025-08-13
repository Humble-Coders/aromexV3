import 'package:aromex/constants.dart';
import 'package:aromex/models/order.dart' as aromex_order;
import 'package:aromex/models/phone.dart';
import 'package:aromex/models/purchase.dart';
import 'package:aromex/models/supplier.dart';
import 'package:aromex/models/util.dart';
import 'package:aromex/pages/purchase/main.dart';
import 'package:aromex/widgets/custom_product_table.dart';
import 'package:aromex/widgets/custom_text_field.dart';
import 'package:aromex/pages/purchase/widgets/product_detail_dialog.dart';
import 'package:aromex/services/purchase.dart';
import 'package:aromex/widgets/searchable_dropdown.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PurchasePageCard extends StatefulWidget {
  final Function(aromex_order.Order order) onSubmit;
  final PurchaseCardSavedState savedState;
  const PurchasePageCard({
    super.key,
    required this.savedState,
    required this.onSubmit,
  });

  @override
  State<PurchasePageCard> createState() => PurchasePageCardState();
}

class PurchasePageCardState extends State<PurchasePageCard> {
  List<Supplier>? suppliers;
  Supplier? selectedSupplier;
  DateTime? selectedDate;
  String? orderNumber;
  DateTime? _internalSelectedDate;
  final TextEditingController orderNumberController = TextEditingController();
  final TextEditingController puchaseDateController = TextEditingController();
  final TextEditingController supplierController = TextEditingController();
  final FocusNode supplierFocusNode = FocusNode();

  // List of phones
  List<Phone> phones = [];
  List<DocumentReference> phoneRefs = [];

  void buildFromSavedState() {
    if (widget.savedState.orderId != null) {
      orderNumber = widget.savedState.orderId;
      orderNumberController.text = orderNumber!;
    } else {
      orderNumberController.text = orderNumber ?? "Loading...";
      generateOrderNumber().then((value) {
        orderNumber = value;
        orderNumberController.text = orderNumber!;
        widget.savedState.orderId = orderNumber;
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

    if (widget.savedState.suppliers != null) {
      suppliers = widget.savedState.suppliers;
      selectedSupplier = widget.savedState.selectedSupplier;
      if (selectedSupplier != null) {
        supplierController.text = selectedSupplier!.name;
      }
    } else {
      selectedSupplier = null;
      supplierController.clear();
      fetchSuppliers();
    }

    // FIX: Make sure to preserve phones from saved state
    phones = List.from(
      widget.savedState.phones,
    ); // Create a copy to avoid reference issues

    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    buildFromSavedState();
  }

  Future<String> generateOrderNumber() async {
    final count = await FirestoreHelper.count(Purchase.collectionName);
    return 'ORD-${count + 1}';
  }

  Future<void> fetchSuppliers() async {
    try {
      suppliers = await FirestoreHelper.getAll(
        Supplier.fromFirestore,
        FirebaseFirestore.instance.collection(Supplier.collectionName),
      );
    } catch (e) {
      suppliers = [];
    }
    widget.savedState.suppliers = suppliers;
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
                      title: "Order number",
                      textController: orderNumberController,
                      description: "Unique order number for this purchase",
                      isReadOnly: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      title: "Date",
                      textController: puchaseDateController,
                      description: "The date when this purchase was made",
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
                        SearchableDropdown<Supplier>(
                          title: "Supplier",
                          description: "Select a supplier for this purchase",
                          items: suppliers,
                          selectedItem: selectedSupplier,
                          controller: supplierController,
                          onChanged: (supplier) {
                            setState(() {
                              selectedSupplier = supplier;
                              widget.savedState.selectedSupplier = supplier;
                            });
                          },
                          getLabel: (supplier) => supplier.name,
                          onClear: () {
                            setState(() {
                              selectedSupplier = null;
                              widget.savedState.selectedSupplier = null;
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
                  onPressed: () {
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
                      phones.removeAt(idx);
                      // FIX: Update saved state when removing products
                      widget.savedState.phones = List.from(phones);
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
                            : () {
                              widget.onSubmit(
                                aromex_order.Order(
                                  orderNumber: orderNumber,
                                  scref: selectedSupplier!.snapshot!.reference,
                                  date: selectedDate,
                                  phones: phoneRefs,
                                  amount: phones.fold(
                                    0.0,
                                    (total, phone) => total + phone.price,
                                  ),
                                  scName: selectedSupplier!.name,
                                  phoneList: phones,
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
                      "Add Purchase",
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
    return orderNumberController.text.trim().isNotEmpty &&
        puchaseDateController.text.trim().isNotEmpty &&
        phones.isNotEmpty &&
        selectedSupplier != null;
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
                  // FIX: Update saved state when adding products
                  widget.savedState.phones = List.from(phones);
                });
              },
            ),
          ),
        );
      },
    );
  }

  bool allEmpty() {
    return selectedSupplier == null &&
        phones.isEmpty &&
        selectedDate == _internalSelectedDate;
  }
}
