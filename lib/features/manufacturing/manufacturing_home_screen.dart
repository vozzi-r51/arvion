import 'package:flutter/material.dart';
import 'bom_list_screen.dart';
import 'production_order_list_screen.dart';

class ManufacturingHomeScreen extends StatelessWidget {
  final int companyId;
  const ManufacturingHomeScreen({super.key, required this.companyId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manufacturing Module'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.precision_manufacturing), text: 'Production Orders'),
              Tab(icon: Icon(Icons.format_list_bulleted), text: 'Bill of Materials (BOM)'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ProductionOrderListScreen(companyId: companyId),
            BomListScreen(companyId: companyId),
          ],
        ),
      ),
    );
  }
}
