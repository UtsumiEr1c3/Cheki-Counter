class CheckiEvent {
  final int? id;
  final String name;
  final String venue;
  final String date;
  final String createdAt;
  final int ticketPrice;

  CheckiEvent({
    this.id,
    required this.name,
    required this.venue,
    required this.date,
    required this.createdAt,
    this.ticketPrice = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'venue': venue,
      'date': date,
      'created_at': createdAt,
      'ticket_price': ticketPrice,
    };
  }

  factory CheckiEvent.fromMap(Map<String, dynamic> map) {
    return CheckiEvent(
      id: map['id'] as int?,
      name: map['name'] as String,
      venue: map['venue'] as String,
      date: map['date'] as String,
      createdAt: map['created_at'] as String,
      ticketPrice: (map['ticket_price'] as num?)?.toInt() ?? 0,
    );
  }
}
