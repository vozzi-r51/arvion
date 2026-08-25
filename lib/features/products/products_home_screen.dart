import 'package:flutter/material.dart';
import 'product_list_screen.dart';
import 'category_list_screen.dart';
import 'brand_list_screen.dart';
import '../import_export/product_import_screen.dart';
import '../shell/main_shell.dart';

class ProductsHomeScreen extends StatelessWidget {
  final int companyId;
  const ProductsHomeScreen({super.key, required this.companyId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: MainShell.getMenuButton(context),
          title: const Text('Inventory'),
          actions: [
            IconButton(
              icon: const Icon(Icons.upload_file_outlined),
              tooltip: 'Bulk Import',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ProductImportScreen(companyId: companyId)),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Products'),
              Tab(text: 'Categories'),
              Tab(text: 'Brands'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ProductListScreen(companyId: companyId),
            CategoryListScreen(companyId: companyId),
            BrandListScreen(companyId: companyId),
          ],
        ),
      ),
    );
  }
}
