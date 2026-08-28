import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/database/db_helper.dart';
import '../../core/bank_reconciliation/models/bank_reconciliation_models.dart';
import '../../core/bank_reconciliation/services/bank_statement_parser.dart';
import '../../core/bank_reconciliation/services/bank_transaction_matcher.dart';
import '../../core/bank_reconciliation/services/bank_reconciliation_executor.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_empty_state.dart';

class BankStatementImportScreen extends StatefulWidget {
  final int companyId;
  final int? initialBankAccountId;

  const BankStatementImportScreen({
    super.key,
    required this.companyId,
    this.initialBankAccountId,
  });

  @override
  State<BankStatementImportScreen> createState() => _BankStatementImportScreenState();
}

class _BankStatementImportScreenState extends State<BankStatementImportScreen> {
  int _currentStep = 0;
  List<Map<String, dynamic>> _bankAccounts = [];
  int? _selectedBankAccountId;

  String? _fileName;
  List<ParsedBankStatementRow> _rows = [];
  bool _busy = false;
  String? _errorMessage;

  String _currencyCode = 'PKR';
  String _currencySymbol = 'Rs.';
  Map<String, int>? _resultSummary;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final company = await DBHelper.instance.getCompanyById(widget.companyId);
    if (company != null) {
      _currencyCode = company['currency_code'] as String? ?? 'PKR';
      _currencySymbol = company['currency_symbol'] as String? ?? 'Rs.';
    }

    final db = await DBHelper.instance.database;
    final accounts = await db.query(
      'bank_accounts',
      where: 'company_id = ?',
      whereArgs: [widget.companyId],
    );

