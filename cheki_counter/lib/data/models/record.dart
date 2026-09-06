enum ChekiRecordType {
  normal('normal', '普通切'),
  theme('theme', '主题切'),
  group('group', '团切');

  final String value;
  final String label;

  const ChekiRecordType(this.value, this.label);

  static ChekiRecordType fromValue(Object? value) {
    return ChekiRecordType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ChekiRecordType.normal,
    );
  }

  static ChekiRecordType fromCsv(String value) {
    return switch (value.trim()) {
      '主题切' || 'theme' => ChekiRecordType.theme,
      '团切' || 'group' => ChekiRecordType.group,
      _ => ChekiRecordType.normal,
    };
  }
}

class CheckiRecord {
  final int? id;
  final int? idolId;
  final String date;
  final int count;
  final int unitPrice;
  final int subtotal;
  final String venue;
  final String createdAt;
  final int? eventId;
  final bool isOnline;
  final ChekiRecordType recordType;
  final String? specialName;
  final String? groupName;
  final List<String> groupNames;
  final String? groupMembers;

  CheckiRecord({
    this.id,
    this.idolId,
    required this.date,
    required this.count,
    required this.unitPrice,
    required this.subtotal,
    required this.venue,
    required this.createdAt,
    this.eventId,
    this.isOnline = false,
    this.recordType = ChekiRecordType.normal,
    this.specialName,
    this.groupName,
    this.groupNames = const [],
    this.groupMembers,
  });

  List<String> get effectiveGroupNames {
    if (groupNames.isNotEmpty) return groupNames;
    final fallback = groupName?.trim() ?? '';
    return fallback.isEmpty ? const [] : [fallback];
  }

  String? get groupDisplayName {
    final names = effectiveGroupNames;
    return names.isEmpty ? null : names.join(' / ');
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'idol_id': idolId,
      'date': date,
      'count': count,
      'unit_price': unitPrice,
      'subtotal': subtotal,
      'venue': venue,
      'created_at': createdAt,
      'event_id': eventId,
      'is_online': isOnline ? 1 : 0,
      'record_type': recordType.value,
      'special_name': specialName,
      'group_name': groupName,
      'group_members': groupMembers,
    };
  }

  factory CheckiRecord.fromMap(Map<String, dynamic> map) {
    return CheckiRecord(
      id: map['id'] as int?,
      idolId: map['idol_id'] as int?,
      date: map['date'] as String,
      count: map['count'] as int,
      unitPrice: map['unit_price'] as int,
      subtotal: map['subtotal'] as int,
      venue: map['venue'] as String,
      createdAt: map['created_at'] as String,
      eventId: map['event_id'] as int?,
      isOnline: (map['is_online'] as int?) == 1,
      recordType: ChekiRecordType.fromValue(map['record_type']),
      specialName: map['special_name'] as String?,
      groupName: map['group_name'] as String?,
      groupNames: _parseGroupNames(map['group_names']),
      groupMembers: map['group_members'] as String?,
    );
  }

  static List<String> _parseGroupNames(Object? value) {
    if (value is! String || value.isEmpty) return const [];
    return value
        .split('\u001f')
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }
}
