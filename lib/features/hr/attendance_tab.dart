import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class AttendanceTab extends StatefulWidget {
  final int companyId;
  final int employeeId;
  const AttendanceTab({super.key, required this.companyId, required this.employeeId});

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  List<Map<String, dynamic>> _records = [];
  Map<String, dynamic>? _todayRecord;
  bool _loading = true;

  String get _today => DateTime.now().toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final records = await DBHelper.instance.getAttendanceForEmployee(widget.employeeId);
    final todayRecord =
        await DBHelper.instance.getAttendanceForDate(widget.employeeId, _today);
    setState(() {
      _records = records;
      _todayRecord = todayRecord;
      _loading = false;
    });
  }

  Future<void> _mark(String status) async {
    await DBHelper.instance.markAttendance({
      'company_id': widget.companyId,
      'employee_id': widget.employeeId,
      'date': _today,
      'status': status,
      'created_at': DateTime.now().toIso8601String(),
    });
    _load();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'leave':
        return Colors.orange;
      case 'half_day':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'present':
        return 'Present';
      case 'absent':
        return 'Absent';
      case 'leave':
        return 'Leave';
      case 'half_day':
        return 'Half Day';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Text('Aaj ($_today)',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (_todayRecord != null)
                    Chip(
                      label: Text(_statusLabel(_todayRecord!['status'] as String)),
                      backgroundColor:
                          _statusColor(_todayRecord!['status'] as String).withOpacity(0.15),
                      labelStyle:
                          TextStyle(color: _statusColor(_todayRecord!['status'] as String)),
                    )
                  else
                    const Text('Abhi mark nahi hui', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _markButton('Present', 'present', Colors.green),
                      _markButton('Absent', 'absent', Colors.red),
                      _markButton('Leave', 'leave', Colors.orange),
                      _markButton('Half Day', 'half_day', Colors.blue),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _records.isEmpty
              ? const Center(child: Text('Abhi koi attendance record nahi hai'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _records.length,
                  itemBuilder: (ctx, i) {
                    final r = _records[i];
                    final status = r['status'] as String;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _statusColor(status).withOpacity(0.15),
                          child: Icon(Icons.calendar_today,
                              color: _statusColor(status), size: 18),
                        ),
                        title: Text(r['date'] as String),
                        trailing: Text(
                          _statusLabel(status),
                          style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _markButton(String label, String status, Color color) {
    final isSelected = _todayRecord?['status'] == status;
    return OutlinedButton(
      onPressed: () => _mark(status),
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? color.withOpacity(0.15) : null,
        side: BorderSide(color: color),
        foregroundColor: color,
      ),
      child: Text(label),
    );
  }
}
