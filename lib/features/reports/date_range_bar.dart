import 'package:flutter/material.dart';

/// A compact "From ... To ..." row with tappable date chips, used at the
/// top of every report screen. Defaults elsewhere are usually "last 30
/// days" — this widget just renders whatever range it's given and reports
/// back a new range when either date is tapped and changed.
class DateRangeBar extends StatelessWidget {
  final DateTime from;
  final DateTime to;
  final ValueChanged<DateTime> onFromChanged;
  final ValueChanged<DateTime> onToChanged;

  const DateRangeBar({
    super.key,
    required this.from,
    required this.to,
    required this.onFromChanged,
    required this.onToChanged,
  });

  String _fmt(DateTime d) => d.toIso8601String().substring(0, 10);

  Future<void> _pick(BuildContext context, DateTime initial,
      ValueChanged<DateTime> onChanged) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(context, from, onFromChanged),
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text('From ${_fmt(from)}'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(context, to, onToChanged),
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text('To ${_fmt(to)}'),
            ),
          ),
        ],
      ),
    );
  }
}
