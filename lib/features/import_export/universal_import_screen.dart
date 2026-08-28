import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/import/models/import_models.dart';
import '../../core/import/services/smart_column_mapper.dart';
import '../../core/import/services/import_validator.dart';
import '../../core/import/services/duplicate_detector.dart';
import '../../core/import/services/import_executor.dart';
import '../../core/import/parsers/quickbooks_import_parser.dart';
import '../../core/import/parsers/tally_import_parser.dart';
import '../../core/import/parsers/vyapar_import_parser.dart';
import '../../core/import/parsers/generic_csv_excel_parser.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_empty_state.dart';

class UniversalImportScreen extends StatefulWidget {
  final int companyId;
  final ImportEntityType? initialEntityType;

  const UniversalImportScreen({
    super.key,
    required this.companyId,
    this.initialEntityType,
  });

  @override
  State<UniversalImportScreen> createState() => _UniversalImportScreenState();
}

class _UniversalImportScreenState extends State<UniversalImportScreen> {
  int _currentStep = 0;
  ImportSource _selectedSource = ImportSource.quickbooks;
  late ImportEntityType _selectedEntityType;

  String? _filePath;
  String? _fileName;
  List<String> _headers = [];
  List<ColumnMapping> _mappings = [];
  List<ParsedRow> _parsedRows = [];

  DuplicatePolicy _duplicatePolicy = DuplicatePolicy.skip;
  bool _busy = false;
  String? _errorMessage;
  ImportSummary? _summary;

  @override
  void initState() {
    super.initState();
    _selectedEntityType = widget.initialEntityType ?? ImportEntityType.products;
  }

  Future<void> _pickAndParseFile() async {
    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls', 'xml'],
      );

      final path = result?.files.single.path;
      final name = result?.files.single.name;

      if (path == null) {
        setState(() => _busy = false);
        return;
      }

      _filePath = path;
      _fileName = name;

      Map<String, dynamic> parseResult;
      switch (_selectedSource) {
        case ImportSource.quickbooks:
          parseResult = await QuickBooksImportParser().parseFile(
            filePath: path,
            entityType: _selectedEntityType,
          );
          break;
        case ImportSource.tally:
          parseResult = await TallyImportParser().parseFile(
            filePath: path,
            entityType: _selectedEntityType,
          );
          break;
        case ImportSource.vyapar:
          parseResult = await VyaparImportParser().parseFile(
            filePath: path,
            entityType: _selectedEntityType,
          );
          break;
        case ImportSource.generic:
          final gen = await GenericCsvExcelParser().parseFile(path);
          final hdrs = List<String>.from(gen['headers']);
          final maps = SmartColumnMapper.mapColumns(
            headers: hdrs,
            entityType: _selectedEntityType,
            source: ImportSource.generic,
          );
          parseResult = {
            'headers': hdrs,
            'mappings': maps,
            'rows': gen['rows'],
          };
          break;
      }

      _headers = List<String>.from(parseResult['headers']);
      _mappings = List<ColumnMapping>.from(parseResult['mappings']);
      final List<Map<String, String>> rawRows = List<Map<String, String>>.from(parseResult['rows']);

      // Build parsed rows & run validation
      List<ParsedRow> rows = [];
      for (int i = 0; i < rawRows.length; i++) {
        var row = ParsedRow(rowIndex: i + 1, rawData: rawRows[i]);
        row = ImportValidator.validateAndExtractRow(
          row: row,
          mappings: _mappings,
          entityType: _selectedEntityType,
        );
        rows.add(row);
      }

      // Run duplicate detection against existing DB records
      rows = await DuplicateDetector.detectDuplicates(
        companyId: widget.companyId,
        rows: rows,
        entityType: _selectedEntityType,
      );

