import 'package:flutter/material.dart';

/// In-App "Suggest a Feature / Report Bug" Dialog.
class FeedbackDialog extends StatefulWidget {
  final int companyId;
  const FeedbackDialog({super.key, required this.companyId});

  static void show(BuildContext context, int companyId) {
    showDialog(
      context: context,
      builder: (_) => FeedbackDialog(companyId: companyId),
    );
  }

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final TextEditingController _feedbackCtrl = TextEditingController();
  String _type = 'Feature Suggestion';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.feedback_outlined, color: Colors.indigo),
          SizedBox(width: 8),
          Text('Suggest a Feature / Feedback'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Feedback Type'),
            items: const [
              DropdownMenuItem(value: 'Feature Suggestion', child: Text('Naye Feature ki Khwahish')),
              DropdownMenuItem(value: 'Bug Report', child: Text('Masla / Bug Report')),
              DropdownMenuItem(value: 'General', child: Text('Aam Feedback')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _type = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _feedbackCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Apna feedback ya naye feature ki details likhein...',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_feedbackCtrl.text.trim().isEmpty) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Aapka feedback bhej diya gaya hai. Shukriya!'), backgroundColor: Colors.green),
            );
          },
          child: const Text('Submit Feedback'),
        ),
      ],
    );
  }
}
