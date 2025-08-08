import 'package:aromex/pages/home/widgets/action_card.dart';
import 'package:aromex/pages/statistics/widgets/customer_credit_dashboard.dart';
import 'package:aromex/pages/statistics/widgets/customer_products.dart';
import 'package:aromex/pages/statistics/widgets/middleman_revenue.dart';
import 'package:aromex/pages/statistics/widgets/sales_dashboard.dart';
import 'package:aromex/pages/statistics/widgets/supplier_credit_dashboard.dart';
import 'package:aromex/pages/statistics/widgets/supplier_products.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class StatisticsNavigationPage extends StatefulWidget {
  final VoidCallback? onBack;
  const StatisticsNavigationPage({super.key, this.onBack});

  @override
  State<StatisticsNavigationPage> createState() =>
      _StatisticsNavigationPageState();
}

class _StatisticsNavigationPageState extends State<StatisticsNavigationPage> {
  int currentPage = 0;

  void _navigateToPage(int pageIndex) {
    setState(() {
      currentPage = pageIndex;
    });
  }

  void _onBack() {
    setState(() {
      currentPage = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return currentPage == 0
        ? _buildNavigationPage(context)
        : currentPage == 1
        ? SalesDashboard(onBack: _onBack)
        : currentPage == 2
        ? CustomerProductsDashboard(onBack: _onBack)
        : currentPage == 3
        ? MiddlemanRevenueDashboard(onBack: _onBack)
        : currentPage == 4
        ? SupplierProductsDashboard(onBack: _onBack)
        : currentPage == 5
        ? SupplierCreditDashboard(onBack: _onBack)
        : CustomerCreditDashboard(onBack: _onBack);
  }

  Widget _buildNavigationPage(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Card(
        margin: const EdgeInsets.all(12),
        color: colorScheme.secondary,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button (similar to PurchaseRecord and InventoryPage)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onBack,
                ),
                const SizedBox(height: 12),

                // Statistics grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                  children: [
                    ActionCard(
                      icon: SvgPicture.asset(
                        'assets/icons/sale_record.svg',
                        width: 40,
                        height: 40,
                      ),
                      title: 'Sales',
                      onTap: () => _navigateToPage(1),
                    ),
                    ActionCard(
                      icon: SvgPicture.asset(
                        'assets/icons/customer.svg',
                        width: 40,
                        height: 40,
                      ),
                      title: 'Customer',
                      onTap: () => _navigateToPage(2),
                    ),
                    ActionCard(
                      icon: SvgPicture.asset(
                        'assets/icons/middleman.svg',
                        width: 40,
                        height: 40,
                      ),
                      title: 'Middleman',
                      onTap: () => _navigateToPage(3),
                    ),
                    ActionCard(
                      icon: SvgPicture.asset(
                        'assets/icons/supplier.svg',
                        width: 40,
                        height: 40,
                      ),
                      title: 'Supplier',
                      onTap: () => _navigateToPage(4),
                    ),
                    ActionCard(
                      icon: SvgPicture.asset(
                        'assets/icons/credit_card.svg',
                        width: 40,
                        height: 40,
                      ),
                      title: 'Supplier Credit Balance',
                      onTap: () => _navigateToPage(5),
                    ),
                    ActionCard(
                      icon: Image.asset(
                        'assets/icons/cash_balance.png',
                        width: 40,
                        height: 40,
                      ),
                      title: 'Customer Credit Balance',
                      onTap: () => _navigateToPage(6),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
