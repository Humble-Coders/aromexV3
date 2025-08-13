import 'package:aromex/models/balance_generic.dart';
import 'package:aromex/models/order.dart';
import 'package:aromex/models/purchase.dart';
import 'package:aromex/models/supplier.dart'; // Add this import for supplier
import 'package:aromex/widgets/custom_text_field.dart';
import 'package:aromex/services/purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart'
    hide Order; // Add this import
import 'package:flutter/material.dart';

class FinalPurchaseCard extends StatefulWidget {
  final Order order;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;
  const FinalPurchaseCard({
    super.key,
    required this.onCancel,
    required this.order,
    required this.onSubmit,
  });

  @override
  State<FinalPurchaseCard> createState() => _FinalPurchaseCardState();
}

class _FinalPurchaseCardState extends State<FinalPurchaseCard> {
  final TextEditingController _gstController = TextEditingController();
  final TextEditingController _pstController = TextEditingController();
  late TextEditingController _amountController;
  final TextEditingController _totalController = TextEditingController();
  final TextEditingController _paidController = TextEditingController();
  final TextEditingController _creditController = TextEditingController();
  BalanceType? paymentSource;
  final TextEditingController _bankController = TextEditingController();
  final TextEditingController _upiController = TextEditingController();
  final TextEditingController _cashController = TextEditingController();
  // Calculate Credit
  String? bankError;
  String? upiError;
  String? cashError;

  void updateCredit() {
    double total = double.tryParse(_totalController.text) ?? 0;
    double bankAmount = double.tryParse(_bankController.text) ?? 0;
    double upiAmount = double.tryParse(_upiController.text) ?? 0;
    double cashAmount = double.tryParse(_cashController.text) ?? 0;

    double totalPaid = bankAmount + upiAmount + cashAmount;

    if (totalPaid > total) {
      setState(() {
        // Set error for whichever field was last modified or all of them
        if (bankAmount > 0)
          bankError = "Total paid can't be more than total amount";
        if (upiAmount > 0)
          upiError = "Total paid can't be more than total amount";
        if (cashAmount > 0)
          cashError = "Total paid can't be more than total amount";
        creditError = null;
      });
      return;
    }

    setState(() {
      // Clear all payment errors
      bankError = null;
      upiError = null;
      cashError = null;

      double credit = total - totalPaid;
      _creditController.text = credit.toStringAsFixed(2);
      creditError = null;
    });
  }

