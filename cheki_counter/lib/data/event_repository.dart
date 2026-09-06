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
  final int colorValue;
  final int count;
  final bool isGroup;

  IdolSummaryEntry({
    required this.name,
    required this.color,
    required this.colorValue,
    required this.count,
    this.isGroup = false,
  });
}

class EventSpendingSummary {
  final int allChekiAmount;
  final int onsiteChekiAmount;
  final int onlineChekiAmount;
  final int onsiteTicketAmount;
  final int onsiteEventCount;
  final int normalChekiAmount;
  final int themeChekiAmount;
  final int groupChekiAmount;

  const EventSpendingSummary({
    required this.allChekiAmount,
    required this.onsiteChekiAmount,
    required this.onlineChekiAmount,
    required this.onsiteTicketAmount,
    required this.onsiteEventCount,
    required this.normalChekiAmount,
    required this.themeChekiAmount,
    required this.groupChekiAmount,
  });

  int get totalSpending => allChekiAmount + onsiteTicketAmount;
}

class EventAlreadyExistsException implements Exception {}

class EventRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<int> upsertByTriple(
    String name,
    String venue,
    String date,
    String createdAt, {
    int ticketPrice = 0,
    bool isOnline = false,
    String? stableId,
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
      'stable_id': stableId?.trim().isNotEmpty == true
          ? stableId!.trim()
          : generateEventStableId(),
      'name': name,
      'venue': venue,
      'date': date,
      'created_at': createdAt,
      'ticket_price': ticketPrice,
      'is_online': isOnline ? 1 : 0,
    });
  }

  Future<CheckiEvent?> getByStableId(String stableId) async {
    final db = await _db;
    final rows = await db.query(
      'events',
      where: 'stable_id = ?',
      whereArgs: [stableId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CheckiEvent.fromMap(rows.first);
  }

  Future<void> update(CheckiEvent original, CheckiEvent updated) async {
    final id = original.id;
    if (id == null) throw ArgumentError('活动 ID 不能为空');
    final db = await _db;
    await db.transaction((txn) async {
      final duplicate = await txn.query(
        'events',
        columns: ['id'],
        where: 'name = ? AND venue = ? AND date = ? AND id != ?',
        whereArgs: [updated.name, updated.venue, updated.date, id],
        limit: 1,
      );
      if (duplicate.isNotEmpty) throw EventAlreadyExistsException();

      await txn.update(
        'events',
        {
          'name': updated.name,
          'venue': updated.venue,
          'date': updated.date,
          'ticket_price': updated.ticketPrice,
          'is_online': updated.isOnline ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      if (original.date != updated.date) {
        await txn.update(
          'records',
          {'date': updated.date},
          where: 'event_id = ? AND date = ?',
          whereArgs: [id, original.date],
        );
      }
      if (original.venue != updated.venue) {
        await txn.update(
          'records',
          {'venue': updated.venue},
          where: 'event_id = ? AND venue = ?',
          whereArgs: [id, original.venue],
        );
      }
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

  Future<List<String>> getSpendingYears() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT year FROM (
        SELECT strftime('%Y', date) AS year FROM events
        UNION
        SELECT strftime('%Y', date) AS year FROM records
      )
      WHERE year IS NOT NULL
      ORDER BY year DESC
    ''');
    return rows.map((r) => r['year'] as String).toList();
  }

  Future<EventSpendingSummary> getSpendingSummary({String? year}) async {
    final db = await _db;
    final recordWhere = year == null ? '' : "WHERE strftime('%Y', date) = ?";
    final recordArgs = year == null ? <Object?>[] : <Object?>[year];
    final recordRows = await db.rawQuery('''
      SELECT COALESCE(SUM(subtotal), 0) AS all_cheki,
             COALESCE(SUM(CASE WHEN is_online = 0 THEN subtotal ELSE 0 END), 0)
               AS onsite_cheki,
             COALESCE(SUM(CASE WHEN is_online = 1 THEN subtotal ELSE 0 END), 0)
               AS online_cheki,
             COALESCE(SUM(CASE WHEN record_type = 'normal' THEN subtotal ELSE 0 END), 0)
               AS normal_cheki,
             COALESCE(SUM(CASE WHEN record_type = 'theme' THEN subtotal ELSE 0 END), 0)
               AS theme_cheki,
             COALESCE(SUM(CASE WHEN record_type = 'group' THEN subtotal ELSE 0 END), 0)
               AS group_cheki
      FROM records
      $recordWhere
    ''', recordArgs);

    final eventConditions = <String>['is_online = 0'];
    final eventArgs = <Object?>[];
    if (year != null) {
      eventConditions.add("strftime('%Y', date) = ?");
      eventArgs.add(year);
    }
    final eventRows = await db.rawQuery('''
      SELECT COALESCE(SUM(ticket_price), 0) AS onsite_tickets,
             COUNT(*) AS onsite_events
      FROM events
      WHERE ${eventConditions.join(' AND ')}
    ''', eventArgs);

    final record = recordRows.single;
    final event = eventRows.single;
    return EventSpendingSummary(
      allChekiAmount: (record['all_cheki'] as num).toInt(),
      onsiteChekiAmount: (record['onsite_cheki'] as num).toInt(),
      onlineChekiAmount: (record['online_cheki'] as num).toInt(),
      onsiteTicketAmount: (event['onsite_tickets'] as num).toInt(),
      onsiteEventCount: (event['onsite_events'] as num).toInt(),
      normalChekiAmount: (record['normal_cheki'] as num).toInt(),
      themeChekiAmount: (record['theme_cheki'] as num).toInt(),
      groupChekiAmount: (record['group_cheki'] as num).toInt(),
    );
  }

  Future<List<EventWithSummary>> getAllWithRecordsSummary({
    String? year,
    bool? isOnline = false,
  }) async {
    final db = await _db;

    final conditions = <String>[];
    final args = <Object?>[];
    if (isOnline != null) {
      conditions.add('e.is_online = ?');
      args.add(isOnline ? 1 : 0);
    }
    if (year != null) {
      conditions.add("strftime('%Y', e.date) = ?");
      args.add(year);
    }
    final whereClause = conditions.isEmpty
        ? ''
        : 'WHERE ${conditions.join(' AND ')}';

    final eventRows = await db.rawQuery('''
      SELECT e.id, e.name, e.venue, e.date, e.created_at,
             e.ticket_price,
             COALESCE(SUM(r.count), 0) AS total_count,
             COALESCE(SUM(r.subtotal), 0) AS total_amount,
             COUNT(r.id) AS record_count
      FROM events e
      LEFT JOIN records r ON r.event_id = e.id AND r.is_online = e.is_online
      $whereClause
      GROUP BY e.id
      ORDER BY e.date DESC, e.id DESC
    ''', args);

    if (eventRows.isEmpty) return [];

    final ids = eventRows.map((r) => r['id'] as int).toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final idolRows = await db.rawQuery('''
      SELECT r.event_id, i.name, i.color, i.color_value, SUM(r.count) AS cnt
      FROM records r
      JOIN idols i ON i.id = r.idol_id
      JOIN events e ON e.id = r.event_id
      WHERE r.event_id IN ($placeholders) AND r.is_online = e.is_online
      GROUP BY r.event_id, i.id
      ORDER BY cnt DESC, i.name ASC
    ''', ids);

    final groupRows = await db.rawQuery('''
      SELECT r.event_id, r.group_name, SUM(r.count) AS cnt
      FROM records r
      JOIN events e ON e.id = r.event_id
      WHERE r.event_id IN ($placeholders)
        AND r.record_type = 'group'
        AND r.is_online = e.is_online
      GROUP BY r.event_id, r.group_name
      ORDER BY cnt DESC, r.group_name ASC
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
              colorValue: row['color_value'] as int,
              count: (row['cnt'] as num).toInt(),
            ),
          );
    }
    for (final row in groupRows) {
      final eid = row['event_id'] as int;
      byEvent
          .putIfAbsent(eid, () => [])
          .add(
            IdolSummaryEntry(
              name: '${row['group_name']}团切',
              color: '',
              colorValue: 0,
              count: (row['cnt'] as num).toInt(),
              isGroup: true,
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
