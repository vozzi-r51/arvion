import 'package:flutter/material.dart';
import 'dart:convert';
import '../../core/database/db_helper.dart';
import '../../core/audit/audit_logger.dart';
import '../../core/business_types/business_type_catalog.dart';
import '../../core/templates/business_templates.dart';
import '../../core/theme/design_tokens.dart';
import '../shell/main_shell.dart';
import 'business_setup_animation_screen.dart';

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
  bool _isQuickSetup = true;

  String _currency = 'Rs.';
  double _taxPercent = 0;
  final Map<String, bool> _modules = {};
  String _uiMode = 'simple'; // 'simple' or 'advanced'

  String _searchQuery = '';

  List<BusinessCategory> get _filteredCategories {
    if (_searchQuery.isEmpty) return kBusinessCategories;
    final q = _searchQuery.toLowerCase();
    return kBusinessCategories.where((c) {
      final matchCat = c.label.toLowerCase().contains(q);
      final matchSub = c.subtypes.any((s) => s.toLowerCase().contains(q));
      return matchCat || matchSub;
    }).toList();
  }

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
          if (_isQuickSetup) {
            _finish();
            return;
          }
        } else {
          error = 'Business type select karein';
        }
        break;
      case 2:
        if (_selectedSubtype != null || (_selectedCategory?.subtypes.isEmpty ?? true)) {
          canGoNext = true;
          // Show animation screen after subtype selection
          _showBusinessSetupAnimation();
          return;
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
      case 5:
        canGoNext = true;
        break;
    }

    if (canGoNext) {
      if (_currentStep < 5) {
        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      } else {
        _finish();
      }
    } else if (error.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  /// Show animated setup screen after business type selection
  void _showBusinessSetupAnimation() {
    if (_selectedCategory == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BusinessSetupAnimationScreen(
          businessTypeLabel: _selectedCategory!.label,
          businessSubtype: _selectedSubtype ?? 'General',
          templateFamily: _selectedCategory!.family,
          businessIcon: _selectedCategory!.icon,
          onComplete: () {
            Navigator.of(context).pop();
            // Continue to step 4
            if (_currentStep == 2) {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          },
        ),
      ),
    );
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
      'business_category': _selectedCategory?.label ?? 'General Retail',
      'business_subtype': _selectedSubtype,
      'template_family': _selectedCategory?.family.toString().split('.').last ?? 'retailStandard',
      'currency_symbol': _currency,
      'default_tax_percent': _taxPercent,
      'terminology_profile': _selectedCategory?.id ?? 'general_retail',
      'enabled_modules': jsonEncode(enabledModules),
      'ui_mode': _uiMode,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });

    await AuditLogger.log(
      companyId: companyId,
      module: 'Setup',
      action: AuditLogger.create,
      description: 'Business setup mukammal: ${_selectedCategory?.id} (${_selectedSubtype}) - UI Mode: $_uiMode',
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
        title: Text('Step ${_currentStep + 1} of 6'),
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
          _buildStep6(), // UI Mode (Simple vs Advanced)
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: FilledButton(
            onPressed: _next,
            child: Text(_currentStep == 5 ? 'Finish & Start Business' : 'Next'),
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
        const SizedBox(height: AppSpacing.xl),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('⚡ Quick (30 sec)'), icon: Icon(Icons.bolt)),
            ButtonSegment(value: false, label: Text('⚙️ Detailed'), icon: Icon(Icons.tune)),
          ],
          selected: {_isQuickSetup},
          onSelectionChanged: (set) => setState(() => _isQuickSetup = set.first),
        ),
        const SizedBox(height: AppSpacing.xl),
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
    final filtered = _filteredCategories;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Business Category', 
                style: AppTypography.titleLarge(context).copyWith(fontWeight: FontWeight.bold)
              ),
              const Text('Apne business ki category chunein.'),
              const SizedBox(height: AppSpacing.m),
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search (e.g. Tandoor, Mobile)',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: AppRadius.medium),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
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
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final cat = filtered[i];
              final isSelected = _selectedCategory?.id == cat.id;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = cat;
                    _selectedSubtype = null;
                  });
                  _applyTemplateFamily(cat.family);
                  _next(); // Auto-move to subtypes
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
    if (_selectedCategory == null) return const SizedBox.shrink();

    final allSubtypes = _selectedCategory!.subtypes;
    if (allSubtypes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'No specific subtypes for "${_selectedCategory!.label}".\nClick Next to continue.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge(context),
              ),
            ],
          ),
        ),
      );
    }

    // Filter subtypes based on search from Step 2
    final filteredSubtypes = allSubtypes.where((s) {
      if (_searchQuery.isEmpty) return true;
      // If the category itself matches the search, show all subtypes
      if (_selectedCategory!.label.toLowerCase().contains(_searchQuery.toLowerCase())) return true;
      // Otherwise only show matching subtypes
      return s.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final displaySubtypes = filteredSubtypes.isEmpty ? allSubtypes : filteredSubtypes;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text(
          'Specific Type', 
          style: AppTypography.titleLarge(context).copyWith(fontWeight: FontWeight.bold)
        ),
        Text('Aapka ${_selectedCategory!.label} business kis tarah ka hai?'),
        const SizedBox(height: AppSpacing.xl),
        ...displaySubtypes.map((sub) {
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
        if (displaySubtypes.isEmpty)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Text('Koi matching subtype nahi mila.', textAlign: TextAlign.center),
          ),
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

  Widget _buildStep6() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text(
          'User Experience Mode',
          style: AppTypography.titleLarge(context).copyWith(fontWeight: FontWeight.bold)
        ),
        const SizedBox(height: AppSpacing.m),
        const Text('Aap kaisa control chahte hain? Simple mode naye users ke liye behtar hai.'),
        const SizedBox(height: AppSpacing.xl),

        // Simple Mode Card
        _buildModeCard(
          mode: 'simple',
          title: 'Simple Mode (Recommended)',
          description: 'Basic fields only, easy to use\n• Product name & price\n• Basic sales & purchases\n• Customer ledger',
          icon: Icons.dashboard,
          isSelected: _uiMode == 'simple',
          onTap: () => setState(() => _uiMode = 'simple'),
        ),

        const SizedBox(height: AppSpacing.l),

        // Advanced Mode Card
        _buildModeCard(
          mode: 'advanced',
          title: 'Advanced Mode',
          description: 'All features visible\n• Variants & custom fields\n• Multi-UOM & multi-tax\n• Manufacturing & accounting',
          icon: Icons.engineering,
          isSelected: _uiMode == 'advanced',
          onTap: () => setState(() => _uiMode = 'advanced'),
        ),
      ],
    );
  }

  Widget _buildModeCard({
    required String mode,
    required String title,
    required String description,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Colors.white,
          borderRadius: AppRadius.medium,
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 40,
              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
            ),
            const SizedBox(width: AppSpacing.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleMedium(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    description,
                    style: AppTypography.bodyMedium(context).copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }
}
