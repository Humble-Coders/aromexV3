import 'package:aromex/models/supplier.dart';
import 'package:aromex/models/purchase.dart';
import 'package:aromex/pages/statistics/widgets/summary_card.dart';
import 'package:aromex/util.dart';
import 'package:aromex/widgets/generic_custom_table.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SupplierProductsDashboard extends StatefulWidget {
  const SupplierProductsDashboard({super.key, this.onBack});
  final VoidCallback? onBack;

  @override
  State<SupplierProductsDashboard> createState() =>
      _SupplierProductsDashboardState();
}

class _SupplierProductsDashboardState extends State<SupplierProductsDashboard> {
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

  List<Supplier> allSuppliers = [];
  List<Supplier> filteredSuppliers = [];
  Map<String, int> supplierPhoneCounts = {};
  Map<String, double> supplierTotalAmounts = {};
  List<Purchase> allPurchases = [];

  @override
  void initState() {
    super.initState();
    fetchSupplierData();
  }

  Future<void> fetchSupplierData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Fetch suppliers
      final suppliersSnapshot =
          await FirebaseFirestore.instance
              .collection(Supplier.collectionName)
              .get();

      // Fetch all purchases (we'll filter by date in memory for efficiency)
      final purchasesQuery =
          await FirebaseFirestore.instance
              .collection(Purchase.collectionName)
              .get();

      // Store all purchases
      allPurchases =
          purchasesQuery.docs
              .map((doc) => Purchase.fromFirestore(doc))
              .toList();

      // Create supplier list
      List<Supplier> suppliers = [];
      for (var supplierDoc in suppliersSnapshot.docs) {
        final supplier = Supplier.fromFirestore(supplierDoc);
        suppliers.add(supplier);
      }

      // Debug logging
      print('DEBUG: Total suppliers loaded: ${suppliers.length}');
      print('DEBUG: Total purchases loaded: ${allPurchases.length}');

      // Print sample purchase data
      if (allPurchases.isNotEmpty) {
        final firstPurchase = allPurchases.first;
        print('DEBUG: First purchase - ID: ${firstPurchase.id}');
        print('DEBUG: First purchase - Amount: ${firstPurchase.amount}');
        print('DEBUG: First purchase - Date: ${firstPurchase.date}');
        print(
          'DEBUG: First purchase - Supplier ID: ${firstPurchase.supplierRef.id}',
        );
        print(
          'DEBUG: First purchase - Phones count: ${firstPurchase.phones.length}',
        );
      }

      setState(() {
        allSuppliers = suppliers;
        isLoading = false;
      });

