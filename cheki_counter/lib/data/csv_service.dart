import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cheki_counter/data/db.dart';
import 'package:cheki_counter/data/event_repository.dart';
import 'package:cheki_counter/data/idol_repository.dart';
import 'package:cheki_counter/data/record_repository.dart';
import 'package:cheki_counter/data/models/idol.dart';
import 'package:cheki_counter/data/models/record.dart';

class ImportResult {
  int newIdols = 0;
  int newRecords = 0;
  int newEvents = 0;
  int skipped = 0;
  int errors = 0;
  List<String> errorDetails = [];
}

class CsvService {
  final _idolRepo = IdolRepository();
  final _recordRepo = RecordRepository();
  final _eventRepo = EventRepository();

  static const _header = [
    '偶像名',
    '应援色',
    '团体',
    '日期',
    '数量',
    '单价',
    '小计',
    '场地',
    '创建时间',
    '活动名',
    '活动场地',
    '活动日期',
    '电切',
  ];

  /// Import CSV from file bytes. Merge-append semantics.
  /// Accepts both legacy 9-column and new 11-column formats.
  Future<ImportResult> importCsv(List<int> bytes) async {
    final result = ImportResult();

    // Handle UTF-8 BOM
    String content;
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      content = utf8.decode(bytes.sublist(3));
    } else {
      content = utf8.decode(bytes);
    }

    content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final rows = const CsvToListConverter(eol: '\n').convert(content);
    if (rows.isEmpty) return result;

    final header = rows.first.map((e) => e.toString().trim()).toList();
    if (header.length < 9) {
      result.errors = 1;
      result.errorDetails.add('行1: 列数不足,期望至少9列');
      return result;
    }

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final lineNum = i + 1;

