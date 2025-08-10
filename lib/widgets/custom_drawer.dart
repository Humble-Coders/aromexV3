import 'package:aromex/AddContactInfo.dart';
import 'package:aromex/pages/customer/main.dart';
import 'package:aromex/pages/home/main.dart';
import 'package:aromex/pages/inventory/main.dart';
import 'package:aromex/pages/middleman/main.dart';
import 'package:aromex/pages/purchase/main.dart';
import 'package:aromex/pages/sale/main.dart';
import 'package:aromex/pages/statistics/main.dart';
import 'package:aromex/pages/supplier/main.dart';
import 'package:aromex/widgets/app_bar.dart';
import 'package:flutter/material.dart';

class CustomDrawer extends StatefulWidget {
  final VoidCallback onLogout;
  const CustomDrawer({super.key, required this.onLogout});

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  int _selectedIndex = 0;
  bool _isDrawerOpen = true;
  final _pages = [
    Page("Home", Icons.home, const HomePage()),
    Page("Purchase", Icons.handshake_outlined, PurchasePage()),
    Page("Sales", Icons.currency_exchange_outlined, const SalePage()),
    Page("Supplier Profile", Icons.person, const SupplierPage()),
    Page("Customer Profile", Icons.people, const CustomerPage()),
    Page("Middleman Profile", Icons.person_2, const MiddlemanPage()),
    Page("Inventory", Icons.inventory_2, const InventoryPage()),
    Page("Statistics", Icons.analytics, const StatisticsNavigationPage()),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: _isDrawerOpen ? 250 : 0,
            padding: EdgeInsets.all(12),
            color: colorScheme.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  'AROMEX',
                  maxLines: 1,
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 64),
                ListView.separated(
                  scrollDirection: Axis.vertical,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _pages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (ctx, idx) {
                    return Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color:
                            _selectedIndex == idx
                                ? Colors.white
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      width: double.infinity,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap:
                              () => setState(() {
                                _selectedIndex = idx;
                              }),
                          hoverColor: Colors.white12,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Icon(
                                  _pages[idx].icon,
                                  color:
                                      _selectedIndex == idx
                                          ? colorScheme.primary
                                          : colorScheme.onPrimary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _pages[idx].title,
                                  maxLines: 1,
                                  style: textTheme.titleMedium?.copyWith(
                                    color:
                                        _selectedIndex == idx
                                            ? colorScheme.primary
                                            : colorScheme.onPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                MyAppBar(
                  title: _pages[_selectedIndex].title,
                  onHamburgerTap: () {
                    setState(() {
                      _isDrawerOpen = !_isDrawerOpen;
                    });
                  },
                  onProfileTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddContactInfo(),
                      ),
                    );
                  },
                ),
                Expanded(child: _pages[_selectedIndex].page),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Page {
  final String title;
  final IconData icon;
  final Widget page;

  Page(this.title, this.icon, this.page);
}
