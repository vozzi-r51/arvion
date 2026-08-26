import 'package:flutter/material.dart';
import 'dart:convert';
import '../../core/database/db_helper.dart';
import '../../core/audit/audit_logger.dart';
import '../../core/templates/business_type_catalog.dart';
import '../../core/templates/business_templates.dart';
import '../../core/theme/design_tokens.dart';
import '../shell/main_shell.dart';

class OnboardingWizardScreen extends StatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  State<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends State<OnboardingWizardScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Data
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _ownerCtrl = TextEditingController();
  
  BusinessCategory? _selectedCategory;
  String? _selectedSubtype;
  
  String _currency = 'Rs.';
  double _taxPercent = 0;
  final Map<String, bool> _modules = {};

  @override
  void initState() {
    super.initState();
    // Default modules for general retail
    _selectedCategory = kBusinessCategories.first;
    _applyTemplateFamily(_selectedCategory!.family);
  }

  void _applyTemplateFamily(TemplateFamily family) {
    final t = BusinessTemplates.getByFamily(family);
    setState(() {
      _modules.clear();
      final allPossible = [
        'sales', 'purchases', 'inventory', 'expenses',
        'accounting', 'hr', 'promotions', 'quotations',
        'committee', 'cheque'
      ];
      for (var m in allPossible) {
        _modules[m] = t.enabledModules.contains(m);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _ownerCtrl.dispose();
    super.dispose();
  }

  void _next() {
    bool canGoNext = false;
    String error = '';

    switch (_currentStep) {
      case 0:
        if (_nameCtrl.text.trim().isNotEmpty) {
          canGoNext = true;
        } else {
          error = 'Company ka naam zaroori hai';
        }
        break;
      case 1:
        if (_selectedCategory != null) {
          canGoNext = true;
        } else {
          error = 'Business type select karein';
        }
        break;
      case 2:
        if (_selectedSubtype != null || (_selectedCategory?.subtypes.isEmpty ?? true)) {
          canGoNext = true;
        } else {
          error = 'Subtype select karein';
        }
        break;
      case 3:
        canGoNext = true;
        break;
      case 4:
        canGoNext = true;
        break;
    }

    if (canGoNext) {
      if (_currentStep < 4) {
        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      } else {
        _finish();
      }
    } else if (error.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _finish() async {
    final List<String> enabledModules = [];
    _modules.forEach((key, value) {
      if (value) enabledModules.add(key);
    });

    final companyId = await DBHelper.instance.insertCompany({
      'name': _nameCtrl.text.trim(),
      'owner_name': _ownerCtrl.text.trim(),
      'business_type': _selectedCategory?.id ?? 'general_retail',
      'business_category': _selectedSubtype ?? _selectedCategory?.label,
      'currency_symbol': _currency,
      'default_tax_percent': _taxPercent,
      'terminology_profile': _selectedCategory?.id ?? 'general_retail',
      'enabled_modules': jsonEncode(enabledModules),
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });

    await AuditLogger.log(
      companyId: companyId,
      module: 'Setup',
      action: AuditLogger.create,
      description: 'Business setup mukammal: ${_selectedCategory?.id} (${_selectedSubtype})',
    );

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Step ${_currentStep + 1} of 5'),
        leading: _currentStep > 0 
          ? IconButton(
              icon: const Icon(Icons.arrow_back), 
              onPressed: () => _pageController.previousPage(
                duration: const Duration(milliseconds: 300), 
                curve: Curves.easeInOut
              )
            )
          : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.close), 
            onPressed: () => Navigator.pop(context)
          )
        ],
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _currentStep = i),
        children: [
          _buildStep1(), // Basic Info
          _buildStep2(), // Category
          _buildStep3(), // Subtype
          _buildStep4(), // Prefs
          _buildStep5(), // Modules
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: FilledButton(
            onPressed: _next,
            child: Text(_currentStep == 4 ? 'Finish & Start Business' : 'Next'),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const Icon(Icons.rocket_launch, size: 64, color: Colors.blue),
        const SizedBox(height: AppSpacing.l),
        Text(
          'Khush Amdeed!', 
          style: AppTypography.headlineMedium(context).copyWith(fontWeight: FontWeight.bold)
        ),
        const Text('Apni company ya shop ki bunyadi maloomat dein.'),
        const SizedBox(height: AppSpacing.xxl),
        TextField(
          controller: _nameCtrl, 
          decoration: const InputDecoration(labelText: 'Company / Shop Naam *')
        ),
        const SizedBox(height: AppSpacing.m),
        TextField(
          controller: _ownerCtrl, 
          decoration: const InputDecoration(labelText: 'Owner Naam')
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Business Category', 
                style: AppTypography.titleLarge(context).copyWith(fontWeight: FontWeight.bold)
              ),
              const Text('Apne business ki category chunein.'),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, 
              childAspectRatio: 1.2, 
              crossAxisSpacing: 12, 
              mainAxisSpacing: 12
            ),
            itemCount: kBusinessCategories.length,
            itemBuilder: (ctx, i) {
              final cat = kBusinessCategories[i];
              final isSelected = _selectedCategory?.id == cat.id;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = cat;
                    _selectedSubtype = null;
                  });
                  _applyTemplateFamily(cat.family);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Colors.white,
                    borderRadius: AppRadius.medium,
                    border: Border.all(
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300, 
                      width: 2
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        cat.icon, 
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey, 
                        size: 32
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cat.label, 
                        textAlign: TextAlign.center, 
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, 
                          fontSize: 11
                        )
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    if (_selectedCategory == null || _selectedCategory!.subtypes.isEmpty) {
      return Center(
        child: Text(
          'No subtypes for this category.\nClick Next to continue.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyLarge(context),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text(
          'Specific Type', 
          style: AppTypography.titleLarge(context).copyWith(fontWeight: FontWeight.bold)
        ),
        Text('Aapka ${_selectedCategory!.label} business kis tarah ka hai?'),
        const SizedBox(height: AppSpacing.xl),
        ..._selectedCategory!.subtypes.map((sub) {
          final isSelected = _selectedSubtype == sub;
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.medium,
              side: BorderSide(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300, width: 2),
            ),
            child: ListTile(
              title: Text(sub),
              trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blue) : null,
              onTap: () => setState(() => _selectedSubtype = sub),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStep4() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text(
          'Preferences', 
          style: AppTypography.titleLarge(context).copyWith(fontWeight: FontWeight.bold)
        ),
        const SizedBox(height: AppSpacing.xl),
        DropdownButtonFormField<String>(
          value: _currency,
          decoration: const InputDecoration(labelText: 'Currency'),
          items: const [
            DropdownMenuItem(value: 'Rs.', child: Text('Rs.')),
            DropdownMenuItem(value: 'USD', child: Text('USD')),
            DropdownMenuItem(value: 'EUR', child: Text('EUR')),
            DropdownMenuItem(value: 'GBP', child: Text('GBP')),
            DropdownMenuItem(value: 'AED', child: Text('AED')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _currency = v);
          },
        ),
        const SizedBox(height: AppSpacing.l),
        TextField(
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Default Tax (%)', 
            hintText: '0'
          ),
          onChanged: (v) => _taxPercent = double.tryParse(v) ?? 0,
        ),
      ],
    );
  }

  Widget _buildStep5() {
    final keys = _modules.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: keys.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Features', 
                style: AppTypography.titleLarge(context).copyWith(fontWeight: FontWeight.bold)
              ),
              const Text('Jo features aap use karna chahte hain unhein on rakhein.'),
              const SizedBox(height: AppSpacing.xl),
            ],
          );
        }
        final m = keys[i - 1];
        return CheckboxListTile(
          title: Text(m.toUpperCase()),
          value: _modules[m],
          onChanged: (v) => setState(() => _modules[m] = v ?? false),
        );
      },
    );
  }
}
