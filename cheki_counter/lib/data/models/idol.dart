class Idol {
  final int? id;
  final String stableId;
  final String name;
  final String color;
  final String groupName;
  final String createdAt;

  // Aggregate fields from JOIN queries
  final int totalCount;
  final int totalAmount;

  Idol({
    this.id,
    this.stableId = '',
    required this.name,
    required this.color,
    required this.groupName,
    required this.createdAt,
    this.totalCount = 0,
    this.totalAmount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (stableId.isNotEmpty) 'stable_id': stableId,
      'name': name,
      'color': color,
      'group_name': groupName,
      'created_at': createdAt,
    };
  }

  factory Idol.fromMap(Map<String, dynamic> map) {
    return Idol(
      id: map['id'] as int?,
      stableId: map['stable_id'] as String? ?? '',
      name: map['name'] as String,
      color: map['color'] as String,
      groupName: map['group_name'] as String,
      createdAt: map['created_at'] as String,
      totalCount: map['total_count'] as int? ?? 0,
      totalAmount: map['total_amount'] as int? ?? 0,
    );
  }

  Idol copyWith({
    int? id,
    String? stableId,
    String? name,
    String? color,
    String? groupName,
    String? createdAt,
    int? totalCount,
    int? totalAmount,
  }) {
    return Idol(
      id: id ?? this.id,
      stableId: stableId ?? this.stableId,
      name: name ?? this.name,
      color: color ?? this.color,
      groupName: groupName ?? this.groupName,
      createdAt: createdAt ?? this.createdAt,
      totalCount: totalCount ?? this.totalCount,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }
}
