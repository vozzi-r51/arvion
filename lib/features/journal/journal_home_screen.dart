import 'package:flutter/material.dart';
import 'journal_entries_tab.dart';
import 'trial_balance_tab.dart';
import 'balance_sheet_tab.dart';

class JournalHomeScreen extends StatelessWidget {
  final int companyId;
  const JournalHomeScreen({super.key, required this.companyId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Journal & Accounts'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Journal'),
              Tab(text: 'Trial Balance'),
              Tab(text: 'Balance Sheet'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            JournalEntriesTab(companyId: companyId),
            TrialBalanceTab(companyId: companyId),
            BalanceSheetTab(companyId: companyId),
          ],
        ),
      ),
    );
  }
}
