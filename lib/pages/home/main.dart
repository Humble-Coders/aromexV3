import 'package:aromex/pages/home/pages/expense_record.dart';
import 'package:aromex/pages/home/pages/home.dart';
import 'package:aromex/pages/home/pages/purchase_record.dart';
import 'package:aromex/pages/home/pages/sale_record.dart';
import 'package:aromex/pages/inventory/main.dart';
import 'package:aromex/pages/statistics/main.dart';
import 'package:flutter/material.dart';

enum Pages {
  home,
  saleRecord,
  purchaseRecord,
  expenseRecord,
  InventoryPage,
  StatisticsPage,
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final PageController _pageController;
  int _currentIndex = 0;

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();

    _pageController = PageController(initialPage: _currentIndex);

    void changePage(Pages page) {
      final index = Pages.values.indexOf(page);
      _pageController.jumpToPage(index);
    }

    _pages.addAll([
      HomePageBase(onPageChange: changePage),
      SaleRecord(onBack: () => changePage(Pages.home)),
      PurchaseRecord(onBack: () => changePage(Pages.home)),

      ExpenseRecord(onBack: () => changePage(Pages.home)),
      InventoryPage(onBack: () => changePage(Pages.home)),
      StatisticsNavigationPage(onBack: () => changePage(Pages.home)),
    ]);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvoked: (didPop) {
        if (!didPop && _currentIndex != 0) {
          _pageController.jumpToPage(0);
        }
      },
      child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _pages,
      ),
    );
  }
}
