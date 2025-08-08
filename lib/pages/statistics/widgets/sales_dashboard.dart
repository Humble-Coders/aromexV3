import 'package:aromex/pages/statistics/widgets/sale_phones_page.dart';
import 'package:aromex/pages/statistics/widgets/summary_card.dart';
import 'package:aromex/util.dart';
import 'package:aromex/widgets/generic_custom_table.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aromex/models/sale.dart';
import 'package:aromex/models/balance_generic.dart';

class SalesDashboard extends StatefulWidget {
  const SalesDashboard({super.key, this.onBack});
  final VoidCallback? onBack;
  @override
  State<SalesDashboard> createState() => _SalesDashboardState();
}

class _SalesDashboardState extends State<SalesDashboard> {
  String selectedPeriod = 'Day';
  String? selectedMonth;
  int? selectedYear;
  DateTime? selectedDate;
  String searchQuery = '';
  String sortBy = 'Revenue';
  bool sortAscending = false;
  bool isLoading = true;
  SalePhonesPage? salePhonesPage;

  final List<String> periods = ['Day', 'Month', 'Year'];
  final List<String> months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final List<String> sortOptions = ['Revenue', 'Date', 'Amount', 'Customer'];

  List<int> get years {
    final currentYear = DateTime.now().year;
    return List.generate(6, (index) => currentYear - index);
  }

  List<Sale> allSales = [];
  List<Sale> filteredSales = [];

