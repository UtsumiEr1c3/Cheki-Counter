import 'package:sqflite/sqflite.dart';
import 'package:cheki_counter/data/db.dart';
import 'package:cheki_counter/data/models/record.dart';

class RecordRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Insert a new record.
  Future<int> insert(CheckiRecord record) async {
    final db = await _db;
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

      final idolId = record.first['idol_id'] as int;

      // Delete the record
      await txn.delete('records', where: 'id = ?', whereArgs: [recordId]);

      // Check if idol has remaining records
      final remaining = Sqflite.firstIntValue(
        await txn.rawQuery(
          'SELECT COUNT(*) FROM records WHERE idol_id = ?',
          [idolId],
        ),
      );

      if (remaining == 0) {
        await txn.delete('idols', where: 'id = ?', whereArgs: [idolId]);
        idolDeleted = true;
      }
    });

    return idolDeleted;
  }

  /// List all records for a given idol, ordered by date DESC, created_at DESC.
  Future<List<CheckiRecord>> listByIdol(int idolId) async {
    final db = await _db;
    final results = await db.query(
      'records',
      where: 'idol_id = ?',
      whereArgs: [idolId],
      orderBy: 'date DESC, created_at DESC',
    );
    return results.map((row) => CheckiRecord.fromMap(row)).toList();
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
    return await db.rawQuery('''
      SELECT date, SUM(count) AS total
      FROM records WHERE idol_id = ?
      GROUP BY date ORDER BY date
    ''', [idolId]);
  }

  /// Get monthly aggregates for an idol (for line chart).
  Future<List<Map<String, dynamic>>> monthlyAggregates(int idolId) async {
    final db = await _db;
    return await db.rawQuery('''
      SELECT strftime('%Y-%m', date) AS ym, SUM(count) AS total
      FROM records WHERE idol_id = ?
      GROUP BY ym ORDER BY ym
    ''', [idolId]);
  }

  /// Get distinct years from records.
  Future<List<String>> getDistinctYears() async {
    final db = await _db;
    final results = await db.rawQuery(
      "SELECT DISTINCT strftime('%Y', date) AS year FROM records ORDER BY year DESC",
    );
    return results.map((r) => r['year'] as String).toList();
  }

  /// Check if a record with the exact dedup key already exists.
  Future<bool> existsByDedupKey({
    required int idolId,
    required String date,
    required int count,
    required int unitPrice,
    required String venue,
    required String createdAt,
  }) async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT 1 FROM records
      WHERE idol_id = ? AND date = ? AND count = ?
        AND unit_price = ? AND venue = ? AND created_at = ?
      LIMIT 1
    ''', [idolId, date, count, unitPrice, venue, createdAt]);
    return result.isNotEmpty;
  }
}
