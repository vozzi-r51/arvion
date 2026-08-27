import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

class HelpArticle {
  final String category;
  final String question;
  final String answer;

  const HelpArticle({
    required this.category,
    required this.question,
    required this.answer,
  });
}

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  String _searchQuery = '';
  String? _selectedCategory;

  static const List<HelpArticle> _faqs = [
    HelpArticle(
      category: 'Sales & Invoicing',
      question: 'Nayi Sale kaise create karein?',
      answer: 'Sales tab mein "Nayi Sale" button dabaayein, products add karein, discount ya customer select karein aur "Complete Sale" par click karein.',
    ),
    HelpArticle(
      category: 'Sales & Invoicing',
      question: 'FBR Digital Invoicing QR Code kaise print hoga?',
      answer: 'Company Profile mein FBR POS ID enter karein. Sale complete hone par 18-digit FBR invoice number aur QR code receipt par automatically print hoga.',
    ),
    HelpArticle(
      category: 'Payments',
      question: 'JazzCash, EasyPaisa ya Raast se payment kaise lein?',
      answer: 'Sale ya Purchase screens par payment method dropdown se JazzCash/EasyPaisa/Raast select karein aur Transaction ID (TRX ID) enter karein.',
    ),
    HelpArticle(
      category: 'Inventory',
      question: 'Low Stock Alerts kaise set karein?',
      answer: 'Product Form mein "Reorder Level" enter karein. Jab stock is se kam hoga, Dashboard aur Stock Report mein warning badge show hoga.',
    ),
    HelpArticle(
      category: 'Accounting',
      question: 'Fiscal Year End Closing process kya hai?',
      answer: 'More -> Fiscal Year-End Closing par jaayein. System Net Profit ko Retained Earnings account mein transfer karke pichlay saal ka data lock kar dega.',
    ),
    HelpArticle(
      category: 'Security',
      question: 'Database Encryption aur Sensitive Screen Lock kaise kaam karta hai?',
      answer: 'Aapka database Android KeyStore AES-256 key se encrypted hai. Settings mein Sensitive Screen Auto-Lock 30s set kar ke app ko lock kar sakte hain.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _faqs.where((faq) {
      final matchesQuery = faq.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          faq.answer.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == null || faq.category == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Help & Resource Center')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Sawaal ya feature search karein...',
                border: OutlineInputBorder(borderRadius: AppRadius.medium),
                filled: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Sab'),
                  selected: _selectedCategory == null,
                  onSelected: (_) => setState(() => _selectedCategory = null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Sales'),
                  selected: _selectedCategory == 'Sales & Invoicing',
                  onSelected: (_) => setState(() => _selectedCategory = 'Sales & Invoicing'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Payments'),
                  selected: _selectedCategory == 'Payments',
                  onSelected: (_) => setState(() => _selectedCategory = 'Payments'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Accounting'),
                  selected: _selectedCategory == 'Accounting',
                  onSelected: (_) => setState(() => _selectedCategory = 'Accounting'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.l),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final faq = filtered[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.m),
                  child: ExpansionTile(
                    title: Text(faq.question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(faq.category, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text(faq.answer, style: const TextStyle(fontSize: 13, height: 1.4)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