  @override
  void initState() {
    super.initState();
    fetchSalesData();
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

  Future<void> fetchSalesData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Fetch all sales without date filtering to make filtering more efficient
      Query query = FirebaseFirestore.instance
          .collection(Sale.collectionName)
          .orderBy('date', descending: true);

      final querySnapshot = await query.get();

      final sales =
          querySnapshot.docs.map((doc) => Sale.fromFirestore(doc)).toList();

      setState(() {
        allSales = sales;
        isLoading = false;
      });

      _applyFiltersAndSort();
    } catch (e) {
      print('Error fetching sales: $e');
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading sales data: $e')));
      }
    }
  }

  DateTimeRange getDateRange() {
    final now = DateTime.now();
    DateTime start, end;

    switch (selectedPeriod) {
      case 'Day':
        final targetDate = selectedDate ?? now;
        start = DateTime(targetDate.year, targetDate.month, targetDate.day);
        end = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          23,
          59,
          59,
        );
        break;
      case 'Month':
        if (selectedMonth != null) {
          final monthIndex = months.indexOf(selectedMonth!) + 1;
          final year = selectedYear ?? now.year;
          start = DateTime(year, monthIndex, 1);
          end = DateTime(year, monthIndex + 1, 0, 23, 59, 59);
        } else {
          start = DateTime(now.year, now.month, 1);
          end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        }
        break;
      case 'Year':
        final year = selectedYear ?? now.year;
        start = DateTime(year, 1, 1);
        end = DateTime(year, 12, 31, 23, 59, 59);
        break;
      default:
        final targetDate = selectedDate ?? now;
        start = DateTime(targetDate.year, targetDate.month, targetDate.day);
        end = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          23,
          59,
          59,
        );
    }

    return DateTimeRange(start: start, end: end);
  }

  void _applyFiltersAndSort() {
    setState(() {
      final dateRange = getDateRange();

      // Filter by search query AND date range
      filteredSales =
          allSales.where((sale) {
            // Search filter
            bool matchesSearch = searchQuery.isEmpty;
            if (!matchesSearch) {
              final searchLower = searchQuery.toLowerCase();
              matchesSearch =
                  sale.orderNumber.toLowerCase().contains(searchLower) ||
                  (sale.customerName?.toLowerCase().contains(searchLower) ??
                      false) ||
                  balanceTypeTitles[sale.paymentSource]!.toLowerCase().contains(
                    searchLower,
                  );
            }

            // Date filter
            bool matchesDate =
                sale.date.isAfter(
                  dateRange.start.subtract(Duration(days: 1)),
                ) &&
                sale.date.isBefore(dateRange.end.add(Duration(days: 1)));

            return matchesSearch && matchesDate;
          }).toList();

      // Sort items
      filteredSales.sort((a, b) {
        int comparison = 0;
        switch (sortBy) {
          case 'Revenue':
            comparison = a.total.compareTo(b.total);
            break;
          case 'Date':
            comparison = a.date.compareTo(b.date);
            break;
          case 'Amount':
            comparison = a.amount.compareTo(b.amount);
            break;
          case 'Customer':
            comparison = (a.customerName ?? '').compareTo(b.customerName ?? '');
            break;
        }
        return sortAscending ? comparison : -comparison;
      });
    });
  }

  void _onPeriodChanged(String period) {
    setState(() {
      selectedPeriod = period;
      if (period != 'Month') {
        selectedMonth = null;
      }
      if (period != 'Year' && period != 'Month') {
        selectedYear = null;
      }
      if (period != 'Day') {
        selectedDate = null;
      }
    });
    _applyFiltersAndSort();
  }

  void _onMonthChanged(String? month) {
    setState(() {
      selectedMonth = month;
    });
    _applyFiltersAndSort();
  }

  void _onYearChanged(int? year) {
    setState(() {
      selectedYear = year;
    });
    _applyFiltersAndSort();
  }

  void _onDateChanged(DateTime? date) {
    setState(() {
      selectedDate = date;
    });
    _applyFiltersAndSort();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) {
      _onDateChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final totalItems = filteredSales.length;

    final totalRevenue = filteredSales.fold<double>(
      0,
      (sum, sale) => sum + sale.total,
    );

    final totalOriginalAmount = filteredSales.fold<double>(
      0,
      (sum, sale) => sum + sale.originalPrice,
    );
    final totalProfit = totalRevenue - totalOriginalAmount;

    return salePhonesPage != null
        ? salePhonesPage!
        : Scaffold(
          backgroundColor: colorScheme.surface,
          body: Card(
            margin: const EdgeInsets.all(12),
            color: colorScheme.secondary,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Controls Row
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed:
                            widget.onBack ?? () => Navigator.pop(context),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 8),
                      // Period Selector
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children:
                              periods.map((period) {
                                final isSelected = selectedPeriod == period;
                                return InkWell(
                                  onTap: () => _onPeriodChanged(period),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isSelected
                                              ? colorScheme.primary
                                              : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      period,
                                      style: textTheme.bodyMedium?.copyWith(
                                        color:
                                            isSelected
                                                ? colorScheme.onPrimary
                                                : colorScheme.onSurface,
                                        fontWeight:
                                            isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Date Selector for Day
                      if (selectedPeriod == 'Day')
                        InkWell(
                          onTap: _selectDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: colorScheme.outline),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  selectedDate != null
                                      ? DateFormat.yMMMd().format(selectedDate!)
                                      : 'Select Date',
                                  style: textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Month Selector
                      if (selectedPeriod == 'Month')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: colorScheme.outline),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: selectedMonth,
                            hint: Text(
                              'Select Month',
                              style: textTheme.bodyMedium,
                            ),
                            underline: const SizedBox(),
                            icon: const Icon(Icons.keyboard_arrow_down),
                            items:
                                months.map((month) {
                                  return DropdownMenuItem(
                                    value: month,
                                    child: Text(month),
                                  );
                                }).toList(),
                            onChanged: _onMonthChanged,
                          ),
                        ),
                      // Year Selector
                      if (selectedPeriod == 'Year' ||
                          selectedPeriod == 'Month') ...[
                        if (selectedPeriod == 'Month')
                          const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: colorScheme.outline),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<int>(
                            value: selectedYear,
                            hint: Text(
                              'Select Year',
                              style: textTheme.bodyMedium,
                            ),
                            underline: const SizedBox(),
                            icon: const Icon(Icons.keyboard_arrow_down),
                            items:
                                years.map((year) {
                                  return DropdownMenuItem(
                                    value: year,
                                    child: Text(year.toString()),
                                  );
                                }).toList(),
                            onChanged: _onYearChanged,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Search and Controls Row
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        // Search Field
                        Expanded(
                          flex: 3,
                          child: TextField(
                            onChanged: (value) {
                              searchQuery = value;
                              _applyFiltersAndSort();
                            },
                            decoration: InputDecoration(
                              hintText: 'Search Items',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: colorScheme.outline,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Sort Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: colorScheme.outline),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.sort),
                              const SizedBox(width: 8),
                              Text('Sort by: '),
                              DropdownButton<String>(
                                value: sortBy,
                                underline: const SizedBox(),
                                items:
                                    sortOptions.map((option) {
                                      return DropdownMenuItem(
                                        value: option,
                                        child: Text(option),
                                      );
                                    }).toList(),
                                onChanged: (value) {
                                  setState(() => sortBy = value!);
                                  _applyFiltersAndSort();
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  sortAscending
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                ),
                                onPressed: () {
                                  setState(
                                    () => sortAscending = !sortAscending,
                                  );
                                  _applyFiltersAndSort();
                                },
                                iconSize: 16,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Refresh Button
                        IconButton(
                          onPressed: fetchSalesData,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh Data',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Summary Cards
                  if (isLoading)
                    const Row(
                      children: [
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: SummaryCard(
                            title: 'Total Sales',
                            value: totalItems.toString(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SummaryCard(
                            title: 'Total Revenue',
                            value: formatCurrency(totalRevenue),
                          ),
                        ),

                        const SizedBox(width: 16),
                        Expanded(
                          child: SummaryCard(
                            title: 'Total Profit',
                            value: formatCurrency(totalProfit),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Sales ',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  // Sales Table
                  GenericCustomTable<Sale>(
                    entries: [...filteredSales],
                    headers: [
                      'Date',
                      'Order No.',
                      'Customer',
                      'Amount',
                      'Payment Source',
                      'Credit',
                    ],
                    valueGetters: [
                      (sale) => DateFormat.yMd().format(sale.date),
                      (sale) => sale.orderNumber,
                      (sale) => sale.customerName ?? 'N/A',
                      (sale) => formatCurrency(sale.amount),
                      (sale) => formatPaymentSource(sale) ?? 'Unknown',
                      (sale) => formatCurrency(sale.credit),
                    ],
                    onTap: (sale) {
                      setState(() {
                        salePhonesPage = SalePhonesPage(
                          sale: sale,
                          onBack: () {
                            setState(() {
                              salePhonesPage = null;
                            });
                          },
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        );
  }
}
