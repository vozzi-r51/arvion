import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../../core/widgets/bizmanager_logo.dart';
import '../company/company_selection_screen.dart';
import '../../core/auth/session.dart';
import '../../core/theme/design_tokens.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  final _answerController = TextEditingController();
  String _selectedQuestion = 'Aapka pehla school konsa tha?';
  String? _error;
  bool _saving = false;

  final List<String> _questions = [
    'Aapka pehla school konsa tha?',
    'Aapki paidaish kis shehar mein hui?',
    'Aapka pasandida khana konsa hai?',
    'Aapke bachpan ka sab se acha dost?',
  ];

  @override
  void initState() {
    super.initState();
    if (!_questions.contains(_selectedQuestion)) {
      _selectedQuestion = _questions.first;
    }
  }

  Future<void> _savePin() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();
    final answer = _answerController.text.trim();

    if (pin.length < 4) {
      setState(() => _error = 'PIN kam se kam 4 digit ka hona chahiye');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'Dono PIN match nahi kar rahe');
      return;
    }
    if (answer.isEmpty) {
      setState(() => _error = 'Security Jawab zaroori hai recovery ke liye');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await AuthService.instance
          .setPin(pin, question: _selectedQuestion, answer: answer);
      if (!mounted) return;
      Session.setOwner();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CompanySelectionScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'PIN save nahi ho saka. Dobara koshish karein.';
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A), // Navy
              Color(0xFF1E3A8A), // Deep Blue
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.l),
                    const Center(
                        child: BizManagerLogo(size: 80, showBackground: false)),
                    const SizedBox(height: AppSpacing.m),
                    const Text(
                      'BizManager',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Smart Business. Simple Control.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Card(
                      elevation: AppElevation.medium,
                      margin: EdgeInsets.zero,
                      shape:
                          RoundedRectangleBorder(borderRadius: AppRadius.large),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Sign up',
                              style: AppTypography.titleLarge(context)
                                  .copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Apna PIN banayein. Ye har baar app kholte waqt use hoga.',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            TextField(
                              controller: _pinController,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              maxLength: 6,
                              style: AppTypography.headlineMedium(context)
                                  .copyWith(letterSpacing: 8),
                              decoration: const InputDecoration(
                                labelText: 'Naya PIN (4-6 digits)',
                                counterText: '',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.m),
                            TextField(
                              controller: _confirmController,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              maxLength: 6,
                              style: AppTypography.headlineMedium(context)
                                  .copyWith(letterSpacing: 8),
                              decoration: const InputDecoration(
                                labelText: 'PIN Confirm Karein',
                                counterText: '',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.l),
                            const Divider(height: 1),
                            const SizedBox(height: AppSpacing.l),
                            Text(
                              'Recovery Question',
                              style: AppTypography.titleSmall(context)
                                  .copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Forgot PIN ke liye ye sawal jawab zaroori hai.',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.m),
                            DropdownButtonFormField<String>(
                              value: _selectedQuestion,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Sawal chunein',
                              ),
                              items: _questions
                                  .map((q) => DropdownMenuItem(
                                      value: q,
                                      child: Text(q,
                                          style:
                                              const TextStyle(fontSize: 13))))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _selectedQuestion = v);
                                }
                              },
                            ),
                            const SizedBox(height: AppSpacing.m),
                            TextField(
                              controller: _answerController,
                              decoration: const InputDecoration(
                                labelText: 'Aapka Jawab',
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: AppSpacing.m),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.xl),
                            SizedBox(
                              height: 64,
                              child: FilledButton(
                                onPressed: _saving ? null : _savePin,
                                child: _saving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Text(
                                        'Create Account',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const Text(
                      'Developed by BizManager Technologies',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
