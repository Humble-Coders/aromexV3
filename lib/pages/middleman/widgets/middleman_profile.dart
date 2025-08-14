import 'package:aromex/models/balance_generic.dart';
import 'package:aromex/models/middleman.dart';
import 'package:aromex/models/purchase.dart';
import 'package:aromex/models/sale.dart';
import 'package:aromex/pages/home/pages/sale_detail_page.dart';
import 'package:aromex/pages/home/widgets/balance_card.dart';
import 'package:aromex/widgets/generic_custom_table.dart';
import 'package:aromex/widgets/profile_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

class MiddlemanProfile extends StatefulWidget {
  final VoidCallback? onBack;
  final Middleman? middleman;
  const MiddlemanProfile({super.key, this.onBack, required this.middleman});

  @override
  State<MiddlemanProfile> createState() => _MiddlemanProfileState();
}

class _MiddlemanProfileState extends State<MiddlemanProfile> {
  List<Sale> sales = [];
  bool isLoading = true;
  late Middleman currentMiddleman;
  SaleDetailPage? saleDetailPage;
  @override
  void initState() {
    super.initState();
    currentMiddleman = widget.middleman!;
    loadSales();
  }

  String formatPaymentSource(Sale sale) {
    List<String> paymentParts = [];

    // Check for cash payment - keep original format
    if (sale.cashPaid != null && sale.cashPaid! > 0) {
      paymentParts.add('Cash(${sale.cashPaid!.toInt()})');
    }

    // Check for UPI payment - keep original format
    if (sale.upiPaid != null && sale.upiPaid! > 0) {
      paymentParts.add('Card(${sale.upiPaid!.toInt()})');
    }

    // Check for bank payment - keep original format
    if (sale.bankPaid != null && sale.bankPaid! > 0) {
      paymentParts.add('Bank(${sale.bankPaid!.toInt()})');
    }

    // If no specific payment amounts, fall back to original paymentSource

    // Join multiple payment methods with comma and space - keep original format
    return paymentParts.isNotEmpty ? paymentParts.join(', ') : 'Unknown';
  }

  Future<List<Sale>> fetchSales(List<DocumentReference>? refs) async {
    if (refs == null || refs.isEmpty) {
      return [];
    }

    try {
      final snapshots = await Future.wait(refs.map((ref) => ref.get()));
      return snapshots
          .where((snap) => snap.exists && snap.data() != null)
          .map((snap) => Sale.fromFirestore(snap))
          .toList();
    } catch (e) {
      print('Error fetching sales: $e');
      return [];
    }
  }

  Future<void> loadSales() async {
    setState(() {
      isLoading = true;
    });

    try {
      if (currentMiddleman.transactionHistory != null) {
        final fetched = await fetchSales(currentMiddleman.transactionHistory);

        if (mounted) {
          setState(() {
            sales = fetched;
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            sales = [];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error in loadSales: $e');
      if (mounted) {
        setState(() {
          sales = [];
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (saleDetailPage != null) {
      return saleDetailPage!;
    }

    Timestamp? updatedAtTimestamp = currentMiddleman.updatedAt;
    String updatedAt = "N/A";
    if (updatedAtTimestamp != null) {
      final date = updatedAtTimestamp.toDate();
      updatedAt = DateFormat.yMd().add_jm().format(date);
    }

    return SingleChildScrollView(
      child: Card(
        color: colorScheme.secondary,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(36, 12, 36, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              const SizedBox(height: 16),
              ProfileCard(
                name: currentMiddleman.name,
                email: currentMiddleman.email,
                phoneNumber: currentMiddleman.phone,
                address: currentMiddleman.address,
                createdAt: currentMiddleman.createdAt,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: BalanceCard(
                      icon: SvgPicture.asset(
                        'assets/icons/credit_card.svg',
                        width: 40,
                        height: 40,
                      ),
                      title: "Credit Details",
                      amount: currentMiddleman.balance,
                      updatedAt: updatedAt,
                      isLoading: false,
                      onTap: () {},
                    ),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
              const SizedBox(height: 16),
              sales.isNotEmpty
                  ? GenericCustomTable<Sale>(
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
                    entries: sales,
                    headers: [
                      "Date",
                      "Order No.",
                      "Amount",
                      "Payment Source",
                      "Credit",
                    ],
                    valueGetters: [
                      (p) => DateFormat.yMd().format(p.date),
                      (p) => p.orderNumber,
                      (p) =>
                          NumberFormat.currency(symbol: '\$').format(p.amount),
                      (p) => formatPaymentSource(p),
                      (p) =>
                          NumberFormat.currency(symbol: '\$').format(p.credit),
                    ],
                  )
                  : isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Center(
                    child: Text(
                      'No Sales Found',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSecondary,
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
