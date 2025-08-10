import 'package:aromex/models/balance_generic.dart';
import 'package:aromex/models/purchase.dart';
import 'package:aromex/pages/home/pages/purchase_detail_page.dart';
import 'package:aromex/pages/home/pages/widgets/info_card.dart';
import 'package:aromex/util.dart';
import 'package:aromex/widgets/generic_custom_table.dart';
import 'package:aromex/widgets/search_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aromex/services/purchase_deletion.dart';
import 'package:aromex/widgets/pin_dialog.dart';

class PurchaseRecord extends StatefulWidget {
  final VoidCallback? onBack;
  const PurchaseRecord({super.key, this.onBack});

  @override
  State<PurchaseRecord> createState() => _PurchaseRecordState();
}

class _PurchaseRecordState extends State<PurchaseRecord> {
  List<Purchase> purchases = [];
  List<Purchase> filteredPurchases = [];
  List<List<Purchase>> pages = [];
  int currentPageIndex = 0;

  bool isLoading = true;
  bool isLoadingMore = false;
  bool isDeletingPurchase = false;
  String? deletingPurchaseId;

  int totalPurchases = 0;
  double totalAmount = 0;
  int totalSuppliers = 0;

  DocumentSnapshot? lastDocument;
  bool hasMore = true;
  final int perPage = 10;

  final TextEditingController controller = TextEditingController();
  String searchQuery = '';

  // Date range filter variables
  DateTime? startDate;
  DateTime? endDate;
  bool isDateRangeActive = false;

  PurchaseDetailPage? purchaseDetailPage;

  List<Purchase> get currentPagePurchases {
    if (pages.isEmpty) return [];
    return pages[currentPageIndex];
  }

  @override
  void initState() {
    super.initState();
    fetchStats();
    loadPurchases();
    controller.addListener(() {
      setState(() {
        searchQuery = controller.text.toLowerCase();
        filterPurchases();
      });
    });
  }

  String formatPaymentSource(Purchase pur) {
    List<String> paymentParts = [];

    // Check for cash payment - keep original format
    if (pur.cashPaid != null && pur.cashPaid! > 0) {
      paymentParts.add('Cash(${pur.cashPaid!.toInt()})');
    }

    // Check for UPI payment - keep original format
    if (pur.upiPaid != null && pur.upiPaid! > 0) {
      paymentParts.add('UPI(${pur.upiPaid!.toInt()})');
    }

    // Check for bank payment - keep original format
    if (pur.bankPaid != null && pur.bankPaid! > 0) {
      paymentParts.add('Bank(${pur.bankPaid!.toInt()})');
    }

    // Check for credit payment - keep original format

    // If no specific payment amounts, fall back to original paymentSource
    if (paymentParts.isEmpty) {
      final paymentSourceTitle = balanceTypeTitles[pur.paymentSource];
      if (paymentSourceTitle != null) {
        return paymentSourceTitle.toString();
      }
      return "cash";
    }

    // Join multiple payment methods with comma and space - keep original format
    return paymentParts.join(', ');
  }

  Future<void> fetchStats() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('Data')
              .doc('Totals')
              .get();

