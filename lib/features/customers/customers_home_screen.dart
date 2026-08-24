import 'package:flutter/material.dart';
import 'customer_list_screen.dart';
import 'supplier_list_screen.dart';

class CustomersHomeScreen extends StatelessWidget {
  final int companyId;
  const CustomersHomeScreen({super.key, required this.companyId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Customers & Suppliers'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Customers'),
              Tab(text: 'Suppliers'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            CustomerListScreen(companyId: companyId),
            SupplierListScreen(companyId: companyId),
          ],
        ),
      ),
    );
  }
}
