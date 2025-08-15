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
import 'package:aromex/widgets/pin_dialog.dart'; // Add this import
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
  bool _isAuthenticatingForStats = false; // Add loading state

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

  // Function to handle navigation with PIN check for Statistics
  Future<void> _handleNavigation(int index) async {
    // Check if trying to navigate to Statistics page (index 7)
    if (index == 7) {
      setState(() {
        _isAuthenticatingForStats = true;
      });

      try {
        final confirmed = await showPinDialog(context);

        if (confirmed) {
          // PIN verified, allow navigation to Statistics
          setState(() {
            _selectedIndex = index;
          });
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
      } finally {
        if (mounted) {
          setState(() {
            _isAuthenticatingForStats = false;
          });
        }
      }
    } else {
      // For all other pages, navigate directly
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      children: [
        Scaffold(
          body: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: _isDrawerOpen ? 250 : 0,
                padding: const EdgeInsets.all(12),
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
                                  () => _handleNavigation(
                                    idx,
                                  ), // Updated to use new handler
                              hoverColor: Colors.white12,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    // Show loading indicator for Statistics if authenticating
                                    if (_isAuthenticatingForStats && idx == 7)
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    else
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
                                    // Add lock icon for Statistics page
                                    if (idx == 7)
                                      const Spacer()
                                    else
                                      const SizedBox.shrink(),
                                    if (idx == 7)
                                      Icon(
                                        Icons.lock,
                                        color:
                                            _selectedIndex == idx
                                                ? colorScheme.primary
                                                : colorScheme.onPrimary,
                                        size: 16,
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
        ),

        // Global overlay loader for PIN authentication
        if (_isAuthenticatingForStats)
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
                        'Verifying access...',
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

class Page {
  final String title;
  final IconData icon;
  final Widget page;

  Page(this.title, this.icon, this.page);
}