    setState(() {
      _bankAccounts = accounts;
      if (accounts.isNotEmpty) {
        _selectedBankAccountId = widget.initialBankAccountId ?? (accounts.first['id'] as int);
      }
    });
  }

  Future<void> _pickAndParseStatement() async {
    if (_selectedBankAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pehle Bank Account Select Karein!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
      );

      final path = result?.files.single.path;
      final name = result?.files.single.name;

      if (path == null) {
        setState(() => _busy = false);
        return;
      }

      _fileName = name;

      final parseResult = await BankStatementParser().parseStatementFile(path);
      List<ParsedBankStatementRow> parsedRows = List<ParsedBankStatementRow>.from(parseResult['rows']);

      // Run Auto-Matching Engine (does NOT modify DB)
      parsedRows = await BankTransactionMatcher.autoMatchTransactions(
        companyId: widget.companyId,
        bankAccountId: _selectedBankAccountId!,
        rows: parsedRows,
      );

      setState(() {
        _rows = parsedRows;
        _busy = false;
        _currentStep = 1; // Advance to Preview Step
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _errorMessage = 'Statement parse karne mein error: $e';
      });
    }
  }

  Future<void> _commitReconciliation() async {
    if (_selectedBankAccountId == null) return;
    setState(() => _busy = true);

    try {
      final res = await BankReconciliationExecutor.commitReconciliation(
        companyId: widget.companyId,
        bankAccountId: _selectedBankAccountId!,
        rows: _rows,
      );

      setState(() {
        _busy = false;
        _resultSummary = res;
        _currentStep = 2; // Advance to Summary Result Step
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _errorMessage = 'Reconciliation commit fail ho gaya: $e';
      });
    }
  }

  void _manualFindTransaction(ParsedBankStatementRow row) async {
    final db = await DBHelper.instance.database;
    final candidates = await db.query(
      'bank_transactions',
      where: 'company_id = ? AND bank_account_id = ? AND (is_reconciled = 0 OR is_reconciled IS NULL)',
      whereArgs: [widget.companyId, _selectedBankAccountId],
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Matching Transaction Select Karein'),
        content: SizedBox(
          width: double.maxFinite,
          child: candidates.isEmpty
              ? const Text('Koi unreconciled candidate transaction nahi mila.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  itemBuilder: (c, i) {
                    final cand = candidates[i];
                    final amt = (cand['amount'] as num).toDouble();
                    return ListTile(
                      title: Text(cand['description'] as String? ?? 'Transaction'),
                      subtitle: Text('Date: ${cand['transaction_date']} • Amount: Rs. ${amt.toStringAsFixed(0)}'),
                      onTap: () {
                        setState(() {
                          row.matchedTransaction = cand;
                          row.status = ParsedRowStatus.manualMatch;
                          row.confidence = MatchConfidence.high;
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bank Statement Auto-Reconciliation')),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0) {
            _pickAndParseStatement();
          } else if (_currentStep == 1) {
            _commitReconciliation();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep--);
          }
        },
        steps: [
          _buildFileSelectionStep(),
          _buildPreviewStep(),
          _buildResultStep(),
        ],
      ),
    );
  }

  Step _buildFileSelectionStep() {
    return Step(
      title: const Text('1. Bank Account & Statement File'),
      subtitle: Text(_fileName ?? 'No file selected'),
      isActive: _currentStep >= 0,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Target Bank Account Select Karein:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _selectedBankAccountId,
            decoration: const InputDecoration(labelText: 'Bank Account'),
            items: _bankAccounts
                .map((b) => DropdownMenuItem<int>(
                      value: b['id'] as int,
                      child: Text('${b['account_name']} (${b['bank_name'] ?? ""})'),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedBankAccountId = v),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _busy ? null : _pickAndParseStatement,
            icon: _busy
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.upload_file),
            label: Text(_fileName != null ? 'Change File ($_fileName)' : 'Bank Statement File Select Karein'),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }

  Step _buildPreviewStep() {
    final autoMatched = _rows.where((r) => r.status == ParsedRowStatus.autoMatched).toList();
    final manualMatched = _rows.where((r) => r.status == ParsedRowStatus.manualMatch).toList();
    final newCreated = _rows.where((r) => r.status == ParsedRowStatus.newTransaction).toList();
    final unmatched = _rows.where((r) => r.status == ParsedRowStatus.unmatched).toList();

    return Step(
      title: const Text('2. Reconciliation Preview'),
      subtitle: Text('${_rows.length} rows parsed'),
      isActive: _currentStep >= 1,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildMetricCard('Auto Matched', '${autoMatched.length}', Colors.green),
              _buildMetricCard('Manual Review', '${manualMatched.length}', Colors.orange),
              _buildMetricCard('New to Create', '${newCreated.length}', Colors.blue),
              _buildMetricCard('Unmatched', '${unmatched.length}', Colors.grey),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Statement Rows Review:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          SizedBox(
            height: 350,
            child: ListView.builder(
              itemCount: _rows.length,
              itemBuilder: (ctx, i) {
                final r = _rows[i];
                final formattedAmt = CurrencyFormatter.format(
                  r.amount,
                  currencyCode: _currencyCode,
                  symbol: _currencySymbol,
                );

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: r.status == ParsedRowStatus.autoMatched
                          ? Colors.green.shade50
                          : (r.status == ParsedRowStatus.manualMatch ? Colors.orange.shade50 : Colors.grey.shade100),
                      child: Icon(
                        r.status == ParsedRowStatus.autoMatched ? Icons.check_circle : Icons.help_outline,
                        color: r.status == ParsedRowStatus.autoMatched ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                    ),
                    title: Text(r.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Date: ${r.dateStr} • Status: ${r.status.displayName}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(formattedAmt, style: TextStyle(fontWeight: FontWeight.bold, color: r.amount >= 0 ? Colors.green : Colors.red)),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'find') {
                              _manualFindTransaction(r);
                            } else if (val == 'create') {
                              setState(() => r.status = ParsedRowStatus.newTransaction);
                            } else if (val == 'skip') {
                              setState(() => r.status = ParsedRowStatus.unmatched);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'find', child: Text('Find Existing Match')),
                            const PopupMenuItem(value: 'create', child: Text('Create as New Transaction')),
                            const PopupMenuItem(value: 'skip', child: Text('Skip')),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Step _buildResultStep() {
    final s = _resultSummary;
    return Step(
      title: const Text('3. Reconciliation Applied'),
      isActive: _currentStep >= 2,
      content: s == null
          ? const SizedBox()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 32),
                    SizedBox(width: 8),
                    Text('Bank Statement Reconciled!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildSummaryRow('Auto Matched Reconciled', '${s['autoMatched']}', Colors.green),
                        _buildSummaryRow('Manually Reconciled', '${s['manualMatched']}', Colors.orange),
                        _buildSummaryRow('New Transactions Created', '${s['newCreated']}', Colors.blue),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Done'),
                ),
              ],
            ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        color: color.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Column(
            children: [
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
              Text(title, style: TextStyle(fontSize: 10, color: color), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String title, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        ],
      ),
    );
  }
}
