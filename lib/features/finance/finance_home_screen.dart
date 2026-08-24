import 'package:flutter/material.dart';
import 'expense_list_screen.dart';
import 'income_list_screen.dart';

class FinanceHomeScreen extends StatelessWidget {
  final int companyId;
  const FinanceHomeScreen({super.key, required this.companyId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Expenses & Income'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Expenses'),
              Tab(text: 'Income'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ExpenseListScreen(companyId: companyId),
            IncomeListScreen(companyId: companyId),
          ],
        ),
      ),
    );
  }
}
