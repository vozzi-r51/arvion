/// Represents a business dimension like Branch, Department, Store, Warehouse.
/// Every transaction can be tagged with a cost center for reporting/analysis.
class CostCenter {
  final int id;
  final int companyId;
  final String code; // "BR-001", "DEPT-SALES", "WH-MAIN"
  final String name; // "Karachi Branch", "Sales Department"
  final String type; // 'branch' | 'department' | 'warehouse' | 'store'
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  CostCenter({
    required this.id,
    required this.companyId,
    required this.code,
    required this.name,
    required this.type,
    this.description,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'company_id': companyId,
        'code': code,
        'name': name,
        'type': type,
        'description': description,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory CostCenter.fromMap(Map<String, dynamic> map) => CostCenter(
        id: map['id'] as int,
        companyId: map['company_id'] as int,
        code: map['code'] as String,
        name: map['name'] as String,
        type: map['type'] as String,
        description: map['description'] as String?,
        isActive: (map['is_active'] as int?) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