  // Calculate Total
  void updateTotal() {
    double amount = double.tryParse(_amountController.text) ?? 0;
    double gst = double.tryParse(_gstController.text) ?? 0;
    double pst = double.tryParse(_pstController.text) ?? 0;

    double total = amount + (amount * gst / 100) + (amount * pst / 100);
    _totalController.text = total.toStringAsFixed(2);
    updateCredit();
  }

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.order.amount.toStringAsFixed(2),
    );
    updateTotal();
    updateCredit();
  }

  // Errors
  String? gstError;
  String? pstError;
  String? paidError;
  String? creditError;

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
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      title: "Amount",
                      textController: _amountController,
                      description: "Total amount of purchase",
                      isReadOnly: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      title: "GST",
                      textController: _gstController,
                      description: "GST Percent on the total purchase",
                      error: gstError,
                      onChanged: (value) {
                        if (value.isEmpty) {
                          setState(() {
                            gstError = "GST cannot be empty";
                          });
                        } else if (double.tryParse(value) == null) {
                          setState(() {
                            gstError = "GST must be a number";
                          });
                        } else {
                          setState(() {
                            gstError = null;
                          });
                        }
                        updateTotal();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      title: "PST",
                      textController: _pstController,
                      description: "PST Percent on the total purchase",
                      error: pstError,
                      onChanged: (value) {
                        if (value.isEmpty) {
                          setState(() {
                            pstError = "PST cannot be empty";
                          });
                        } else if (double.tryParse(value) == null) {
                          setState(() {
                            pstError = "PST must be a number";
                          });
                        } else {
                          setState(() {
                            pstError = null;
                          });
                        }
                        updateTotal();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Divider(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      title: "Total",
                      textController: _totalController,
                      description: "Total amount of purchase",
                      isReadOnly: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Row(
                      children: [
                        // Bank Field
                        Expanded(
                          child: Row(
                            children: [
                              // Bank Field
                              Expanded(
                                child: CustomTextField(
                                  title: "Bank",
                                  textController: _bankController,
                                  description: "Bank payment",
                                  error: bankError,

                                  onChanged: (value) {
                                    if (value.isNotEmpty &&
                                        double.tryParse(value) == null) {
                                      setState(() {
                                        bankError =
                                            "Bank must be a valid number";
                                      });
                                    } else if (value.isNotEmpty &&
                                        double.parse(value) < 0) {
                                      setState(() {
                                        bankError =
                                            "Bank amount cannot be negative";
                                      });
                                    } else {
                                      setState(() {
                                        bankError = null;
                                      });
                                    }
                                    updateCredit();
                                  },
                                ),
                              ),
                              SizedBox(width: 8), // Spacing between fields
                              // UPI Field
                              Expanded(
                                child: CustomTextField(
                                  title: "Card",
                                  textController: _upiController,
                                  description: "Credir Card Pay",
                                  error: upiError,

                                  onChanged: (value) {
                                    if (value.isNotEmpty &&
                                        double.tryParse(value) == null) {
                                      setState(() {
                                        upiError =
                                            "Number must be a valid number";
                                      });
                                    } else if (value.isNotEmpty &&
                                        double.parse(value) < 0) {
                                      setState(() {
                                        upiError =
                                            "Card amount cannot be negative";
                                      });
                                    } else {
                                      setState(() {
                                        upiError = null;
                                      });
                                    }
                                    updateCredit();
                                  },
                                ),
                              ),
                              SizedBox(width: 8), // Spacing between fields
                              // Cash Field
                              Expanded(
                                child: CustomTextField(
                                  title: "Cash",
                                  textController: _cashController,
                                  description: "Cash payment",
                                  error: cashError,

                                  onChanged: (value) {
                                    if (value.isNotEmpty &&
                                        double.tryParse(value) == null) {
                                      setState(() {
                                        cashError =
                                            "Cash must be a valid number";
                                      });
                                    } else if (value.isNotEmpty &&
                                        double.parse(value) < 0) {
                                      setState(() {
                                        cashError = null;
                                      });
                                    } else {
                                      setState(() {
                                        cashError = null;
                                      });
                                    }
                                    updateCredit();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      title: "Credit",
                      textController: _creditController,
                      description: "Total amount credit",
                      isReadOnly: true,
                      error: creditError,
                      onChanged: (value) {
                        if (double.tryParse(value) == null) {
                          setState(() {
                            creditError = "Credit must be a number";
                          });
                        } else {
                          setState(() {
                            creditError = null;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      widget.onCancel();
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
                              final purchase = Purchase(
                                orderNumber: widget.order.orderNumber!,
                                phones: widget.order.phones!,
                                supplierRef: widget.order.scref!,
                                supplierName: widget.order.scName,
                                amount: widget.order.amount,
                                bankPaid: double.parse(_bankController.text),
                                upiPaid: double.parse(_upiController.text),
                                cashPaid: double.parse(_cashController.text),
                                gst: double.parse(_gstController.text),
                                pst: double.parse(_pstController.text),
                                date: widget.order.date!,
                                total:
                                    double.tryParse(_totalController.text) ??
                                    0.0,
                                paid:
                                    double.tryParse(_paidController.text) ??
                                    0.0,
                                credit:
                                    -1 *
                                    (double.tryParse(_creditController.text) ??
                                        0.0),
                              );
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) {
                                  return Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                              );
                              try {
                                await createPurchase(widget.order, purchase);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Purchase saved successfully",
                                      ),
                                    ),
                                  );
                                  widget.onSubmit();
                                  Navigator.pop(context);

                                  // Bill generation dialog - same as in FinalSaleCard
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
                                                mainAxisSize: MainAxisSize.min,
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
                                                    textController:
                                                        adjustmentController,
                                                    isMandatory: false,
                                                    onChanged: (p0) {
                                                      setState(() {
                                                        if (p0.trim().isEmpty) {
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
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                },
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed:
                                                    adjustmentError == null
                                                        ? () async {
                                                          // Get supplier instead of customer
                                                          Supplier supplier =
                                                              Supplier.fromFirestore(
                                                                await FirebaseFirestore
                                                                    .instance
                                                                    .doc(
                                                                      widget
                                                                          .order
                                                                          .scref!
                                                                          .path,
                                                                    )
                                                                    .get(),
                                                              );
                                                          // Proceed to generate the purchase bill
                                                          generatePurchaseBill(
                                                            // Assuming you have this function
                                                            purchase: purchase,
                                                            supplier: supplier,
                                                            phones:
                                                                widget
                                                                    .order
                                                                    .phoneList,
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
                                                          Navigator.of(
                                                            context,
                                                          ).pop();
                                                        }
                                                        : null,
                                                child: const Text('Generate'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Error: $e")),
                                  );
                                }
                              }
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
    return gstError == null &&
        pstError == null &&
        paidError == null &&
        creditError == null &&
        _amountController.text.trim().isNotEmpty &&
        _totalController.text.trim().isNotEmpty &&
        _gstController.text.trim().isNotEmpty &&
        _pstController.text.trim().isNotEmpty &&
        _bankController.text.trim().isNotEmpty &&
        _upiController.text.trim().isNotEmpty &&
        _cashController.text.trim().isNotEmpty &&
        _creditController.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _bankController.dispose();
    _upiController.dispose();
    _cashController.dispose();
    _gstController.dispose();
    _pstController.dispose();
    _amountController.dispose();
    _totalController.dispose();
    _paidController.dispose();
    _creditController.dispose();
    super.dispose();
  }
}
