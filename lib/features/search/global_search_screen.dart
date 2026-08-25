import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';
import '../../core/auth/session.dart';
import '../products/product_form_screen.dart';
import '../customers/customer_form_screen.dart';
import '../customers/supplier_form_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  final int companyId;
  const GlobalSearchScreen({super.key, required this.companyId});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _suppliers = [];
  bool _searched = false;
  Timer? _debounce;

  Future<void> _onQueryChanged(String query) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _products = [];
        _customers = [];
        _suppliers = [];
        _searched = false;
      });
      return;
    }
    final products = await DBHelper.instance
        .getProducts(widget.companyId, searchQuery: query, limit: 20);
    final customers = await DBHelper.instance
        .getCustomers(widget.companyId, searchQuery: query);
    final suppliers = await DBHelper.instance
        .getSuppliers(widget.companyId, searchQuery: query);
    setState(() {
      _products = products;
      _customers = customers.take(20).toList();
      _suppliers = suppliers.take(20).toList();
      _searched = true;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final noResults = _searched &&
        _products.isEmpty &&
        _customers.isEmpty &&
        _suppliers.isEmpty;

    final isOwner = Session.isOwner;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        title: TextField(
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          cursorColor: isDark ? Colors.white : Colors.black,
          decoration: InputDecoration(
            hintText: 'Product, customer ya supplier search karein...',
            hintStyle: TextStyle(
                color: isDark ? Colors.white60 : Colors.black45),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: _onQueryChanged,
        ),
      ),
      body: noResults
          ? const Center(child: Text('Kuch nahi mila'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (_products.isNotEmpty)
                  ..._section(
                      'Products',
                      _products,
                      (p) => p['name'] as String,
                      (p) {
                        if (!isOwner) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cashier products edit nahi kar sakta'))
                          );
                          return;
                        }
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ProductFormScreen(
                              companyId: widget.companyId, existing: p)));
                      }),
                if (_customers.isNotEmpty)
                  ..._section(
                      'Customers',
                      _customers,
                      (c) => c['name'] as String,
                      (c) {
                        if (!isOwner) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cashier customers edit nahi kar sakta'))
                          );
                          return;
                        }
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => CustomerFormScreen(
                              companyId: widget.companyId, existing: c)));
                      }),
                if (_suppliers.isNotEmpty)
                  ..._section(
                      'Suppliers',
                      _suppliers,
                      (s) => s['company_name'] as String,
                      (s) {
                        if (!isOwner) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cashier suppliers edit nahi kar sakta'))
                          );
                          return;
                        }
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => SupplierFormScreen(
                              companyId: widget.companyId, existing: s)));
                      }),
              ],
            ),
    );
  }

  List<Widget> _section(
      String title,
      List<Map<String, dynamic>> items,
      String Function(Map<String, dynamic>) label,
      void Function(Map<String, dynamic>) onTap) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.grey)),
      ),
      ...items.map((item) => Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              title: Text(label(item)),
              onTap: () => onTap(item),
            ),
          )),
    ];
  }
}
