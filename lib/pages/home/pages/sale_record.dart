import 'package:aromex/models/balance_generic.dart';
import 'package:aromex/models/sale.dart';
import 'package:aromex/pages/home/pages/sale_detail_page.dart';
import 'package:aromex/pages/home/pages/widgets/info_card.dart';
import 'package:aromex/services/sale_deletion.dart';
import 'package:aromex/util.dart';
import 'package:aromex/widgets/generic_custom_table.dart';
import 'package:aromex/widgets/pin_dialog.dart';
import 'package:aromex/widgets/search_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SaleRecord extends StatefulWidget {
  final VoidCallback? onBack;
  const SaleRecord({super.key, this.onBack});

  @override
  State<SaleRecord> createState() => _SaleRecordState();
}

class _SaleRecordState extends State<SaleRecord> {
  List<Sale> sales = [];
  List<Sale> filteredSales = [];
  List<List<Sale>> pages = [];
  int currentPageIndex = 0;

  bool isLoading = true;
  bool isLoadingMore = false;
  bool isDeletingSale = false;
  String? deletingSaleId;

  int totalSales = 0;
  double totalAmount = 0;
  int totalCustomers = 0;

  DocumentSnapshot? lastDocument;
  bool hasMore = true;
  final int perPage = 10;

  final TextEditingController controller = TextEditingController();
  String searchQuery = '';

  // Date range filter variables
  DateTime? startDate;
  DateTime? endDate;
  bool isDateRangeActive = false;

  SaleDetailPage? saleDetailPage;

  List<Sale> get currentPageSales {
    if (pages.isEmpty) return [];
    return pages[currentPageIndex];
  }

  @override
  void initState() {
    super.initState();
    fetchStats();
    loadSales();
    controller.addListener(() {
      setState(() {
        searchQuery = controller.text.toLowerCase();
        filterSales();
      });
    });
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
          totalSales = (data['totalSales'] ?? 0).toInt();
          totalAmount = (data['totalSaleAmount'] ?? 0.0).toDouble();
          totalCustomers = (data['totalCustomers'] ?? 0).toInt();
        });
      }
    } catch (e) {
      print('Error fetching sale stats: $e');
    }
  }

  Future<void> loadSales({bool loadMore = false}) async {
    if (loadMore && (!hasMore || isLoadingMore)) return;

    setState(() => isLoadingMore = loadMore);

    Query query = FirebaseFirestore.instance
        .collection('Sales')
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

      final loadedSales =
          snapshot.docs.map((doc) => Sale.fromFirestore(doc)).toList();

      setState(() {
        if (loadMore) {
          sales.addAll(loadedSales);
        } else {
          sales = loadedSales;
        }

        isLoading = false;
        isLoadingMore = false;
        hasMore = snapshot.docs.length == perPage;

        filterSales(takeBackToFirstPage: !loadMore);
      });
    } catch (e) {
      print('Error loading sales: $e');
      setState(() {
        isLoading = false;
        isLoadingMore = false;
      });
    }
  }

  String formatPaymentSource(Sale sale) {
    List<String> paymentParts = [];

    // Check for cash payment - keep original format
    if (sale.cashPaid != null && sale.cashPaid! >= 0) {
      paymentParts.add('Cash(${sale.cashPaid!.toInt()})');
    }

    // Check for UPI payment - keep original format
    if (sale.upiPaid != null && sale.upiPaid! >= 0) {
      paymentParts.add('Card(${sale.upiPaid!.toInt()})');
    }

    // Check for bank payment - keep original format
    if (sale.bankPaid != null && sale.bankPaid! >= 0) {
      paymentParts.add('Bank(${sale.bankPaid!.toInt()})');
    }

    // Check for credit payment - keep original format

    // If no specific payment amounts, fall back to original paymentSource

    // Join multiple payment methods with comma and space - keep original format
    return paymentParts.join(', ');
  }

  void filterSales({bool takeBackToFirstPage = true}) {
    List<Sale> baseList =
        searchQuery.isEmpty
            ? sales
            : sales.where((p) {
              final customerName = p.customerName?.toLowerCase() ?? '';
              final paymentSourceFormatted =
                  formatPaymentSource(p).toLowerCase();
              return p.orderNumber.toLowerCase().contains(searchQuery) ||
                  customerName.contains(searchQuery) ||
                  paymentSourceFormatted.contains(searchQuery);
            }).toList();

    // Apply date range filter if active (for sales already loaded)
    if (isDateRangeActive && (startDate != null || endDate != null)) {
      baseList =
          baseList.where((p) {
            if (startDate != null && p.date.isBefore(startDate!)) {
              return false;
            }
            if (endDate != null) {
              // Include all sales from the end date
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
      filteredSales = baseList;
      pages = [];
      for (var i = 0; i < baseList.length; i += perPage) {
        pages.add(
          baseList.sublist(
            i,
            i + perPage > baseList.length ? baseList.length : i + perPage,
          ),
        );
      }
      currentPageIndex = takeBackToFirstPage ? 0 : currentPageIndex;
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
        loadSales();
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
      loadSales();
    });
  }

  // Update the build method to show loader during deletion
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        saleDetailPage ??
            Scaffold(
              body: Card(
                margin: const EdgeInsets.all(1),
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
                              title: "Total Sales",
                              icon: Icons.shopping_cart,
                              description: "$totalSales sales",
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
                              title: "Customers",
                              icon: Icons.group,
                              description: "$totalCustomers customers",
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
                      const SizedBox(height: 11),
                      isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                            children: [
                              GenericCustomTable<Sale>(
                                onTap: (p) {
                                  setState(() {
                                    saleDetailPage = SaleDetailPage(
                                      sale: p,
                                      onBack: () {
                                        setState(() {
                                          saleDetailPage = null;
                                        });
                                      },
                                    );
                                  });
                                },
                                entries: currentPageSales,
                                headers: [
                                  "Date",
                                  "Order No.",
                                  "Amount",
                                  "Customer",
                                  "Payment Source",
                                ],
                                // Update the valueGetters in your GenericCustomTable
                                valueGetters: [
                                  (p) => DateFormat(
                                    'dd/MM/yy HH:mm',
                                  ).format(p.date),
                                  (p) => p.orderNumber,
                                  (p) => formatCurrency(p.total),
                                  (p) => p.customerName ?? 'N/A',
                                  (p) => formatPaymentSource(
                                    p,
                                  ), // Updated this line
                                ],
                                rowActions:
                                    (sale) => [
                                      // Show spinner if this sale is being deleted
                                      if (isDeletingSale &&
                                          deletingSaleId == sale.id)
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
                                          tooltip: "Delete Sale",
                                          onPressed: () async {
                                            final confirmed =
                                                await showPinDialog(context);
                                            if (confirmed) {
                                              setState(() {
                                                isDeletingSale = true;
                                                deletingSaleId = sale.id;
                                              });

                                              try {
                                                await deleteSaleWithReversal(
                                                  sale,
                                                );
                                                await loadSales();
                                                await fetchStats(); // Refresh stats too

                                                if (mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Sale deleted successfully.',
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
                                                        'Error deleting sale: $e',
                                                      ),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              } finally {
                                                if (mounted) {
                                                  setState(() {
                                                    isDeletingSale = false;
                                                    deletingSaleId = null;
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
                                              () => loadSales(loadMore: true),
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
        if (isDeletingSale)
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
                      Text('Deleting sale...', style: TextStyle(fontSize: 16)),
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
