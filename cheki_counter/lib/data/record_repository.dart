import 'package:sqflite/sqflite.dart';
import 'package:cheki_counter/data/db.dart';
import 'package:cheki_counter/data/models/record.dart';

class IdolRecordRow {
  final CheckiRecord record;
  final String? eventName;

  IdolRecordRow({required this.record, this.eventName});
}

enum SpendingRecordFilter { all, normal, theme, group, onsite, online }

class SpendingRecordRow {
  final CheckiRecord record;
  final String? idolName;
  final String? idolColor;
  final int? idolColorValue;
  final String? eventName;

  const SpendingRecordRow({
    required this.record,
    this.idolName,
    this.idolColor,
    this.idolColorValue,
    this.eventName,
  });
}

class RecordRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Insert a new record.
  Future<int> insert(CheckiRecord record, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _db;
    return await db.insert('records', record.toMap());
  }

  /// Delete a record and clean up the idol if no records remain.
  /// Returns true if the idol was also deleted.
  Future<bool> deleteAndCleanupIdolIfEmpty(int recordId) async {
    final db = await _db;
    bool idolDeleted = false;

    await db.transaction((txn) async {
      // Get the idol_id before deleting
      final record = await txn.query(
        'records',
        columns: ['idol_id'],
        where: 'id = ?',
        whereArgs: [recordId],
      );
      if (record.isEmpty) return;

      final idolId = record.first['idol_id'] as int?;

      // Delete the record
      await txn.delete('records', where: 'id = ?', whereArgs: [recordId]);

      if (idolId == null) return;

      // 检查偶像是否仍有记录
      final remaining = Sqflite.firstIntValue(
        await txn.rawQuery('SELECT COUNT(*) FROM records WHERE idol_id = ?', [
          idolId,
        ]),
      );

      if (remaining == 0) {
        await txn.delete('idols', where: 'id = ?', whereArgs: [idolId]);
        idolDeleted = true;
      }
    });

    return idolDeleted;
  }

  /// List all records for a given idol, ordered by date DESC, created_at DESC.
  /// Joins `events` to carry the (optional) event name for UI display.
  Future<List<IdolRecordRow>> listByIdol(int idolId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT r.id, r.idol_id, r.date, r.count, r.unit_price, r.subtotal,
             r.venue, r.created_at, r.event_id, r.is_online,
             r.record_type, r.special_name, r.group_name, r.group_members,
             e.name AS event_name
      FROM records r
      LEFT JOIN events e ON e.id = r.event_id
      WHERE r.idol_id = ?
      ORDER BY r.date DESC, r.created_at DESC
    ''',
      [idolId],
    );
    return rows
        .map(
          (row) => IdolRecordRow(
            record: CheckiRecord.fromMap(row),
            eventName: row['event_name'] as String?,
          ),
        )
        .toList();
  }

  Future<List<SpendingRecordRow>> listForSpending({
    String? year,
    SpendingRecordFilter filter = SpendingRecordFilter.all,
  }) async {
    final db = await _db;
    final conditions = <String>[];
    final args = <Object?>[];
    if (year != null) {
      conditions.add("strftime('%Y', r.date) = ?");
      args.add(year);
    }
    switch (filter) {
      case SpendingRecordFilter.all:
        break;
      case SpendingRecordFilter.normal:
      case SpendingRecordFilter.theme:
      case SpendingRecordFilter.group:
        conditions.add('r.record_type = ?');
        args.add(filter.name);
        break;
      case SpendingRecordFilter.onsite:
        conditions.add('r.is_online = 0');
        break;
      case SpendingRecordFilter.online:
        conditions.add('r.is_online = 1');
        break;
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final rows = await db.rawQuery('''
      SELECT r.id, r.idol_id, r.date, r.count, r.unit_price, r.subtotal,
             r.venue, r.created_at, r.event_id, r.is_online,
             r.record_type, r.special_name, r.group_name, r.group_members,
             i.name AS idol_name, i.color AS idol_color,
             i.color_value AS idol_color_value, e.name AS event_name
      FROM records r
      LEFT JOIN idols i ON i.id = r.idol_id
      LEFT JOIN events e ON e.id = r.event_id
      $where
      ORDER BY r.date DESC, r.created_at DESC, r.id DESC
    ''', args);
    return rows
        .map(
          (row) => SpendingRecordRow(
            record: CheckiRecord.fromMap(row),
            idolName: row['idol_name'] as String?,
            idolColor: row['idol_color'] as String?,
            idolColorValue: row['idol_color_value'] as int?,
            eventName: row['event_name'] as String?,
          ),
        )
        .toList();
  }

  /// List all records for a given event, ordered by idol and created_at.
  Future<List<Map<String, dynamic>>> getByEventId(int eventId) async {
    final db = await _db;
    return await db.rawQuery(
      '''
      SELECT r.id, r.idol_id, r.date, r.count, r.unit_price, r.subtotal,
             r.venue, r.created_at, r.event_id, r.is_online,
             r.record_type, r.special_name, r.group_name, r.group_members,
             i.name AS idol_name, i.color AS idol_color,
             i.color_value AS idol_color_value,
             i.group_name AS idol_group_name
      FROM records r
      LEFT JOIN idols i ON i.id = r.idol_id
      WHERE r.event_id = ?
      ORDER BY COALESCE(i.name, r.group_name) ASC, r.created_at DESC
    ''',
      [eventId],
    );
  }

  /// Get the last unit price for a given idol (by created_at).
  /// Returns null if no records exist.
  Future<int?> lastUnitPriceOf(int idolId) async {
    final db = await _db;
    final results = await db.query(
      'records',
      columns: ['unit_price'],
      where: 'idol_id = ?',
      whereArgs: [idolId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first['unit_price'] as int;
  }

  /// Get daily aggregates for an idol (for line chart).
  Future<List<Map<String, dynamic>>> dailyAggregates(int idolId) async {
    final db = await _db;
    return await db.rawQuery(
      '''
      SELECT date, SUM(count) AS total
      FROM records WHERE idol_id = ?
      GROUP BY date ORDER BY date
    ''',
      [idolId],
    );
  }

  /// Get monthly aggregates for an idol (for line chart).
  Future<List<Map<String, dynamic>>> monthlyAggregates(int idolId) async {
    final db = await _db;
    return await db.rawQuery(
      '''
      SELECT strftime('%Y-%m', date) AS ym, SUM(count) AS total
      FROM records WHERE idol_id = ?
      GROUP BY ym ORDER BY ym
    ''',
      [idolId],
    );
  }

  /// Get distinct years from records.
  Future<List<String>> getDistinctYears() async {
    final db = await _db;
    final results = await db.rawQuery(
      "SELECT DISTINCT strftime('%Y', date) AS year FROM records ORDER BY year DESC",
    );
    return results.map((r) => r['year'] as String).toList();
  }

  Future<Map<String, int>> getGroupChekiAggregate(
    String groupName, {
    String? year,
  }) async {
    final db = await _db;
    final conditions = <String>["record_type = 'group'", 'group_name = ?'];
    final args = <Object?>[groupName];
    if (year != null) {
      conditions.add("strftime('%Y', date) = ?");
      args.add(year);
    }
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(count), 0) AS total_count,
             COALESCE(SUM(subtotal), 0) AS total_amount
      FROM records
      WHERE ${conditions.join(' AND ')}
    ''', args);
    final row = rows.single;
    return {
      'total_count': (row['total_count'] as num).toInt(),
      'total_amount': (row['total_amount'] as num).toInt(),
    };
  }

  Future<Map<String, int>> getAllGroupChekiAggregate({String? year}) async {
    final db = await _db;
    final conditions = <String>["record_type = 'group'"];
    final args = <Object?>[];
    if (year != null) {
      conditions.add("strftime('%Y', date) = ?");
      args.add(year);
    }
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(count), 0) AS total_count,
             COALESCE(SUM(subtotal), 0) AS total_amount
      FROM records
      WHERE ${conditions.join(' AND ')}
    ''', args);
    final row = rows.single;
    return {
      'total_count': (row['total_count'] as num).toInt(),
      'total_amount': (row['total_amount'] as num).toInt(),
    };
  }

  Future<void> markTheme({required int recordId, required String name}) async {
    final db = await _db;
    await db.update(
      'records',
      {'record_type': 'theme', 'special_name': name.trim()},
      where: "id = ? AND idol_id IS NOT NULL AND event_id IS NULL",
      whereArgs: [recordId],
    );
  }

  Future<void> markNormal(int recordId) async {
    final db = await _db;
    await db.update(
      'records',
      {'record_type': 'normal', 'special_name': null},
      where: "id = ? AND idol_id IS NOT NULL",
      whereArgs: [recordId],
    );
  }

  /// Get distinct venues across records and events, case-folded to drop
  /// near-duplicates. For each lowercase group, returns the venue whose
  /// source row has the most recent `created_at`. Ordered by that
  /// timestamp DESC.
  Future<List<String>> getDistinctVenues() async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT venue, MAX(last_used) AS last_used FROM (
        SELECT venue, created_at AS last_used FROM records
          WHERE venue IS NOT NULL AND venue != ''
        UNION ALL
        SELECT venue, created_at AS last_used FROM events
          WHERE venue IS NOT NULL AND venue != ''
      )
      GROUP BY LOWER(venue)
      ORDER BY last_used DESC
    ''');
    return results.map((r) => r['venue'] as String).toList();
  }

  /// Resolve canonical venue form for a user-typed input.
  /// Trims input; returns null for empty. Otherwise looks up the most recent
  /// row (across records + events) whose venue matches case-insensitively
  /// and returns that venue's original casing. Returns null if no match.
  Future<String?> canonicalVenueFor(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final db = await _db;
    final results = await db.rawQuery(
      '''
      SELECT venue FROM (
        SELECT venue, created_at FROM records WHERE LOWER(venue) = LOWER(?)
        UNION ALL
        SELECT venue, created_at FROM events WHERE LOWER(venue) = LOWER(?)
      )
      ORDER BY created_at DESC LIMIT 1
    ''',
      [trimmed, trimmed],
    );
    if (results.isEmpty) return null;
    return results.first['venue'] as String;
  }

  /// Check if a record with the exact dedup key already exists.
  /// `eventId` may be null; NULL equality is matched via IS.
  Future<bool> existsByDedupKey({
    int? idolId,
    required String date,
    required int count,
    required int unitPrice,
    required String venue,
    required String createdAt,
    int? eventId,
    required bool isOnline,
    ChekiRecordType recordType = ChekiRecordType.normal,
    String? specialName,
    String? groupName,
    String? groupMembers,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _db;
    final result = await db.rawQuery(
      '''
      SELECT 1 FROM records
      WHERE ((idol_id IS NULL AND ? IS NULL) OR idol_id = ?)
        AND date = ? AND count = ?
        AND unit_price = ? AND venue = ? AND created_at = ?
        AND ((event_id IS NULL AND ? IS NULL) OR event_id = ?)
        AND is_online = ?
        AND record_type = ?
        AND ((special_name IS NULL AND ? IS NULL) OR special_name = ?)
        AND ((group_name IS NULL AND ? IS NULL) OR group_name = ?)
        AND ((group_members IS NULL AND ? IS NULL) OR group_members = ?)
      LIMIT 1
    ''',
      [
        idolId,
        idolId,
        date,
        count,
        unitPrice,
        venue,
        createdAt,
        eventId,
        eventId,
        isOnline ? 1 : 0,
        recordType.value,
        specialName,
        specialName,
        groupName,
        groupName,
        groupMembers,
        groupMembers,
      ],
    );
    return result.isNotEmpty;
  }
}