      setState(() {
        _parsedRows = rows;
        _busy = false;
        _currentStep = 3; // Advance to Mapping & Preview Step
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _errorMessage = 'File parse karne mein error: $e';
      });
    }
  }

  Future<void> _executeImport() async {
    setState(() => _busy = true);

    final summary = await ImportExecutor.executeImport(
      companyId: widget.companyId,
      rows: _parsedRows,
      entityType: _selectedEntityType,
      duplicatePolicy: _duplicatePolicy,
      sourceName: _selectedSource.displayName,
    );

    setState(() {
      _busy = false;
      _summary = summary;
      _currentStep = 4; // Advance to Summary Result Step
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Universal Data Import (Zero Switching Cost)')),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0) {
            setState(() => _currentStep = 1);
          } else if (_currentStep == 1) {
            setState(() => _currentStep = 2);
          } else if (_currentStep == 2) {
            _pickAndParseFile();
          } else if (_currentStep == 3) {
            _executeImport();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep--);
          }
        },
        steps: [
          _buildSourceStep(),
          _buildEntityStep(),
          _buildFileStep(),
          _buildPreviewMappingStep(),
          _buildSummaryStep(),
        ],
      ),
    );
  }

  Step _buildSourceStep() {
    return Step(
      title: const Text('1. Source Selection'),
      subtitle: Text(_selectedSource.displayName),
      isActive: _currentStep >= 0,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Aap kahan se data la rahe hain?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ...ImportSource.values.map((s) => RadioListTile<ImportSource>(
                title: Text(s.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(s.instructions, style: const TextStyle(fontSize: 12)),
                value: s,
                groupValue: _selectedSource,
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSource = val);
                },
              )),
        ],
      ),
    );
  }

  Step _buildEntityStep() {
    return Step(
      title: const Text('2. Data Type Selection'),
      subtitle: Text(_selectedEntityType.displayName),
      isActive: _currentStep >= 1,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kangi kis qisam ka data import karna chahte hain?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ...ImportEntityType.values.map((e) => RadioListTile<ImportEntityType>(
                title: Text(e.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                value: e,
                groupValue: _selectedEntityType,
                onChanged: (val) {
                  if (val != null) setState(() => _selectedEntityType = val);
                },
              )),
        ],
      ),
    );
  }

  Step _buildFileStep() {
    return Step(
      title: const Text('3. File Selection'),
      subtitle: Text(_fileName ?? 'No file selected'),
      isActive: _currentStep >= 2,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Selected Source: ${_selectedSource.displayName}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('Selected Entity: ${_selectedEntityType.displayName}'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _busy ? null : _pickAndParseFile,
            icon: _busy
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.upload_file),
            label: Text(_fileName != null ? 'Change File ($_fileName)' : 'CSV / Excel File Pick Karein'),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }

  Step _buildPreviewMappingStep() {
    final validRows = _parsedRows.where((r) => r.isValid).toList();
    final invalidRows = _parsedRows.where((r) => !r.isValid).toList();
    final duplicateRows = validRows.where((r) => r.isDuplicate).toList();

    return Step(
      title: const Text('4. Smart Mapping & Preview'),
      subtitle: Text('${_parsedRows.length} Rows Detected'),
      isActive: _currentStep >= 3,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Metric Summary
          Row(
            children: [
              _buildMetricCard('Total Rows', '${_parsedRows.length}', Colors.blue),
              _buildMetricCard('Valid', '${validRows.length}', Colors.green),
              _buildMetricCard('Invalid', '${invalidRows.length}', Colors.red),
              _buildMetricCard('Duplicates', '${duplicateRows.length}', Colors.orange),
            ],
          ),
          const SizedBox(height: 16),

          // Duplicate Policy Choice
          if (duplicateRows.isNotEmpty) ...[
            const Text('Duplicate Action', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<DuplicatePolicy>(
              value: _duplicatePolicy,
              items: DuplicatePolicy.values
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.displayName)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _duplicatePolicy = v);
              },
            ),
            const SizedBox(height: 16),
          ],

          // Column Mapping Badges
          const Text('Smart Column Mappings:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _mappings.map((m) {
              return Chip(
                avatar: Icon(m.confidence == ImportConfidence.high ? Icons.check_circle : Icons.auto_fix_high, size: 16),
                label: Text('${m.sourceHeader} ➔ ${m.targetField ?? "Unmapped"}'),
                backgroundColor: m.confidence == ImportConfidence.high ? Colors.green.shade50 : Colors.amber.shade50,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Invalid Rows Warning List
          if (invalidRows.isNotEmpty) ...[
            Text('⚠️ ${invalidRows.length} rows invalid hain aur skip hon gi:', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 6),
            ...invalidRows.take(5).map((r) => Text('Row ${r.rowIndex}: ${r.validationErrors.join(", ")}', style: const TextStyle(fontSize: 12, color: Colors.red))),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Step _buildSummaryStep() {
    final s = _summary;
    return Step(
      title: const Text('5. Import Result'),
      isActive: _currentStep >= 4,
      content: s == null
          ? const SizedBox()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 32),
                    SizedBox(width: 8),
                    Text('Import Complete!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildSummaryRow('Imported Records', '${s.importedCount}', Colors.green),
                        _buildSummaryRow('Skipped Records', '${s.skippedCount}', Colors.grey),
                        _buildSummaryRow('Duplicates Found', '${s.duplicateRows}', Colors.orange),
                        _buildSummaryRow('Invalid Records', '${s.invalidRows}', Colors.red),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('No data was lost. Transaction committed safely.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
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
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
              Text(title, style: TextStyle(fontSize: 11, color: color)),
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
