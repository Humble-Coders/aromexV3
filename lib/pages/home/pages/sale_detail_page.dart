import 'package:aromex/models/balance_generic.dart';
import 'package:aromex/models/customer.dart';
import 'package:aromex/models/phone.dart';
import 'package:aromex/models/sale.dart';
import 'package:aromex/pages/home/pages/widgets/order_info_card.dart';
import 'package:aromex/pages/home/pages/widgets/payment_detail_card.dart';
import 'package:aromex/pages/home/pages/widgets/product_detail_card.dart';
import 'package:aromex/util.dart';
import 'package:aromex/widgets/custom_text_field.dart';
import 'package:aromex/widgets/generic_custom_table.dart';
import 'package:aromex/widgets/profile_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SaleDetailPage extends StatefulWidget {
  const SaleDetailPage({super.key, required this.sale, required this.onBack});
  final VoidCallback onBack;
  final Sale sale;

  @override
  State<SaleDetailPage> createState() => _SaleDetailPageState();
}

class _SaleDetailPageState extends State<SaleDetailPage> {
  String phoneNumber = '';
  DateTime createdAt = DateTime.now();
  bool isLoading = true;
  List<Phone> phoneList = [];

  String? middlemanPhoneNumber;
  DateTime? middlemanCreatedAt;
  String? middlemanName;

  ProductDetailCard? productDetailCard;

  Customer? customer;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    await fetchCustomerInfo();
    if (widget.sale.middlemanRef != null) {
      await fetchMiddlemanInfo();
    }
    await fetchPhones();
    setState(() {
      isLoading = false;
    });
  }

  String formatPaymentSource(Sale sale) {
    List<String> paymentParts = [];

    // Check for cash payment - keep original format
    if (sale.cashPaid != null && sale.cashPaid! > 0) {
      paymentParts.add('Cash(${sale.cashPaid!.toInt()})');
    }

    // Check for UPI payment - keep original format
    if (sale.upiPaid != null && sale.upiPaid! > 0) {
      paymentParts.add('UPI(${sale.upiPaid!.toInt()})');
    }

    // Check for bank payment - keep original format
    if (sale.bankPaid != null && sale.bankPaid! > 0) {
      paymentParts.add('Bank(${sale.bankPaid!.toInt()})');
    }

    // Check for credit payment - keep original format

    // If no specific payment amounts, fall back to original paymentSource
    if (paymentParts.isEmpty) {
      final paymentSourceTitle = balanceTypeTitles[sale.paymentSource];
      if (paymentSourceTitle != null) {
        return paymentSourceTitle.toString();
      }
      return "cash";
    }

    // Join multiple payment methods with comma and space - keep original format
    return paymentParts.join(', ');
  }

  Future<void> fetchCustomerInfo() async {
    try {
      final doc = await widget.sale.customerRef.get();
      customer = Customer.fromFirestore(doc);
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

  Future<void> fetchMiddlemanInfo() async {
    try {
      final doc = await widget.sale.middlemanRef!.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        middlemanPhoneNumber = data['phone'] ?? '';
        middlemanName = data['name'] ?? '';
        middlemanCreatedAt =
            data['createdAt'] is Timestamp
                ? (data['createdAt'] as Timestamp).toDate()
                : DateTime.now();
      }
    } catch (e) {
      print('Error fetching middleman: $e');
    }
  }

  Future<void> fetchPhones() async {
    try {
      final phoneSnapshots = await Future.wait(
        widget.sale.phones.map((ref) => ref.get()),
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
      // Load brand data for each phone
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
                    // Back button
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: widget.onBack,
                        ),

                        const Spacer(),
                        IconButton(
                          onPressed:
                              customer == null
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
                                                'Generate Bill',
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
                                                            // Proceed to generate the bill
                                                            generateBill(
                                                              sale: widget.sale,
                                                              customer:
                                                                  customer!,
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
                              orderId: widget.sale.orderNumber,
                              orderDate: formatDate(widget.sale.date),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: // In sale_detail_page.dart, update the PaymentDetailCard usage:
                                PaymentDetailCard(
                              amount: widget.sale.amount.toString(),
                              gst: widget.sale.gst.toString(),
                              pst: widget.sale.pst.toString(),
                              paid: widget.sale.paid.toString(),
                              credit: widget.sale.credit.toString(),
                              paymentSource: formatPaymentSource(
                                widget.sale,
                              ), // Changed this line
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ProfileCard(
                      name: widget.sale.customerName!,
                      phoneNumber: phoneNumber,
                      createdAt: createdAt,
                    ),
                    const SizedBox(height: 16),
                    if (widget.sale.middlemanRef != null)
                      ProfileCard(
                        name: middlemanName!,
                        phoneNumber: middlemanPhoneNumber!,
                        createdAt: middlemanCreatedAt!,
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Sales History',
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
