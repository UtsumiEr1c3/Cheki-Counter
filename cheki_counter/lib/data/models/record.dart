class CheckiRecord {
  final int? id;
  final int idolId;
  final String date;
  final int count;
  final int unitPrice;
  final int subtotal;
  final String venue;
  final String createdAt;
  final int? eventId;

  CheckiRecord({
    this.id,
    required this.idolId,
    required this.date,
    required this.count,
    required this.unitPrice,
    required this.subtotal,
    required this.venue,
    required this.createdAt,
    this.eventId,
  });

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
    };
  }

  factory CheckiRecord.fromMap(Map<String, dynamic> map) {
    return CheckiRecord(
      id: map['id'] as int?,
      idolId: map['idol_id'] as int,
      date: map['date'] as String,
      count: map['count'] as int,
      unitPrice: map['unit_price'] as int,
      subtotal: map['subtotal'] as int,
      venue: map['venue'] as String,
      createdAt: map['created_at'] as String,
      eventId: map['event_id'] as int?,
    );
  }
}
