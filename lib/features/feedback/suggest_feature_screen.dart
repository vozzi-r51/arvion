import 'package:flutter/material.dart';
import '../../core/feedback/feedback_service.dart';
import '../../core/theme/design_tokens.dart';

class SuggestFeatureScreen extends StatefulWidget {
  final int companyId;
  const SuggestFeatureScreen({super.key, required this.companyId});

  @override
  State<SuggestFeatureScreen> createState() => _SuggestFeatureScreenState();
}

class _SuggestFeatureScreenState extends State<SuggestFeatureScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'Sales';
  bool _submitting = false;

  static const List<String> _categories = [
    'Sales',
    'Purchases',
    'Inventory',
    'Accounting',
    'Manufacturing',
    'Reports',
    'Other',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feature Title zaroori hai.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await FeedbackService.instance.submitFeedback(
        companyId: widget.companyId,
        title: title,
        category: _category,
        description: _descCtrl.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aapki suggestion save ho gayi hai. Shukriya!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suggest a Feature')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.l),
          children: [
            Card(
              color: Colors.indigo.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.indigo, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Aapka feedback hamare liye ahem hai! BizManager ko mazeed behtar banane ke liye apni raye dein.',
                        style: TextStyle(fontSize: 13, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Feature Title * (e.g. WhatsApp Invoice Sending)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Detail Description (Kaise kaam kare aur kyun faida hoga?)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Submit Feedback'),
            ),
          ],
        ),
      ),
    );
  }
}
