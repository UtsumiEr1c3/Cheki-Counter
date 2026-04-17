import 'package:sqflite/sqflite.dart';
import 'package:cheki_counter/data/db.dart';
import 'package:cheki_counter/data/models/idol.dart';
import 'package:cheki_counter/data/models/record.dart';

class IdolRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Get all idols with aggregated count and amount.
  /// [sortBy] can be 'count' or 'amount'.
  /// [year] filters records by year (null = all).
  Future<List<Idol>> getAllWithAggregates({
    String sortBy = 'count',
    String? year,
  }) async {
    final db = await _db;
    final orderCol = sortBy == 'amount' ? 'total_amount' : 'total_count';

    final String query;
    if (year != null) {
      query = '''
        SELECT i.id, i.name, i.color, i.group_name, i.created_at,
               SUM(r.count) AS total_count,
               SUM(r.subtotal) AS total_amount
        FROM idols i
        INNER JOIN records r ON r.idol_id = i.id
        WHERE strftime('%Y', r.date) = '$year'
        GROUP BY i.id
        ORDER BY $orderCol DESC
      ''';
    } else {
      query = '''
        SELECT i.id, i.name, i.color, i.group_name, i.created_at,
               COALESCE(SUM(r.count), 0) AS total_count,
               COALESCE(SUM(r.subtotal), 0) AS total_amount
        FROM idols i
        LEFT JOIN records r ON r.idol_id = i.id
        GROUP BY i.id
        ORDER BY $orderCol DESC
      ''';
    }

    final results = await db.rawQuery(query);

    return results.map((row) => Idol.fromMap(row)).toList();
  }

  /// Find idol by (name, color, group) triple.
  Future<Idol?> findByTriple(String name, String color, String groupName) async {
    final db = await _db;
    final results = await db.query(
      'idols',
      where: 'name = ? AND color = ? AND group_name = ?',
      whereArgs: [name, color, groupName],
    );
    if (results.isEmpty) return null;
    return Idol.fromMap(results.first);
  }

  /// Insert a new idol with its first record in a single transaction.
  Future<int> insertWithFirstRecord(Idol idol, CheckiRecord record) async {
    final db = await _db;
    late int idolId;
    await db.transaction((txn) async {
      idolId = await txn.insert('idols', idol.toMap());
      final recordMap = record.toMap();
      recordMap['idol_id'] = idolId;
      await txn.insert('records', recordMap);
    });
    return idolId;
  }

  /// Get aggregates for groups.
  Future<List<Map<String, dynamic>>> getGroupAggregates() async {
    final db = await _db;
    return await db.rawQuery('''
      SELECT i.group_name,
             COUNT(DISTINCT i.id) AS idol_count,
             COALESCE(SUM(r.count), 0) AS total_count,
             COALESCE(SUM(r.subtotal), 0) AS total_amount
      FROM idols i
      LEFT JOIN records r ON r.idol_id = i.id
      GROUP BY i.group_name
      ORDER BY total_count DESC
    ''');
  }
}
