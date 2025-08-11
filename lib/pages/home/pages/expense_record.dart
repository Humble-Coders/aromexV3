import 'package:aromex/models/balance_generic.dart';
import 'package:aromex/models/transaction.dart' as AT;
import 'package:aromex/util.dart';
import 'package:aromex/widgets/generic_custom_table.dart';
import 'package:aromex/widgets/search_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExpenseRecord extends StatefulWidget {
  final VoidCallback? onBack;
  const ExpenseRecord({super.key, this.onBack});

  @override
  State<ExpenseRecord> createState() => _ExpenseRecordState();
}

class _ExpenseRecordState extends State<ExpenseRecord> {
  List<AT.Transaction> transactions = [];
  List<AT.Transaction> filteredTransactions = [];
  List<List<AT.Transaction>> pages = [];
  int currentPageIndex = 0;

  Balance? balance;

  bool isLoading = true;
  bool isLoadingMore = false;

  DocumentSnapshot? lastDocument;
  bool hasMore = true;
  final int perPage = 10;

  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  // Date range filter variables
  DateTime? startDate;
  DateTime? endDate;
  bool isDateRangeActive = false;

  // View mode toggle
  bool showDetailedView = true;

  List<AT.Transaction> get currentPageTransactions {
    if (pages.isEmpty) return [];
    return pages[currentPageIndex];
  }