      if (snapshot.exists) {
        final data = snapshot.data()!;
        setState(() {
          totalPurchases = (data['totalPurchases'] ?? 0).toInt();
          totalAmount = (data['totalAmount'] ?? 0.0).toDouble();
          totalSuppliers = (data['totalSuppliers'] ?? 0).toInt();
        });
      }
    } catch (e) {
      print('Error fetching purchase stats: $e');
    }
  }

  Future<void> loadPurchases({bool loadMore = false}) async {
    if (loadMore && (!hasMore || isLoadingMore)) return;

    setState(() => isLoadingMore = loadMore);

    Query query = FirebaseFirestore.instance
        .collection('Purchases')
        .orderBy('date', descending: true);

    // Apply date filters to Firestore query if date range is active
    if (isDateRangeActive) {
      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        // Add one day to include the end date in the results
        final DateTime endDatePlusOne = endDate!.add(const Duration(days: 1));
        query = query.where('date', isLessThan: endDatePlusOne);
      }
    }

    query = query.limit(perPage);

    if (loadMore && lastDocument != null) {
      query = query.startAfterDocument(lastDocument!);
    }

    try {
      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        lastDocument = snapshot.docs.last;
      }

      final loadedPurchases =
          snapshot.docs.map((doc) => Purchase.fromFirestore(doc)).toList();

      setState(() {
        if (loadMore) {
          purchases.addAll(loadedPurchases);
        } else {
          purchases = loadedPurchases;
        }

        isLoading = false;
        isLoadingMore = false;
        hasMore = snapshot.docs.length == perPage;

        filterPurchases(takeBacktoFirstPage: !loadMore);
      });
    } catch (e, stackTrace) {
      print('Error loading purchases: $e $stackTrace');
      setState(() {
        isLoading = false;
        isLoadingMore = false;
      });
    }
  }

  void filterPurchases({bool takeBacktoFirstPage = true}) {
    List<Purchase> baseList =
        searchQuery.isEmpty
            ? purchases
            : purchases.where((p) {
              final supplierName = p.supplierName.toLowerCase();
              return p.orderNumber.toLowerCase().contains(searchQuery) ||
                  supplierName.contains(searchQuery) ||
                  balanceTypeTitles[p.paymentSource]!.toLowerCase().contains(
                    searchQuery,
                  );
            }).toList();

    // Apply date range filter if active (for purchases already loaded)
    if (isDateRangeActive && (startDate != null || endDate != null)) {
      baseList =
          baseList.where((p) {
            if (startDate != null && p.date.isBefore(startDate!)) {
              return false;
            }
            if (endDate != null) {
              // Include all purchases from the end date
              final DateTime endDatePlusOne = endDate!.add(
                const Duration(days: 1),
              );
              if (p.date.isAfter(endDatePlusOne) ||
                  p.date.isAtSameMomentAs(endDatePlusOne)) {
                return false;
              }
            }
            return true;
          }).toList();
    }

    setState(() {
      filteredPurchases = baseList;
      pages = [];
      for (var i = 0; i < baseList.length; i += perPage) {
        pages.add(
          baseList.sublist(
            i,
            i + perPage > baseList.length ? baseList.length : i + perPage,
          ),
        );
      }
      currentPageIndex = takeBacktoFirstPage ? 0 : currentPageIndex;
    });
  }

  String get _dateRangeText {
    if (!isDateRangeActive) return 'Select Date Range';

    final DateFormat formatter = DateFormat('MM/dd/yyyy');
    if (startDate != null && endDate != null) {
      return '${formatter.format(startDate!)} - ${formatter.format(endDate!)}';
    } else if (startDate != null) {
      return 'From ${formatter.format(startDate!)}';
    } else if (endDate != null) {
      return 'Until ${formatter.format(endDate!)}';
    }
    return 'Select Date Range';
  }

  Future<void> _selectDateRange(BuildContext context) async {
    // Create variables to store temporary dates
    DateTime? tempStartDate = startDate;
    DateTime? tempEndDate = endDate;

    // Show a custom dialog with date pickers
    final result = await showDialog<Map<String, DateTime?>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Date Range'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Start date picker
                    ListTile(
                      title: const Text('Start Date'),
                      subtitle: Text(
                        tempStartDate != null
                            ? DateFormat('MM/dd/yyyy').format(tempStartDate!)
                            : 'Not set',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: tempStartDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            tempStartDate = picked;
                          });
                        }
                      },
                    ),
                    const Divider(),
                    // End date picker
                    ListTile(
                      title: const Text('End Date'),
                      subtitle: Text(
                        tempEndDate != null
                            ? DateFormat('MM/dd/yyyy').format(tempEndDate!)
                            : 'Not set',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: tempEndDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            tempEndDate = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pop({'startDate': tempStartDate, 'endDate': tempEndDate});
                  },
                  child: const Text('APPLY'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        startDate = result['startDate'];
        endDate = result['endDate'];
        isDateRangeActive = (startDate != null || endDate != null);

        // Reset pagination and reload with new filters
        lastDocument = null;
        currentPageIndex = 0;
        isLoading = true;
        loadPurchases();
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      startDate = null;
      endDate = null;
      isDateRangeActive = false;

      // Reset pagination and reload without date filter
      lastDocument = null;
      currentPageIndex = 0;
      isLoading = true;
      loadPurchases();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        purchaseDetailPage ??
            Scaffold(
              body: Card(
                margin: const EdgeInsets.all(12),
                color: colorScheme.secondary,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: widget.onBack,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InfoCard(
                              title: "Total Purchases",
                              icon: Icons.shopping_cart,
                              description: "$totalPurchases purchases",
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InfoCard(
                              title: "Total Amount",
                              icon: Icons.attach_money,
                              description: formatCurrency(totalAmount),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InfoCard(
                              title: "Suppliers",
                              icon: Icons.group,
                              description: "$totalSuppliers suppliers",
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Row with search bar and date filter
                      Row(
                        children: [
                          // Search bar
                          Expanded(
                            flex: 2,
                            child: CustomSearchBar(controller: controller),
                          ),
                          const SizedBox(width: 12),
                          // Date range filter
                          Expanded(
                            flex: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextButton.icon(
                                      icon: const Icon(Icons.calendar_today),
                                      label: Text(
                                        _dateRangeText,
                                        style: TextStyle(
                                          color:
                                              isDateRangeActive
                                                  ? Theme.of(
                                                    context,
                                                  ).primaryColor
                                                  : Colors.black54,
                                          fontWeight:
                                              isDateRangeActive
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onPressed:
                                          () => _selectDateRange(context),
                                    ),
                                  ),
                                  if (isDateRangeActive)
                                    IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: _clearDateFilter,
                                      tooltip: 'Clear date filter',
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                            children: [
                              GenericCustomTable<Purchase>(
                                onTap: (p) {
                                  setState(() {
                                    purchaseDetailPage = PurchaseDetailPage(
                                      purchase: p,
                                      onBack: () {
                                        setState(() {
                                          purchaseDetailPage = null;
                                        });
                                      },
                                    );
                                  });
                                },
                                entries: currentPagePurchases,
                                headers: [
                                  "Date",
                                  "Order No.",
                                  "Amount",
                                  "Supplier",
                                  "Payment Source",
                                ],
                                valueGetters: [
                                  (p) => p.date.toString(),
                                  (p) => p.orderNumber,
                                  (p) => formatCurrency(p.total),
                                  (p) => p.supplierName,
                                  (p) => formatPaymentSource(p),
                                ],
                                rowActions:
                                    (purchase) => [
                                      // Show spinner if this purchase is being deleted
                                      if (isDeletingPurchase &&
                                          deletingPurchaseId == purchase.id)
                                        const Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        )
                                      else
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          tooltip: "Delete Purchase",
                                          onPressed: () async {
                                            final confirmed =
                                                await showPinDialog(context);
                                            if (confirmed) {
                                              setState(() {
                                                isDeletingPurchase = true;
                                                deletingPurchaseId =
                                                    purchase.id;
                                              });

                                              try {
                                                await deletePurchaseWithReversal(
                                                  purchase,
                                                );
                                                await loadPurchases();
                                                await fetchStats(); // Refresh stats too

                                                if (mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Purchase deleted successfully.',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Error deleting purchase: $e',
                                                      ),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              } finally {
                                                if (mounted) {
                                                  setState(() {
                                                    isDeletingPurchase = false;
                                                    deletingPurchaseId = null;
                                                  });
                                                }
                                              }
                                            }
                                          },
                                        ),
                                    ],
                              ),
                              const SizedBox(height: 12),
                              if (pages.isNotEmpty)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ...List.generate(pages.length, (index) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4.0,
                                        ),
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                index == currentPageIndex
                                                    ? Theme.of(
                                                      context,
                                                    ).primaryColor
                                                    : Colors.grey[300],
                                            foregroundColor:
                                                index == currentPageIndex
                                                    ? Colors.white
                                                    : Colors.black,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              currentPageIndex = index;
                                            });
                                          },
                                          child: Text("${index + 1}"),
                                        ),
                                      );
                                    }),
                                    if (hasMore)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4.0,
                                        ),
                                        child: TextButton(
                                          onPressed:
                                              () =>
                                                  loadPurchases(loadMore: true),
                                          child:
                                              isLoadingMore
                                                  ? const SizedBox(
                                                    height: 16,
                                                    width: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                  : const Text(
                                                    "Load Next Page",
                                                  ),
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                    ],
                  ),
                ),
              ),
            ),

        // Global overlay loader for deletion
        if (isDeletingPurchase)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Deleting purchase...',
                        style: TextStyle(fontSize: 16),
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
