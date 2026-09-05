import 'dart:math';

class CheckiEvent {
  final int? id;
  final String stableId;
  final String name;
  final String venue;
  final String date;
  final String createdAt;
  final int ticketPrice;
  final bool isOnline;

  CheckiEvent({
    this.id,
    this.stableId = '',
    required this.name,
    required this.venue,
    required this.date,
    required this.createdAt,
    this.ticketPrice = 0,
    this.isOnline = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'stable_id': stableId,
      'name': name,
      'venue': venue,
      'date': date,
      'created_at': createdAt,
      'ticket_price': ticketPrice,
      'is_online': isOnline ? 1 : 0,
    };
  }

  factory CheckiEvent.fromMap(Map<String, dynamic> map) {
    return CheckiEvent(
      id: map['id'] as int?,
      stableId: map['stable_id'] as String? ?? '',
      name: map['name'] as String,
      venue: map['venue'] as String,
      date: map['date'] as String,
      createdAt: map['created_at'] as String,
      ticketPrice: (map['ticket_price'] as num?)?.toInt() ?? 0,
      isOnline: (map['is_online'] as int?) == 1,
    );
  }
}

String generateEventStableId() {
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final suffix = Random.secure().nextInt(0x7fffffff).toRadixString(16);
  return 'event_${timestamp}_$suffix';
}
