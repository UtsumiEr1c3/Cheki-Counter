class Idol {
  final int? id;
  final String name;
  final String color;
  final String groupName;
  final String createdAt;

  // Aggregate fields from JOIN queries
  final int totalCount;
  final int totalAmount;

  Idol({
    this.id,
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
      'name': name,
      'color': color,
      'group_name': groupName,
      'created_at': createdAt,
    };
  }

  factory Idol.fromMap(Map<String, dynamic> map) {
    return Idol(
      id: map['id'] as int?,
      name: map['name'] as String,
      color: map['color'] as String,
      groupName: map['group_name'] as String,
      createdAt: map['created_at'] as String,
      totalCount: map['total_count'] as int? ?? 0,
      totalAmount: map['total_amount'] as int? ?? 0,
    );
  }
}
