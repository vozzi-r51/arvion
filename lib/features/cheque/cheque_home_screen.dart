import 'package:flutter/material.dart';
import 'cheque_list_screen.dart';

class ChequeHomeScreen extends StatelessWidget {
  final int companyId;
  const ChequeHomeScreen({super.key, required this.companyId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cheque Management'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Received'),
              Tab(text: 'Issued'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ChequeListScreen(companyId: companyId, type: 'received'),
            ChequeListScreen(companyId: companyId, type: 'issued'),
          ],
        ),
      ),
    );
  }
}