      _applyFiltersAndSort();
    } catch (e) {
      print('Error fetching suppliers: $e');
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading supplier data: $e')),
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
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    }

    print('DEBUG: Date range - Start: $start, End: $end');
    return DateTimeRange(start: start, end: end);
  }

  void _applyFiltersAndSort() {
    setState(() {
      final dateRange = getDateRange();

      // Filter purchases by date range and count phones + calculate total amounts per supplier
      Map<String, int> phoneCounts = {};
      Map<String, double> totalAmounts = {};

      print('DEBUG: Total purchases before filtering: ${allPurchases.length}');

      final filteredPurchases =
          allPurchases.where((purchase) {
            final purchaseDate = purchase.date;
            final isInRange =
                purchaseDate.isAfter(
                  dateRange.start.subtract(Duration(days: 1)),
                ) &&
                purchaseDate.isBefore(dateRange.end.add(Duration(days: 1)));

            if (!isInRange) {
              print(
                'DEBUG: Purchase ${purchase.id} excluded - Date: $purchaseDate (outside range)',
              );
            }

            return isInRange;
          }).toList();

      print('DEBUG: Filtered purchases count: ${filteredPurchases.length}');

      for (var purchase in filteredPurchases) {
        final supplierId = purchase.supplierRef.id;
        final phoneCount = purchase.phones.length;

        // Handle different amount types
        double purchaseAmount = 0.0;
        try {
          if (purchase.amount is int) {
            purchaseAmount = (purchase.amount as int).toDouble();
          } else if (purchase.amount is double) {
            purchaseAmount = purchase.amount as double;
          } else if (purchase.amount is String) {
            purchaseAmount = double.parse(purchase.amount as String);
          } else {
            purchaseAmount = purchase.amount.toDouble();
          }
        } catch (e) {
          print(
            'DEBUG: Error parsing amount for purchase ${purchase.id}: ${purchase.amount} - $e',
          );
          purchaseAmount = 0.0;
        }

        phoneCounts[supplierId] = (phoneCounts[supplierId] ?? 0) + phoneCount;
        totalAmounts[supplierId] =
            (totalAmounts[supplierId] ?? 0.0) + purchaseAmount;

        print(
          'DEBUG: Purchase ${purchase.id} - Supplier: $supplierId, Amount: $purchaseAmount, Phones: $phoneCount',
        );
      }

      supplierPhoneCounts = phoneCounts;
      supplierTotalAmounts = totalAmounts;

      print('DEBUG: Supplier phone counts: $supplierPhoneCounts');
      print('DEBUG: Supplier total amounts: $supplierTotalAmounts');

      // Filter suppliers by search query
      filteredSuppliers =
          allSuppliers.where((supplier) {
            if (searchQuery.isEmpty) return true;

            final searchLower = searchQuery.toLowerCase();
            return supplier.name.toLowerCase().contains(searchLower) ||
                supplier.phone.toLowerCase().contains(searchLower) ||
                supplier.email.toLowerCase().contains(searchLower);
          }).toList();

      print('DEBUG: Filtered suppliers count: ${filteredSuppliers.length}');

      // Sort items
      filteredSuppliers.sort((a, b) {
        int comparison = 0;
        switch (sortBy) {
          case 'A to Z':
            comparison = a.name.compareTo(b.name);
            break;
          case 'Products':
            final aCount = supplierPhoneCounts[a.id] ?? 0;
            final bCount = supplierPhoneCounts[b.id] ?? 0;
            comparison = bCount.compareTo(aCount);

            if (comparison == 0) {
              comparison = a.name.compareTo(b.name);
            }
            break;
          case 'Amount':
            final aAmount = supplierTotalAmounts[a.id] ?? 0.0;
            final bAmount = supplierTotalAmounts[b.id] ?? 0.0;
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

    final totalSuppliers = filteredSuppliers.length;
    final totalPhones = filteredSuppliers.fold<int>(
      0,
      (sum, supplier) => sum + (supplierPhoneCounts[supplier.id] ?? 0),
    );
    final totalAmount = filteredSuppliers.fold<double>(
      0.0,
      (sum, supplier) => sum + (supplierTotalAmounts[supplier.id] ?? 0.0),
    );
    final averagePhones =
        totalSuppliers > 0 ? totalPhones / totalSuppliers : 0.0;
    final maxPhones =
        filteredSuppliers.isEmpty
            ? 0
            : filteredSuppliers
                .map((supplier) => supplierPhoneCounts[supplier.id] ?? 0)
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
                          hintText: 'Search Suppliers',
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
                      onPressed: fetchSupplierData,
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
                        title: 'Total Suppliers',
                        value: totalSuppliers.toString(),
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
                        title: 'Total Purchase Amount',
                        value: formatCurrency(totalAmount),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SummaryCard(
                        title: 'Avg Phones/Supplier',
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

              // Suppliers Section Title
              Text(
                'Suppliers',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),

              // Suppliers Table
              GenericCustomTable<Supplier>(
                entries: [...filteredSuppliers],
                headers: [
                  'Supplier',
                  'Number of Products Bought',
                  'Total Amount',
                ],
                valueGetters: [
                  (supplier) => supplier.name,
                  (supplier) =>
                      (supplierPhoneCounts[supplier.id] ?? 0).toString(),
                  (supplier) =>
                      formatCurrency(supplierTotalAmounts[supplier.id] ?? 0.0),
                ],
                onTap: (supplier) {
                  // Handle tap - show detailed view
                  showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('Supplier Details'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Name: ${supplier.name}'),
                              const SizedBox(height: 8),
                              Text('Phone: ${supplier.phone}'),
                              const SizedBox(height: 8),
                              if (supplier.email.isNotEmpty) ...[
                                Text('Email: ${supplier.email}'),
                                const SizedBox(height: 8),
                              ],
                              if (supplier.address.isNotEmpty) ...[
                                Text('Address: ${supplier.address}'),
                                const SizedBox(height: 8),
                              ],
                              Text(
                                'Phones Bought: ${supplierPhoneCounts[supplier.id] ?? 0}',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Total Purchase Amount: ${formatCurrency(supplierTotalAmounts[supplier.id] ?? 0.0)}',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Balance: ${formatCurrency(supplier.balance)}',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Created: ${DateFormat.yMMMd().format(supplier.createdAt)}',
                              ),
                              if (supplier.notes.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('Notes: ${supplier.notes}'),
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
