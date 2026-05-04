import 'package:sqflite/sqflite.dart';
import 'package:cheki_counter/data/db.dart';
import 'package:cheki_counter/data/models/event.dart';

class EventWithSummary {
  final CheckiEvent event;
  final int totalCount;
  final int totalAmount;
  final int recordCount;
  final List<IdolSummaryEntry> idolSummary;
  final int ticketPrice;

  EventWithSummary({
    required this.event,
    required this.totalCount,
    required this.totalAmount,
    required this.recordCount,
    required this.idolSummary,
    required this.ticketPrice,
  });

  bool get hasRecords => recordCount > 0;
  int get grandAmount => ticketPrice + totalAmount;
}

class IdolSummaryEntry {
  final String name;
  final String color;
  final int count;

  IdolSummaryEntry({
    required this.name,
    required this.color,
    required this.count,
  });
}

class EventRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<int> upsertByTriple(
    String name,
    String venue,
    String date,
    String createdAt, {
    int ticketPrice = 0,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _db;
    final existing = await db.query(
      'events',
      columns: ['id', 'ticket_price'],
      where: 'name = ? AND venue = ? AND date = ?',
      whereArgs: [name, venue, date],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final row = existing.first;
      final id = row['id'] as int;
      final existingTicketPrice = (row['ticket_price'] as num?)?.toInt() ?? 0;
      if (existingTicketPrice == 0 && ticketPrice > 0) {
        await db.update(
          'events',
          {'ticket_price': ticketPrice},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      return id;
    }
    return await db.insert('events', {
      'name': name,
      'venue': venue,
      'date': date,
      'created_at': createdAt,
      'ticket_price': ticketPrice,
    });
  }

  Future<List<CheckiEvent>> getAll() async {
    final db = await _db;
    final rows = await db.query('events', orderBy: 'date DESC, id DESC');
    return rows.map((r) => CheckiEvent.fromMap(r)).toList();
  }

  Future<CheckiEvent?> getById(int id) async {
    final db = await _db;
    final rows = await db.query(
      'events',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CheckiEvent.fromMap(rows.first);
  }

  Future<List<String>> getDistinctYears() async {
    final db = await _db;
    final rows = await db.rawQuery(
      "SELECT DISTINCT strftime('%Y', date) AS year FROM events ORDER BY year DESC",
    );
    return rows.map((r) => r['year'] as String).toList();
  }

  Future<List<EventWithSummary>> getAllWithRecordsSummary({
    String? year,
  }) async {
    final db = await _db;

    final conditions = <String>[
      "NOT EXISTS (SELECT 1 FROM records WHERE event_id = e.id AND is_online = 1)",
    ];
    final args = <Object?>[];
    if (year != null) {
      conditions.add("strftime('%Y', e.date) = ?");
      args.add(year);
    }
    final whereClause = 'WHERE ${conditions.join(' AND ')}';

    final eventRows = await db.rawQuery('''
      SELECT e.id, e.name, e.venue, e.date, e.created_at,
             e.ticket_price,
             COALESCE(SUM(r.count), 0) AS total_count,
             COALESCE(SUM(r.subtotal), 0) AS total_amount,
             COUNT(r.id) AS record_count
      FROM events e
      LEFT JOIN records r ON r.event_id = e.id AND r.is_online = 0
      $whereClause
      GROUP BY e.id
      ORDER BY e.date DESC, e.id DESC
    ''', args);

    if (eventRows.isEmpty) return [];

    final ids = eventRows.map((r) => r['id'] as int).toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final idolRows = await db.rawQuery('''
      SELECT r.event_id, i.name, i.color, SUM(r.count) AS cnt
      FROM records r
      JOIN idols i ON i.id = r.idol_id
      WHERE r.event_id IN ($placeholders) AND r.is_online = 0
      GROUP BY r.event_id, i.id
      ORDER BY cnt DESC, i.name ASC
    ''', ids);

    final byEvent = <int, List<IdolSummaryEntry>>{};
    for (final row in idolRows) {
      final eid = row['event_id'] as int;
      byEvent
          .putIfAbsent(eid, () => [])
          .add(
            IdolSummaryEntry(
              name: row['name'] as String,
              color: row['color'] as String,
              count: (row['cnt'] as num).toInt(),
            ),
          );
    }

    return eventRows.map((r) {
      final id = r['id'] as int;
      return EventWithSummary(
        event: CheckiEvent.fromMap(r),
        totalCount: (r['total_count'] as num).toInt(),
        totalAmount: (r['total_amount'] as num).toInt(),
        recordCount: (r['record_count'] as num).toInt(),
        idolSummary: byEvent[id] ?? const [],
        ticketPrice: (r['ticket_price'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }
}
