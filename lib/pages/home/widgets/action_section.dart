import 'package:aromex/pages/home/pages/add_customer.dart';
import 'package:aromex/pages/home/main.dart';
import 'package:aromex/pages/home/pages/add_expense.dart';
import 'package:aromex/pages/home/pages/add_middleman.dart';
import 'package:aromex/pages/home/widgets/action_card.dart';
import 'package:aromex/pages/purchase/widgets/product_detail_dialog.dart';
import 'package:aromex/pages/home/pages/add_supplier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ActionSection extends StatefulWidget {
  final Function(Pages) onPageChange;
  const ActionSection({super.key, required this.onPageChange});

  @override
  State<ActionSection> createState() => _ActionSectionState();
}

class _ActionSectionState extends State<ActionSection> {
  bool _isCreatingProduct = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: ActionCard(
                  icon: SvgPicture.asset(
                    'assets/icons/customer.svg',
                    width: 40,
                    height: 40,
                  ),
                  title: 'Add Customer',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return Align(
                          alignment: Alignment.center,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.125,
                              vertical:
                                  MediaQuery.of(context).size.height * 0.125,
                            ),
                            child: const AddCustomer(),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: ActionCard(
                  icon: SvgPicture.asset(
                    'assets/icons/supplier.svg',
                    width: 40,
                    height: 40,
                  ),
                  title: 'Add Supplier',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return Align(
                          alignment: Alignment.center,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.125,
                              vertical:
                                  MediaQuery.of(context).size.height * 0.125,
                            ),
                            child: const AddSupplier(),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: ActionCard(
                  icon: SvgPicture.asset(
                    'assets/icons/middleman.svg',
                    width: 40,
                    height: 40,
                  ),
                  title: 'Add Middleman',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return Align(
                          alignment: Alignment.center,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.125,
                              vertical:
                                  MediaQuery.of(context).size.height * 0.125,
                            ),
                            child: const AddMiddleman(),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child:
                    _isCreatingProduct
                        ? Align(
                          alignment: Alignment.center,
                          child: CircularProgressIndicator(),
                        )
                        : ActionCard(
                          icon: SvgPicture.asset(
                            'assets/icons/product.svg',
                            width: 40,
                            height: 40,
                          ),
                          title: 'Add Product',
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return Align(
                                  alignment: Alignment.center,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal:
                                          MediaQuery.of(context).size.width *
                                          0.125,
                                      vertical:
                                          MediaQuery.of(context).size.height *
                                          0.125,
                                    ),
                                    child: ProductDetailDialog(
                                      onProductAdded: (phone) async {
                                        setState(() {
                                          _isCreatingProduct = true;
                                        });
                                        Navigator.pop(context);
                                        await phone.create();
                                        setState(() {
                                          _isCreatingProduct = false;
                                        });
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Product created successfully',
                                            ),
                                            duration: const Duration(
                                              seconds: 2,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: ActionCard(
                  icon: SvgPicture.asset(
                    'assets/icons/purchase_record.svg',
                    width: 40,
                    height: 40,
                  ),
                  title: 'Purchase Record',
                  onTap: () {
                    widget.onPageChange(Pages.purchaseRecord);
                  },
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: ActionCard(
                  icon: SvgPicture.asset(
                    'assets/icons/sale_record.svg',
                    width: 40,
                    height: 40,
                  ),
                  title: 'Sale Record',
                  onTap: () {
                    widget.onPageChange(Pages.saleRecord);
                  },
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: ActionCard(
                  icon: SvgPicture.asset(
                    'assets/icons/inventory.svg',
                    width: 40,
                    height: 40,
                  ),
                  title: 'Inventory',
                  onTap: () {
                    widget.onPageChange(Pages.InventoryPage);
                  },
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: ActionCard(
                  icon: SvgPicture.asset(
                    'assets/icons/reports.svg',
                    width: 40,
                    height: 40,
                  ),
                  title: 'Statistics',
                  onTap: () {
                    widget.onPageChange(Pages.StatisticsPage);
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: ActionCard(
                  icon: SvgPicture.asset(
                    'assets/icons/add_expense.svg',
                    width: 40,
                    height: 40,
                  ),
                  title: 'Add Expense',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return Align(
                          alignment: Alignment.center,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.125,
                              vertical:
                                  MediaQuery.of(context).size.height * 0.125,
                            ),
                            child: AddExpense(
                              onPageChange: widget.onPageChange,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ],
    );
  }
}