      try {
        if (row.length < 9) {
          throw const FormatException('列数不足');
        }

        String col(int idx) =>
            idx < row.length ? row[idx].toString().trim() : '';

        // Idol/record side
        final name = col(0);
        final color = col(1);
        final group = col(2);
        final date = col(3);
        final countVal = row.length > 4 ? row[4] : '';
        final priceVal = row.length > 5 ? row[5] : '';
        final venue = col(7);
        final createdAt = col(8);

        // Event side
        final eventName = col(9);
        final eventVenue = col(10);
        final eventDate = col(11);

        // is_online (col 12, new in 13-column format)
        bool isOnline = false;
        if (row.length > 12) {
          final raw = col(12);
          if (raw == '1') {
            isOnline = true;
          } else if (raw.isEmpty || raw == '0') {
            isOnline = false;
          } else {
            isOnline = false;
            result.errors++;
            result.errorDetails.add('行$lineNum: 电切列值无效,已按现场(0)处理');
          }
        }

        // Resolve event first (shared across both sides)
        int? eventId;
        final hasEvent = eventName.isNotEmpty &&
            eventVenue.isNotEmpty &&
            eventDate.isNotEmpty;

        final hasRecord = name.isNotEmpty &&
            date.isNotEmpty &&
            venue.isNotEmpty &&
            countVal.toString().trim().isNotEmpty &&
            priceVal.toString().trim().isNotEmpty;

        if (!hasEvent && !hasRecord) {
          throw const FormatException('既无偶像也无活动');
        }

        if (hasEvent) {
          final existingEvent = await _findEventId(
            eventName,
            eventVenue,
            eventDate,
          );
          if (existingEvent != null) {
            eventId = existingEvent;
          } else {
            eventId = await _eventRepo.upsertByTriple(
              eventName,
              eventVenue,
              eventDate,
              createdAt.isNotEmpty ? createdAt : DateTime.now().toIso8601String(),
            );
            result.newEvents++;
          }
        }

        if (!hasRecord) {
          // Pure check-in event row (C)
          continue;
        }

        final count = countVal is num
            ? countVal.toInt()
            : int.tryParse(countVal.toString().trim());
        if (count == null || count <= 0) {
          throw FormatException('数量无效: $countVal');
        }

        final unitPrice = priceVal is num
            ? priceVal.toInt()
            : int.tryParse(priceVal.toString().trim());
        if (unitPrice == null || unitPrice <= 0) {
          throw FormatException('单价无效: $priceVal');
        }

        // Find or create idol
        var idol = await _idolRepo.findByTriple(name, color, group);
        bool newIdol = false;
        if (idol == null) {
          final idolObj = Idol(
            name: name,
            color: color,
            groupName: group,
            createdAt: createdAt,
          );
          final record = CheckiRecord(
            idolId: 0,
            date: date,
            count: count,
            unitPrice: unitPrice,
            subtotal: count * unitPrice,
            venue: venue,
            createdAt: createdAt,
            eventId: eventId,
            isOnline: isOnline,
          );
          await _idolRepo.insertWithFirstRecord(idolObj, record);
          result.newIdols++;
          result.newRecords++;
          newIdol = true;
          idol = await _idolRepo.findByTriple(name, color, group);
        }

        if (!newIdol) {
          final exists = await _recordRepo.existsByDedupKey(
            idolId: idol!.id!,
            date: date,
            count: count,
            unitPrice: unitPrice,
            venue: venue,
            createdAt: createdAt,
            eventId: eventId,
            isOnline: isOnline,
          );

          if (exists) {
            result.skipped++;
          } else {
            final record = CheckiRecord(
              idolId: idol.id!,
              date: date,
              count: count,
              unitPrice: unitPrice,
              subtotal: count * unitPrice,
              venue: venue,
              createdAt: createdAt,
              eventId: eventId,
              isOnline: isOnline,
            );
            await _recordRepo.insert(record);
            result.newRecords++;
          }
        }
      } catch (e) {
        result.errors++;
        result.errorDetails.add('行$lineNum: $e');
      }
    }

    return result;
  }

  Future<int?> _findEventId(String name, String venue, String date) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'events',
      columns: ['id'],
      where: 'name = ? AND venue = ? AND date = ?',
      whereArgs: [name, venue, date],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }

  /// Export all records and pure-check-in events to a CSV file.
  /// Returns the file path.
  Future<String> exportCsv() async {
    final db = await DatabaseHelper.instance.database;

    final recordRows = await db.rawQuery('''
      SELECT i.name AS idol_name, i.color AS idol_color, i.group_name,
             r.date AS r_date, r.count, r.unit_price, r.subtotal,
             r.venue AS r_venue, r.created_at AS r_created,
             r.is_online AS r_is_online,
             e.name AS e_name, e.venue AS e_venue, e.date AS e_date,
             COALESCE(e.date, r.date) AS sort_date, r.id AS r_id
      FROM records r
      JOIN idols i ON i.id = r.idol_id
      LEFT JOIN events e ON e.id = r.event_id
      ORDER BY sort_date DESC, r_id ASC
    ''');

    final pureEventRows = await db.rawQuery('''
      SELECT e.name AS e_name, e.venue AS e_venue, e.date AS e_date,
             e.created_at AS e_created
      FROM events e
      WHERE NOT EXISTS (
        SELECT 1 FROM records r WHERE r.event_id = e.id
      )
      ORDER BY e.date DESC, e.id ASC
    ''');

    // Merge-sort by event date (desc), keeping record rows' tie-break by r.id.
    final combined = <_ExportRow>[];
    for (final r in recordRows) {
      combined.add(_ExportRow(
        sortDate: r['sort_date'] as String? ?? '',
        isRecord: true,
        data: r,
      ));
    }
    for (final e in pureEventRows) {
      combined.add(_ExportRow(
        sortDate: e['e_date'] as String,
        isRecord: false,
        data: e,
      ));
    }
    combined.sort((a, b) => b.sortDate.compareTo(a.sortDate));

    final csvRows = <List<dynamic>>[
      _header,
      ...combined.map((row) {
        final d = row.data;
        if (row.isRecord) {
          return [
            d['idol_name'] ?? '',
            d['idol_color'] ?? '',
            d['group_name'] ?? '',
            d['r_date'] ?? '',
            d['count'] ?? '',
            d['unit_price'] ?? '',
            (d['subtotal'] as int?)?.toStringAsFixed(2) ?? '',
            d['r_venue'] ?? '',
            d['r_created'] ?? '',
            d['e_name'] ?? '',
            d['e_venue'] ?? '',
            d['e_date'] ?? '',
            (d['r_is_online'] as int?) == 1 ? '1' : '0',
          ];
        } else {
          return [
            '', '', '', '', '', '', '', '',
            d['e_created'] ?? '',
            d['e_name'] ?? '',
            d['e_venue'] ?? '',
            d['e_date'] ?? '',
            '0',
          ];
        }
      }),
    ];

    final csvString = const ListToCsvConverter().convert(csvRows);

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/cheki_export.csv');
    final bom = [0xEF, 0xBB, 0xBF];
    await file.writeAsBytes([...bom, ...utf8.encode(csvString)]);

    return file.path;
  }
}

class _ExportRow {
  final String sortDate;
  final bool isRecord;
  final Map<String, dynamic> data;

  _ExportRow({
    required this.sortDate,
    required this.isRecord,
    required this.data,
  });
}
