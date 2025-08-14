import 'package:aromex/pages/home/pages/add_customer.dart';
import 'package:aromex/pages/home/main.dart';
import 'package:aromex/pages/home/pages/add_expense.dart';
import 'package:aromex/pages/home/pages/add_middleman.dart';
import 'package:aromex/pages/home/widgets/action_card.dart';
import 'package:aromex/pages/purchase/widgets/product_detail_dialog.dart';
import 'package:aromex/pages/home/pages/add_supplier.dart';
import 'package:aromex/widgets/pin_dialog.dart'; // Add this import
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
  bool _isAuthenticatingForStats = false; // Add loading state for statistics

  // Function to handle Statistics navigation with PIN check
  Future<void> _handleStatisticsNavigation() async {
    try {
      // Show PIN dialog without setting loading state first
      final confirmed = await showPinDialog(context);

      if (confirmed) {
        // PIN verified, show loading state and navigate
        setState(() {
          _isAuthenticatingForStats = true;
        });

        // Small delay to show the verification message
        await Future.delayed(const Duration(milliseconds: 500));

        // Navigate to Statistics
        widget.onPageChange(Pages.StatisticsPage);

        // Reset loading state
        if (mounted) {
          setState(() {
            _isAuthenticatingForStats = false;
          });
        }
      } else {
        // PIN verification failed or cancelled, show message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Access denied. Invalid PIN.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Handle any errors during PIN verification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during authentication: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
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
                                      MediaQuery.of(context).size.height *
                                      0.125,
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
                                      MediaQuery.of(context).size.height *
                                      0.125,
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
                                      MediaQuery.of(context).size.height *
                                      0.125,
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
                            ? const Align(
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
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.125,
                                          vertical:
                                              MediaQuery.of(
                                                context,
                                              ).size.height *
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
                                              const SnackBar(
                                                content: Text(
                                                  'Product created successfully',
                                                ),
                                                duration: Duration(seconds: 2),
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
                      icon: Stack(
                        children: [
                          SvgPicture.asset(
                            'assets/icons/reports.svg',
                            width: 40,
                            height: 40,
                          ),
                          // Add lock icon overlay
                          const Positioned(
                            right: 0,
                            top: 0,
                            child: Icon(
                              Icons.lock,
                              size: 16,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      title: 'Statistics',
                      onTap:
                          _isAuthenticatingForStats
                              ? () {}
                              : () =>
                                  _handleStatisticsNavigation(), // Disable during auth
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
                                      MediaQuery.of(context).size.height *
                                      0.125,
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
        ),

        // Global overlay loader for PIN authentication - only show after PIN is verified
        if (_isAuthenticatingForStats)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Card(
                margin: const EdgeInsets.all(20),
                child: Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      const Text(
                        'Accessing Statistics...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
