import 'package:aromex/models/customer.dart';
import 'package:aromex/models/sale.dart';
import 'package:aromex/pages/statistics/widgets/summary_card.dart';
import 'package:aromex/util.dart';
import 'package:aromex/widgets/generic_custom_table.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerProductsDashboard extends StatefulWidget {
  const CustomerProductsDashboard({super.key, this.onBack});
  final VoidCallback? onBack;

  @override
  State<CustomerProductsDashboard> createState() =>
      _CustomerProductsDashboardState();
}

class _CustomerProductsDashboardState extends State<CustomerProductsDashboard> {
  String selectedPeriod = 'Day';
  String? selectedMonth;
  String searchQuery = '';
  String sortBy = 'A to Z';
  bool sortAscending = true;
  bool isLoading = true;
  int? selectedYear;
  DateTime? selectedDate;

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
  final List<String> sortOptions = ['A to Z', 'Products', 'Date', 'Amount'];

  List<int> get years {
    final currentYear = DateTime.now().year;
    return List.generate(6, (index) => currentYear - index);
  }

  List<Customer> allCustomers = [];
  List<Customer> filteredCustomers = [];
  Map<String, int> customerPhoneCounts = {};
  Map<String, double> customerTotalAmounts = {};
  List<Sale> allSales = [];

  @override
  void initState() {
    super.initState();
    fetchCustomerData();
  }

  Future<void> fetchCustomerData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Fetch all customers
      final customersSnapshot =
          await FirebaseFirestore.instance
              .collection(Customer.collectionName)
              .get();

      // Fetch all sales
      final salesSnapshot =
          await FirebaseFirestore.instance
              .collection(Sale.collectionName)
              .get();

      // Create customer list
      List<Customer> customers = [];
      for (var customerDoc in customersSnapshot.docs) {
        final customer = Customer.fromFirestore(customerDoc);
        customers.add(customer);
      }

      // Create sales list
      List<Sale> sales = [];
      for (var saleDoc in salesSnapshot.docs) {
        final sale = Sale.fromFirestore(saleDoc);
        sales.add(sale);
      }

      // Debug logging
      print('DEBUG: Total customers loaded: ${customers.length}');
      print('DEBUG: Total sales loaded: ${sales.length}');

      // Print sample sale data
      if (sales.isNotEmpty) {
        final firstSale = sales.first;
        print('DEBUG: First sale - ID: ${firstSale.id}');
        print('DEBUG: First sale - Amount: ${firstSale.amount}');
        print('DEBUG: First sale - Date: ${firstSale.date}');
        print('DEBUG: First sale - Customer ID: ${firstSale.customerRef.id}');
        print('DEBUG: First sale - Phones count: ${firstSale.phones.length}');
      }

      setState(() {
        allCustomers = customers;
        allSales = sales;
        isLoading = false;
      });

