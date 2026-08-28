import 'package:flutter/material.dart';
import '../../core/database/db_helper.dart';

class EmployeeFormScreen extends StatefulWidget {
  final int companyId;
  final Map<String, dynamic>? existing;
  const EmployeeFormScreen({super.key, required this.companyId, this.existing});

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final _nameCtrl = TextEditingController();
  final _urduCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cnicCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  DateTime _joiningDate = DateTime.now();
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e['name'] as String? ?? '';
      _urduCtrl.text = e['urdu_name'] as String? ?? '';
      _phoneCtrl.text = e['phone'] as String? ?? '';
      _addressCtrl.text = e['address'] as String? ?? '';
      _cnicCtrl.text = e['cnic'] as String? ?? '';
      _designationCtrl.text = e['designation'] as String? ?? '';
      _departmentCtrl.text = e['department'] as String? ?? '';
      _salaryCtrl.text = '${e['monthly_salary'] ?? 0}';
      _notesCtrl.text = e['notes'] as String? ?? '';
      final jd = e['joining_date'] as String?;
      if (jd != null) _joiningDate = DateTime.tryParse(jd) ?? DateTime.now();
    }
  }

  double _num(String s) => double.tryParse(s.trim()) ?? 0;

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Naam zaroori hai')));
      return;
    }
    setState(() => _saving = true);

    final data = {
      'company_id': widget.companyId,
      'name': _nameCtrl.text.trim(),
      'urdu_name': _urduCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'cnic': _cnicCtrl.text.trim(),
      'designation': _designationCtrl.text.trim(),
      'department': _departmentCtrl.text.trim(),
      'monthly_salary': _num(_salaryCtrl.text),
      'joining_date': _joiningDate.toIso8601String(),
      'notes': _notesCtrl.text.trim(),
      'status': 'active',
    };

    if (_isEditing) {
      await DBHelper.instance
          .updateEmployee(widget.existing!['id'] as int, data);
    } else {
      data['created_at'] = DateTime.now().toIso8601String();
      await DBHelper.instance.insertEmployee(data);
    }

    setState(() => _saving = false);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urduCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cnicCtrl.dispose();
    _designationCtrl.dispose();
    _departmentCtrl.dispose();
    _salaryCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_isEditing ? 'Employee Edit Karein' : 'Naya Employee')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Naam *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urduCtrl,
            decoration: const InputDecoration(labelText: 'Urdu Naam'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressCtrl,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Address'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cnicCtrl,
            decoration: const InputDecoration(labelText: 'CNIC'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _designationCtrl,
                  decoration: const InputDecoration(labelText: 'Designation'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _departmentCtrl,
                  decoration: const InputDecoration(labelText: 'Department'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _salaryCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:
                const InputDecoration(labelText: 'Monthly Salary (Rs.)'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
                'Joining Date: ${_joiningDate.toIso8601String().substring(0, 10)}'),
            trailing: const Icon(Icons.calendar_today, size: 18),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _joiningDate,
                firstDate: DateTime(2015),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _joiningDate = picked);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Employee Save Karein'),
          ),
        ],
      ),
    );
  }
}
