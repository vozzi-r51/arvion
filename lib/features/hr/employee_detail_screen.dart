import 'package:flutter/material.dart';
import 'attendance_tab.dart';
import 'salary_tab.dart';
import 'advance_tab.dart';
import 'commission_tab.dart';

class EmployeeDetailScreen extends StatelessWidget {
  final int companyId;
  final Map<String, dynamic> employee;
  const EmployeeDetailScreen(
      {super.key, required this.companyId, required this.employee});

  @override
  Widget build(BuildContext context) {
    final employeeId = employee['id'] as int;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(employee['name'] as String),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Attendance'),
              Tab(text: 'Salary'),
              Tab(text: 'Advance'),
              Tab(text: 'Commission'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            AttendanceTab(companyId: companyId, employeeId: employeeId),
            SalaryTab(companyId: companyId, employee: employee),
            AdvanceTab(companyId: companyId, employeeId: employeeId),
            CommissionTab(companyId: companyId, employeeId: employeeId),
          ],
        ),
      ),
    );
  }
}