      _applyFiltersAndSort();
    } catch (e) {
      print('Error fetching customers: $e');
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading customer data: $e')),
        );
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

    print('DEBUG: Date range - Start: $start, End: $end');
    return DateTimeRange(start: start, end: end);
  }

  void _applyFiltersAndSort() {
    setState(() {
      final dateRange = getDateRange();

      // Filter sales by date range and count phones + calculate total amounts per customer
      Map<String, int> phoneCounts = {};
      Map<String, double> totalAmounts = {};

      print('DEBUG: Total sales before filtering: ${allSales.length}');

      final filteredSales =
          allSales.where((sale) {
            final saleDate = sale.date;
            final isInRange =
                saleDate.isAfter(dateRange.start.subtract(Duration(days: 1))) &&
                saleDate.isBefore(dateRange.end.add(Duration(days: 1)));

            if (!isInRange) {
              print(
                'DEBUG: Sale ${sale.id} excluded - Date: $saleDate (outside range)',
              );
            }

            return isInRange;
          }).toList();

      print('DEBUG: Filtered sales count: ${filteredSales.length}');

      for (var sale in filteredSales) {
        final customerId = sale.customerRef.id;
        final phoneCount = sale.phones.length;

        // Handle different amount types
        double saleAmount = 0.0;
        try {
          if (sale.amount is int) {
            saleAmount = (sale.amount as int).toDouble();
          } else if (sale.amount is double) {
            saleAmount = sale.amount as double;
          } else if (sale.amount is String) {
            saleAmount = double.parse(sale.amount as String);
          } else {
            saleAmount = sale.amount.toDouble();
          }
        } catch (e) {
          print(
            'DEBUG: Error parsing amount for sale ${sale.id}: ${sale.amount} - $e',
          );
          saleAmount = 0.0;
        }

        phoneCounts[customerId] = (phoneCounts[customerId] ?? 0) + phoneCount;
        totalAmounts[customerId] =
            (totalAmounts[customerId] ?? 0.0) + saleAmount;

        print(
          'DEBUG: Sale ${sale.id} - Customer: $customerId, Amount: $saleAmount, Phones: $phoneCount',
        );
      }

      customerPhoneCounts = phoneCounts;
      customerTotalAmounts = totalAmounts;

      print('DEBUG: Customer phone counts: $customerPhoneCounts');
      print('DEBUG: Customer total amounts: $customerTotalAmounts');

      // Filter customers by search query
      filteredCustomers =
          allCustomers.where((customer) {
            if (searchQuery.isEmpty) return true;

            final searchLower = searchQuery.toLowerCase();
            return customer.name.toLowerCase().contains(searchLower) ||
                customer.phone.toLowerCase().contains(searchLower) ||
                customer.email.toLowerCase().contains(searchLower);
          }).toList();

      print('DEBUG: Filtered customers count: ${filteredCustomers.length}');

      // Sort items
      filteredCustomers.sort((a, b) {
        int comparison = 0;
        switch (sortBy) {
          case 'A to Z':
            comparison = a.name.compareTo(b.name);
            break;
          case 'Products':
            final aCount = customerPhoneCounts[a.id] ?? 0;
            final bCount = customerPhoneCounts[b.id] ?? 0;
            comparison = bCount.compareTo(aCount);

            if (comparison == 0) {
              comparison = a.name.compareTo(b.name);
            }
            break;
          case 'Amount':
            final aAmount = customerTotalAmounts[a.id] ?? 0.0;
            final bAmount = customerTotalAmounts[b.id] ?? 0.0;
            comparison = bAmount.compareTo(aAmount);

            if (comparison == 0) {
              comparison = a.name.compareTo(b.name);
            }
            break;
          case 'Date':
            comparison = a.createdAt.compareTo(b.createdAt);
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

    final totalCustomers = filteredCustomers.length;
    final totalPhones = filteredCustomers.fold<int>(
      0,
      (sum, customer) => sum + (customerPhoneCounts[customer.id] ?? 0),
    );
    final totalAmount = filteredCustomers.fold<double>(
      0.0,
      (sum, customer) => sum + (customerTotalAmounts[customer.id] ?? 0.0),
    );
    final averagePhones =
        totalCustomers > 0 ? totalPhones / totalCustomers : 0.0;
    final maxPhones =
        filteredCustomers.isEmpty
            ? 0
            : filteredCustomers
                .map((customer) => customerPhoneCounts[customer.id] ?? 0)
                .reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Card(
        margin: const EdgeInsets.all(12),
        color: colorScheme.secondary,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Debug Info Card (Remove this in production)

              // Top Controls Row
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: widget.onBack ?? () => Navigator.pop(context),
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
                                  : 'Today (${DateFormat.yMMMd().format(DateTime.now())})',
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
                        hint: Text('Select Month', style: textTheme.bodyMedium),
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
                    if (selectedPeriod == 'Month') const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<int>(
                        value: selectedYear,
                        hint: Text('Select Year', style: textTheme.bodyMedium),
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
                          hintText: 'Search Customers',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colorScheme.outline),
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
                              setState(() => sortAscending = !sortAscending);
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
                      onPressed: fetchCustomerData,
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
                        title: 'Total Customers',
                        value: totalCustomers.toString(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SummaryCard(
                        title: 'Total Phones',
                        value: totalPhones.toString(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SummaryCard(
                        title: 'Total Sales Amount',
                        value: formatCurrency(totalAmount),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SummaryCard(
                        title: 'Avg Phones/Customer',
                        value: averagePhones.toStringAsFixed(1),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SummaryCard(
                        title: 'Max Phones',
                        value: maxPhones.toString(),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),

              // Customers Section Title
              Text(
                'Customers',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),

              // Customers Table
              GenericCustomTable<Customer>(
                entries: [...filteredCustomers],
                headers: [
                  'Customer',
                  'Number of Products Bought',
                  'Total Amount',
                ],
                valueGetters: [
                  (customer) => customer.name,
                  (customer) =>
                      (customerPhoneCounts[customer.id] ?? 0).toString(),
                  (customer) =>
                      formatCurrency(customerTotalAmounts[customer.id] ?? 0.0),
                ],
                onTap: (customer) {
                  // Handle tap - show detailed view
                  showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('Customer Details'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Name: ${customer.name}'),
                              const SizedBox(height: 8),
                              Text('Phone: ${customer.phone}'),
                              const SizedBox(height: 8),
                              if (customer.email.isNotEmpty) ...[
                                Text('Email: ${customer.email}'),
                                const SizedBox(height: 8),
                              ],
                              if (customer.address.isNotEmpty) ...[
                                Text('Address: ${customer.address}'),
                                const SizedBox(height: 8),
                              ],
                              Text(
                                'Phones Bought: ${customerPhoneCounts[customer.id] ?? 0}',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Total Purchase Amount: ${formatCurrency(customerTotalAmounts[customer.id] ?? 0.0)}',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Balance: ${formatCurrency(customer.balance)}',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Created: ${DateFormat.yMMMd().format(customer.createdAt)}',
                              ),
                              if (customer.notes.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('Notes: ${customer.notes}'),
                              ],
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
