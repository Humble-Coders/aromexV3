import 'package:aromex/models/balance_generic.dart';
import 'package:aromex/models/phone.dart';
import 'package:aromex/models/purchase.dart';
import 'package:aromex/models/supplier.dart';
import 'package:aromex/pages/home/pages/widgets/order_info_card.dart';
import 'package:aromex/pages/home/pages/widgets/payment_detail_card.dart';
import 'package:aromex/pages/home/pages/widgets/product_detail_card.dart';
import 'package:aromex/util.dart';
import 'package:aromex/widgets/custom_text_field.dart';
import 'package:aromex/widgets/generic_custom_table.dart';
import 'package:aromex/widgets/profile_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PurchaseDetailPage extends StatefulWidget {
  const PurchaseDetailPage({
    super.key,
    required this.purchase,
    required this.onBack,
  });
  final VoidCallback onBack;
  final Purchase purchase;

  @override
  State<PurchaseDetailPage> createState() => _PurchaseDetailPageState();
}

class _PurchaseDetailPageState extends State<PurchaseDetailPage> {
  String phoneNumber = '';
  DateTime createdAt = DateTime.now();
  bool isLoading = true;
  List<Phone> phoneList = [];

  ProductDetailCard? productDetailCard;
  Supplier? supplier;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    await fetchSupplierInfo();
    await fetchPhones();
    setState(() {
      isLoading = false;
    });
  }

  String formatPaymentSource(Purchase purchase) {
    List<String> paymentParts = [];

    // Check for cash payment - keep original format
    if (purchase.cashPaid != null && purchase.cashPaid! >= 0) {
      paymentParts.add('Cash(${purchase.cashPaid!.toInt()})');
    }

    // Check for UPI payment - keep original format
    if (purchase.cardPaid != null && purchase.cardPaid! >= 0) {
      paymentParts.add('Card(${purchase.cardPaid!.toInt()})');
    }

    // Check for bank payment - keep original format
    if (purchase.bankPaid != null && purchase.bankPaid! >= 0) {
      paymentParts.add('Bank(${purchase.bankPaid!.toInt()})');
    }

    // If no specific payment amounts, fall back to original paymentSource
    if (paymentParts.isEmpty) {
      final paymentSourceTitle = balanceTypeTitles[purchase.paymentSource];
      if (paymentSourceTitle != null) {
        return paymentSourceTitle.toString();
      }
      return "cash";
    }

    // Join multiple payment methods with comma and space - keep original format
    return paymentParts.join(', ');
  }

  Future<void> fetchSupplierInfo() async {
    try {
      final doc = await widget.purchase.supplierRef.get();
      supplier = Supplier.fromFirestore(doc);
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        phoneNumber = data['phone'] ?? '';
        createdAt =
            data['createdAt'] is Timestamp
                ? (data['createdAt'] as Timestamp).toDate()
                : DateTime.now();
      }
    } catch (e) {
      print('Error fetching supplier: $e');
    }
  }

  Future<void> fetchPhones() async {
    try {
      final phoneSnapshots = await Future.wait(
        widget.purchase.phones.map((ref) => ref.get()),
      );

      phoneList =
          phoneSnapshots
              .where((doc) => doc.exists)
              .map((doc) => Phone.fromFirestore(doc))
              .toList();

      for (final phone in phoneList) {
        phone.loadStorageLocation();
      }

      // Load model data for each phone
      await Future.wait(phoneList.map((phone) => phone.loadModel()));
      await Future.wait(phoneList.map((phone) => phone.loadBrand()));
    } catch (e) {
      print('Error fetching phone data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return productDetailCard ??
        (isLoading
            ? const Center(child: CircularProgressIndicator())
            : Card(
              margin: const EdgeInsets.all(12.0),
              color: colorScheme.secondary,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button and PDF button row
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: widget.onBack,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed:
                              supplier == null
                                  ? null
                                  : () {
                                    showDialog(
                                      context: context,
                                      builder: (_) {
                                        TextEditingController noteController =
                                            TextEditingController();
                                        TextEditingController
                                        adjustmentController =
                                            TextEditingController();
                                        String? adjustmentError;
                                        return StatefulBuilder(
                                          builder: (context, setState) {
                                            return AlertDialog(
                                              backgroundColor:
                                                  colorScheme.secondary,
                                              title: Text(
                                                'Generate Purchase Bill',
                                                style:
                                                    Theme.of(
                                                      context,
                                                    ).textTheme.titleLarge,
                                              ),
                                              content: SizedBox(
                                                width:
                                                    MediaQuery.of(
                                                      context,
                                                    ).size.width *
                                                    0.6,
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    CustomTextField(
                                                      title: "Notes",
                                                      textController:
                                                          noteController,
                                                      description:
                                                          "This will be visible on the bill",
                                                      isMandatory: false,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    CustomTextField(
                                                      title: "Adjustment",
                                                      error: adjustmentError,
                                                      isMandatory: false,
                                                      textController:
                                                          adjustmentController,
                                                      onChanged: (p0) {
                                                        setState(() {
                                                          if (p0
                                                              .trim()
                                                              .isEmpty) {
                                                            adjustmentError =
                                                                null;
                                                            return;
                                                          }

                                                          try {
                                                            double.parse(p0);
                                                            adjustmentError =
                                                                null;
                                                          } catch (_) {
                                                            adjustmentError =
                                                                "Invalid number";
                                                          }
                                                        });
                                                      },
                                                      description:
                                                          "This will be subtracted from the total amount",
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  style: TextButton.styleFrom(
                                                    backgroundColor:
                                                        colorScheme.primary,
                                                  ),
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                  },
                                                  child: Text(
                                                    style: TextStyle(
                                                      color:
                                                          colorScheme.secondary,
                                                    ),
                                                    'Cancel',
                                                  ),
                                                ),
                                                TextButton(
                                                  style: TextButton.styleFrom(
                                                    backgroundColor:
                                                        colorScheme.primary,
                                                  ),
                                                  onPressed:
                                                      adjustmentError == null
                                                          ? () {
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                            // Proceed to generate the purchase bill
                                                            generatePurchaseBill(
                                                              purchase:
                                                                  widget
                                                                      .purchase,
                                                              supplier:
                                                                  supplier!,
                                                              phones: phoneList,
                                                              note:
                                                                  noteController
                                                                          .text
                                                                          .trim()
                                                                          .isNotEmpty
                                                                      ? noteController
                                                                          .text
                                                                          .trim()
                                                                      : null,
                                                              adjustment:
                                                                  adjustmentController
                                                                          .text
                                                                          .trim()
                                                                          .isNotEmpty
                                                                      ? double.parse(
                                                                        adjustmentController
                                                                            .text
                                                                            .trim(),
                                                                      )
                                                                      : null,
                                                            );
                                                          }
                                                          : null,
                                                  child: Text(
                                                    style: TextStyle(
                                                      color:
                                                          colorScheme.secondary,
                                                    ),
                                                    'Generate',
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                          icon: Icon(Icons.picture_as_pdf),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 1,
                            child: OrderInfoCard(
                              orderId: widget.purchase.orderNumber,
                              orderDate: formatDate(widget.purchase.date),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: PaymentDetailCard(
                              amount: widget.purchase.amount.toString(),
                              gst: widget.purchase.gst.toString(),
                              pst: widget.purchase.pst.toString(),
                              paid: widget.purchase.paid.toString(),
                              credit: widget.purchase.credit.toString(),
                              paymentSource: formatPaymentSource(
                                widget.purchase,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ProfileCard(
                      name: widget.purchase.supplierName,
                      phoneNumber: phoneNumber,
                      createdAt: createdAt,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Purchase History',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GenericCustomTable<Phone>(
                      onTap: (p) {
                        setState(() {
                          productDetailCard = ProductDetailCard(
                            phone: p,
                            onBack: () {
                              setState(() {
                                productDetailCard = null;
                              });
                            },
                          );
                        });
                      },
                      entries: phoneList,
                      headers: ["Model", "IMEI/Serial", "Capacity", "Price"],
                      valueGetters: [
                        (p) =>
                            p.model != null && p.model!.exists
                                ? (p.model!.data()
                                        as Map<String, dynamic>)['name'] ??
                                    'Unknown'
                                : 'Loading...',
                        (p) => p.imei,
                        (p) => p.capacity.toString(),
                        (p) => formatCurrency(p.price),
                      ],
                    ),
                  ],
                ),
              ),
            ));
  }
}