  @override
  void initState() {
    super.initState();
    searchController.addListener(() {
      setState(() {
        searchQuery = searchController.text.toLowerCase();
      });
      filterTransactions();
    });
    loadTransactions();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadTransactions({bool loadMore = false}) async {
    if (loadMore && (!hasMore || isLoadingMore)) return;

    setState(() => isLoadingMore = loadMore);
    balance ??= await Balance.fromType(BalanceType.expenseRecord);

    try {
      final snapshot = await balance!.getTransactions(
        startTime: startDate,
        endTime: endDate,
        limit: perPage,
        descending: true,
        startAfter: loadMore && lastDocument != null ? lastDocument : null,
      );

      setState(() {
        if (loadMore) {
          transactions.addAll(snapshot);
        } else {
          transactions = snapshot;
        }

        isLoading = false;
        isLoadingMore = false;
        hasMore = snapshot.length == perPage;

        filterTransactions(takeBackToFirstPage: !loadMore);
      });
    } catch (e, stackTrace) {
      print('Error loading transactions: $e $stackTrace');
      setState(() {
        isLoading = false;
        isLoadingMore = false;
      });
    }
  }

  void filterTransactions({bool takeBackToFirstPage = true}) {
    List<AT.Transaction> baseList =
        searchQuery.isEmpty
            ? transactions
            : transactions.where((transaction) {
              final category = (transaction.category ?? '').toLowerCase();
              final notes = (transaction.note ?? '').toLowerCase();
              final amount = transaction.amount.toString().toLowerCase();

              return category.contains(searchQuery) ||
                  notes.contains(searchQuery) ||
                  amount.contains(searchQuery);
            }).toList();

    // Apply date range filter if active
    if (isDateRangeActive && (startDate != null || endDate != null)) {
      baseList =
          baseList.where((transaction) {
            if (startDate != null &&
                transaction.time.toDate().isBefore(startDate!)) {
              return false;
            }
            if (endDate != null) {
              final DateTime endDatePlusOne = endDate!.add(
                const Duration(days: 1),
              );
              if (transaction.time.toDate().isAfter(endDatePlusOne) ||
                  transaction.time.toDate().isAtSameMomentAs(endDatePlusOne)) {
                return false;
              }
            }
            return true;
          }).toList();
    }

    setState(() {
      filteredTransactions = baseList;
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
    DateTime? tempStartDate = startDate;
    DateTime? tempEndDate = endDate;

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
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            tempStartDate = picked;
                          });
                        }
                      },
                    ),
                    const Divider(),
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

        lastDocument = null;
        currentPageIndex = 0;
        isLoading = true;
        loadTransactions();
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      startDate = null;
      endDate = null;
      isDateRangeActive = false;

      lastDocument = null;
      currentPageIndex = 0;
      isLoading = true;
      loadTransactions();
    });
  }

  // Format payment method details
  String _getPaymentDetails(AT.Transaction transaction) {
    List<String> paymentMethods = [];

    // Check for Cash Payment
    if (transaction.cashPaid != null && transaction.cashPaid! > 0) {
      paymentMethods.add('Cash: ${formatCurrency(transaction.cashPaid!)}');
    }

    // Check for Bank Payment
    if (transaction.bankPaid != null && transaction.bankPaid! > 0) {
      paymentMethods.add('Bank: ${formatCurrency(transaction.bankPaid!)}');
    }

    // Check for Credit Card Payment
    if (transaction.creditCardPaid != null && transaction.creditCardPaid! > 0) {
      paymentMethods.add(
        ' Card: ${formatCurrency(transaction.creditCardPaid!)}',
      );
    }

    // Check for UPI Payment

    // If no specific payment methods are found, check if it's an older transaction
    if (paymentMethods.isEmpty) {
      // For older transactions without payment breakdown, show total amount
      if (transaction.amount > 0) {
        return ' Total: ${formatCurrency(transaction.amount)}';
      }
      return 'Payment method not specified';
    }

    return paymentMethods.join(' ,');
  }

  // Get payment method icons
  Widget _getPaymentIcons(AT.Transaction transaction) {
    List<Widget> icons = [];

    if (transaction.cashPaid != null && transaction.cashPaid! > 0) {
      icons.add(
        Tooltip(
          message: 'Cash: ${formatCurrency(transaction.cashPaid!)}',
          child: Icon(Icons.money, size: 16, color: Colors.green),
        ),
      );
    }
    if (transaction.bankPaid != null && transaction.bankPaid! > 0) {
      icons.add(
        Tooltip(
          message: 'Bank: ${formatCurrency(transaction.bankPaid!)}',
          child: Icon(Icons.account_balance, size: 16, color: Colors.blue),
        ),
      );
    }
    if (transaction.creditCardPaid != null && transaction.creditCardPaid! > 0) {
      icons.add(
        Tooltip(
          message:
              'Credit Card: ${formatCurrency(transaction.creditCardPaid!)}',
          child: Icon(Icons.credit_card, size: 16, color: Colors.orange),
        ),
      );
    }
    if (transaction.creditCardPaid != null && transaction.creditCardPaid! > 0) {
      icons.add(
        Tooltip(
          message: 'UPI: ${formatCurrency(transaction.creditCardPaid!)}',
          child: Icon(Icons.phone_android, size: 16, color: Colors.purple),
        ),
      );
    }

    return icons.isEmpty
        ? Icon(Icons.help_outline, size: 16, color: Colors.grey)
        : Wrap(spacing: 4, children: icons);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back),
                  const SizedBox(width: 8),
                  Text(
                    'Back to home',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              onPressed: widget.onBack,
            ),
            Card(
              color: colorScheme.secondary,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Expense Record',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(
                            color: colorScheme.onSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),

                        // View toggle button
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: CustomSearchBar(controller: searchController),
                        ),
                        const SizedBox(width: 12),
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
                                                ? Theme.of(context).primaryColor
                                                : Colors.black54,
                                        fontWeight:
                                            isDateRangeActive
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onPressed: () => _selectDateRange(context),
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
                            if (showDetailedView)
                              // Detailed view with payment breakdown
                              GenericCustomTable<AT.Transaction>(
                                entries: currentPageTransactions,
                                headers: const [
                                  "Date",
                                  "Total Amount",
                                  "Payment Methods",
                                  "Category",
                                  "Notes",
                                ],
                                onTap: (_) {},
                                valueGetters: [
                                  (transaction) => DateFormat(
                                    'MM/dd/yyyy',
                                  ).format(transaction.time.toDate()),
                                  (transaction) =>
                                      formatCurrency(transaction.amount),
                                  (transaction) =>
                                      _getPaymentDetails(transaction),
                                  (transaction) =>
                                      transaction.category ?? 'N/A',
                                  (transaction) => transaction.note ?? 'N/A',
                                ],
                              )
                            else
                              // Simple view with payment icons
                              GenericCustomTable<AT.Transaction>(
                                entries: currentPageTransactions,
                                headers: const [
                                  "Date",
                                  "Amount",
                                  "Payment",
                                  "Category",
                                  "Notes",
                                ],
                                onTap: (_) {},
                                valueGetters: [
                                  (transaction) => DateFormat(
                                    'MM/dd/yyyy',
                                  ).format(transaction.time.toDate()),
                                  (transaction) =>
                                      formatCurrency(transaction.amount),
                                  (transaction) =>
                                      '', // Will be replaced by custom widget
                                  (transaction) =>
                                      transaction.category ?? 'N/A',
                                  (transaction) => transaction.note ?? 'N/A',
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
                                            () => loadTransactions(
                                              loadMore: true,
                                            ),
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
                                                : const Text("Load Next Page"),
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
          ],
        ),
      ),
    );
  }
}
