import 'package:flutter/material.dart';
import '../../core/templates/business_templates.dart';
import '../../core/business_types/business_type_catalog.dart';
import '../../core/theme/design_tokens.dart';

class BusinessSetupAnimationScreen extends StatefulWidget {
  final String businessTypeLabel;
  final String businessSubtype;
  final TemplateFamily templateFamily;
  final IconData businessIcon;
  final VoidCallback onComplete;

  const BusinessSetupAnimationScreen({
    super.key,
    required this.businessTypeLabel,
    required this.businessSubtype,
    required this.templateFamily,
    required this.businessIcon,
    required this.onComplete,
  });

  @override
  State<BusinessSetupAnimationScreen> createState() =>
      _BusinessSetupAnimationScreenState();
}

class _BusinessSetupAnimationScreenState
    extends State<BusinessSetupAnimationScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _itemAnimations;
  final List<String> _checklistItems = [];
  bool _animationComplete = false;

  @override
  void initState() {
    super.initState();
    _initializeChecklist();
    _setupAnimations();
  }

  void _initializeChecklist() {
    // Get template to extract setup info
    final template = BusinessTemplates.getByFamily(
      widget.templateFamily,
      categoryTitle: widget.businessTypeLabel,
      icon: widget.businessIcon,
    );

    // Build checklist from template
    _checklistItems.addAll([
      '✓ Chart of Accounts ready',
      '✓ Categories added',
      '✓ Units configured',
    ]);

    // Add template-specific items
    if (template.hasVariants) {
      _checklistItems.add('✓ Size/Color Variants enabled');
    }
    if (template.hasCustomFields) {
      _checklistItems.add('✓ Weight/Purity fields ready');
    }
    if (template.hasBatchExpiry) {
      _checklistItems.add('✓ Batch & Expiry tracking enabled');
    }
    if (template.hasSerialNumbers) {
      _checklistItems.add('✓ Serial number tracking ready');
    }

    // Add business-specific features
    switch (widget.templateFamily) {
      case TemplateFamily.foodService:
        _checklistItems.add('✓ Table Management enabled');
        _checklistItems.add('✓ Kitchen Orders ready');
        break;
      case TemplateFamily.serviceJob:
        _checklistItems.add('✓ Service Billing setup');
        break;
      case TemplateFamily.bookingBased:
        _checklistItems.add('✓ Booking Calendar ready');
        break;
      case TemplateFamily.manufacturing:
        _checklistItems.add('✓ Bill of Materials enabled');
        break;
      default:
        break;
    }
  }

  void _setupAnimations() {
    _controller = AnimationController(
      duration: Duration(milliseconds: 100 * _checklistItems.length + 500),
      vsync: this,
    );

    _itemAnimations = List.generate(
      _checklistItems.length,
      (index) => Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            index * 0.1,
            (index * 0.1) + 0.3,
            curve: Curves.easeOutBack,
          ),
        ),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _animationComplete = true);
        // Auto-continue after 1 second
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) widget.onComplete();
        });
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header with business icon
            Expanded(
              flex: 2,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        widget.businessIcon,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.l),
                    Text(
                      'Setting up your',
                      style: AppTypography.bodyLarge(context)
                          .copyWith(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    Text(
                      widget.businessTypeLabel,
                      style: AppTypography.headlineMedium(context)
                          .copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            // Animated checklist
            Expanded(
              flex: 3,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.l,
                ),
                itemCount: _checklistItems.length,
                itemBuilder: (context, index) {
                  return ScaleTransition(
                    scale: _itemAnimations[index],
                    child: FadeTransition(
                      opacity: _itemAnimations[index],
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.m),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.m),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            border: Border.all(
                              color: Colors.green.shade200,
                              width: 1.5,
                            ),
                            borderRadius: AppRadius.medium,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green.shade600,
                                size: 24,
                              ),
                              const SizedBox(width: AppSpacing.m),
                              Expanded(
                                child: Text(
                                  _checklistItems[index],
                                  style: AppTypography.bodyMedium(context)
                                      .copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Continue button (visible after animation)
            if (_animationComplete)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: FilledButton.icon(
                  onPressed: widget.onComplete,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Continue Setup'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: SizedBox(
                  height: 48,
                  child: Center(
                    child: Text(
                      'Setting up your business...',
                      style: AppTypography.bodyMedium(context)
                          .copyWith(color: Colors.grey.shade500),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
