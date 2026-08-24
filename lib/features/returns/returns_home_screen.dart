import 'package:flutter/material.dart';
import 'sales_returns_list_screen.dart';
import 'purchase_returns_list_screen.dart';

class ReturnsHomeScreen extends StatelessWidget {
  final int companyId;
  const ReturnsHomeScreen({super.key, required this.companyId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Returns'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Sales Returns'),
              Tab(text: 'Purchase Returns'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SalesReturnsListScreen(companyId: companyId),
            PurchaseReturnsListScreen(companyId: companyId),
          ],
        ),
      ),
    );
  }
}
