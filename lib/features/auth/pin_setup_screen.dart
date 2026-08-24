import 'package:flutter/material.dart';
import '../../core/auth/auth_service.dart';
import '../company/company_selection_screen.dart';
import '../../core/auth/session.dart';

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

    await AuthService.instance.setPin(pin, question: _selectedQuestion, answer: answer);
    Session.setOwner();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CompanySelectionScreen()),
    );
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
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Icon(Icons.lock_outline,
                  size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Apni App PIN Banayein',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Ye PIN har baar app kholte waqt use hoga',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Naya PIN',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'PIN Confirm Karein',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 24),
              const Text('Recovery Question (Forgot PIN ke liye)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedQuestion,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: _questions.map((q) => DropdownMenuItem(value: q, child: Text(q, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _selectedQuestion = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _answerController,
                decoration: const InputDecoration(
                  labelText: 'Aapka Jawab',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _savePin,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('PIN Save Karein'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
