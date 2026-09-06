import 'dart:math';

import 'package:sqflite/sqflite.dart';
import 'package:cheki_counter/data/db.dart';
import 'package:cheki_counter/data/models/idol.dart';
import 'package:cheki_counter/data/models/record.dart';

class IdolRepository {
  final _random = Random.secure();

  Future<Database> get _db => DatabaseHelper.instance.database;

  String generateStableId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final suffix = _random.nextInt(0x7fffffff).toRadixString(16);
    return 'idol_${timestamp}_$suffix';
  }

  /// Get all idols for selection controls.
  Future<List<Idol>> getAllForSelection() async {
    final db = await _db;
    final results = await db.query(
      'idols',
      orderBy: 'name ASC, group_name ASC, id ASC',
    );
    return results.map((row) => Idol.fromMap(row)).toList();
  }

  Future<List<String>> getDistinctGroupNames() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT group_name FROM idols WHERE group_name != ''
      UNION
      SELECT group_name FROM record_groups WHERE group_name != ''
      UNION
      SELECT r.group_name FROM records r
      WHERE r.record_type = 'group'
        AND r.group_name IS NOT NULL
        AND r.group_name != ''
        AND NOT EXISTS (
          SELECT 1 FROM record_groups rg WHERE rg.record_id = r.id
        )
      ORDER BY group_name
    ''');
    return rows.map((row) => row['group_name'] as String).toList();
  }

  Future<List<String>> getMemberNamesByGroup(String groupName) async {
    final db = await _db;
    final rows = await db.query(
      'idols',
      columns: ['name'],
      where: 'group_name = ?',
      whereArgs: [groupName],
      orderBy: 'name ASC, id ASC',
    );
    return rows.map((row) => row['name'] as String).toList();
  }

  Future<List<String>> getSuggestedMemberNamesByGroup(String groupName) async {
    final currentMembers = await getMemberNamesByGroup(groupName);
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      WITH group_links AS (
        SELECT record_id, group_name FROM record_groups
        UNION ALL
        SELECT r.id, r.group_name
        FROM records r
        WHERE r.record_type = 'group'
          AND r.group_name IS NOT NULL
          AND r.group_name != ''
          AND NOT EXISTS (
            SELECT 1 FROM record_groups rg WHERE rg.record_id = r.id
          )
      )
      SELECT r.group_members
      FROM records r
      JOIN group_links gl ON gl.record_id = r.id
      WHERE gl.group_name = ?
        AND r.record_type = 'group'
        AND r.group_members IS NOT NULL
        AND r.group_members != ''
      ORDER BY r.date DESC, r.created_at DESC, r.id DESC
      LIMIT 1
    ''',
      [groupName],
    );
    final result = <String>[];
    final seen = <String>{};
    void addNames(Iterable<String> names) {
      for (final name in names) {
        final trimmed = name.trim();
        if (trimmed.isNotEmpty && seen.add(trimmed)) result.add(trimmed);
      }
    }

    addNames(currentMembers);
    if (rows.isNotEmpty) {
      addNames(
        (rows.first['group_members'] as String).split(RegExp(r'[,，、\n]')),
      );
    }
    return result;
  }

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
      query =
          '''
        SELECT i.id, i.stable_id, i.name, i.color, i.color_value,
               i.group_name, i.created_at,
               SUM(r.count) AS total_count,
               SUM(r.subtotal) AS total_amount
        FROM idols i
        INNER JOIN records r ON r.idol_id = i.id
        WHERE strftime('%Y', r.date) = '$year'
        GROUP BY i.id
        ORDER BY $orderCol DESC
      ''';
    } else {
      query =
          '''
        SELECT i.id, i.stable_id, i.name, i.color, i.color_value,
               i.group_name, i.created_at,
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
  Future<Idol?> findByTriple(
    String name,
    String color,
    String groupName,
  ) async {
    final db = await _db;
    final results = await db.query(
      'idols',
      where: 'name = ? AND color = ? AND group_name = ?',
      whereArgs: [name, color, groupName],
    );
    if (results.isEmpty) return null;
    return Idol.fromMap(results.first);
  }

  Future<Idol?> findByStableId(String stableId) async {
    if (stableId.trim().isEmpty) return null;
    final db = await _db;
    final results = await db.query(
      'idols',
      where: 'stable_id = ?',
      whereArgs: [stableId.trim()],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Idol.fromMap(results.first);
  }

  Future<Idol?> findById(int id) async {
    final db = await _db;
    final results = await db.query(
      'idols',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Idol.fromMap(results.first);
  }

  Future<bool> hasTripleConflict({
    required int idolId,
    required String name,
    required String color,
    required String groupName,
  }) async {
    final db = await _db;
    final results = await db.query(
      'idols',
      columns: ['id'],
      where: 'name = ? AND color = ? AND group_name = ? AND id <> ?',
      whereArgs: [name, color, groupName, idolId],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  Future<void> updateCurrentProfile({
    required int idolId,
    required String name,
    required String color,
    required int colorValue,
    required String groupName,
  }) async {
    if (await hasTripleConflict(
      idolId: idolId,
      name: name,
      color: color,
      groupName: groupName,
    )) {
      throw DuplicateIdolTripleException();
    }

    final db = await _db;
    await db.update(
      'idols',
      {
        'name': name,
        'color': color,
        'color_value': colorValue,
        'group_name': groupName,
      },
      where: 'id = ?',
      whereArgs: [idolId],
    );
  }

  /// Insert a new idol with its first record in a single transaction.
  Future<int> insertWithFirstRecord(Idol idol, CheckiRecord record) async {
    final db = await _db;
    late int idolId;
    await db.transaction((txn) async {
      final idolToInsert = idol.stableId.isEmpty
          ? idol.copyWith(stableId: generateStableId())
          : idol;
      idolId = await txn.insert('idols', idolToInsert.toMap());
      final recordMap = record.toMap();
      recordMap['idol_id'] = idolId;
      await txn.insert('records', recordMap);
    });
    return idolId;
  }

  /// Get idols in one group with aggregated count and amount.
  /// [sortBy] can be 'count' or 'amount'.
  /// [year] filters records by year (null = all).
  Future<List<Idol>> getByGroupWithAggregates({
    required String groupName,
    String sortBy = 'count',
    String? year,
  }) async {
    final db = await _db;
    final orderCol = sortBy == 'amount' ? 'total_amount' : 'total_count';
    final whereParts = ['i.group_name = ?'];
    final args = <Object?>[groupName];
    if (year != null) {
      whereParts.add("strftime('%Y', r.date) = ?");
      args.add(year);
    }

    final results = await db.rawQuery('''
      SELECT i.id, i.stable_id, i.name, i.color, i.color_value,
             i.group_name, i.created_at,
             SUM(r.count) AS total_count,
             SUM(r.subtotal) AS total_amount
      FROM idols i
      INNER JOIN records r ON r.idol_id = i.id
      WHERE ${whereParts.join(' AND ')}
      GROUP BY i.id
      ORDER BY $orderCol DESC
    ''', args);

    return results.map((row) => Idol.fromMap(row)).toList();
  }

  /// Get aggregates for groups.
  /// [year] filters records by year (null = all).
  Future<List<Map<String, dynamic>>> getGroupAggregates({String? year}) async {
    final db = await _db;
    final where = year == null ? '' : "WHERE strftime('%Y', r.date) = ?";
    final args = year == null ? <Object?>[] : <Object?>[year];

    final idolRows = await db.rawQuery('''
      SELECT i.group_name,
             COUNT(DISTINCT i.id) AS idol_count,
             SUM(r.count) AS total_count,
             SUM(r.subtotal) AS total_amount
      FROM idols i
      INNER JOIN records r ON r.idol_id = i.id
      $where
      GROUP BY i.group_name
    ''', args);

    final groupConditions = <String>["r.record_type = 'group'"];
    final groupArgs = <Object?>[];
    if (year != null) {
      groupConditions.add("strftime('%Y', r.date) = ?");
      groupArgs.add(year);
    }
    final groupRows = await db.rawQuery('''
      WITH group_links AS (
        SELECT record_id, group_name FROM record_groups
        UNION ALL
        SELECT r.id, r.group_name
        FROM records r
        WHERE r.record_type = 'group'
          AND r.group_name IS NOT NULL
          AND r.group_name != ''
          AND NOT EXISTS (
            SELECT 1 FROM record_groups rg WHERE rg.record_id = r.id
          )
      )
      SELECT gl.group_name, SUM(r.count) AS total_count,
             SUM(r.subtotal) AS total_amount
      FROM records r
      JOIN group_links gl ON gl.record_id = r.id
      WHERE ${groupConditions.join(' AND ')}
      GROUP BY gl.group_name
    ''', groupArgs);

    final merged = <String, Map<String, dynamic>>{};
    for (final row in idolRows) {
      merged[row['group_name'] as String] = {
        'group_name': row['group_name'],
        'idol_count': (row['idol_count'] as num).toInt(),
        'total_count': (row['total_count'] as num).toInt(),
        'total_amount': (row['total_amount'] as num).toInt(),
      };
    }
    for (final row in groupRows) {
      final name = row['group_name'] as String;
      final target = merged.putIfAbsent(
        name,
        () => {
          'group_name': name,
          'idol_count': 0,
          'total_count': 0,
          'total_amount': 0,
        },
      );
      target['total_count'] =
          (target['total_count'] as int) + (row['total_count'] as num).toInt();
      target['total_amount'] =
          (target['total_amount'] as int) +
          (row['total_amount'] as num).toInt();
    }
    final result = merged.values.toList();
    result.sort(
      (a, b) => (b['total_count'] as int).compareTo(a['total_count'] as int),
    );
    return result;
  }
}

class DuplicateIdolTripleException implements Exception {}
