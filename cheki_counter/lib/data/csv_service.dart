import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cheki_counter/data/db.dart';
import 'package:cheki_counter/data/idol_repository.dart';
import 'package:cheki_counter/data/record_repository.dart';
import 'package:cheki_counter/data/models/idol.dart';
import 'package:cheki_counter/data/models/record.dart';

class ImportResult {
  int newIdols = 0;
  int newRecords = 0;
  int skipped = 0;
  int errors = 0;
  List<String> errorDetails = [];
}

class CsvService {
  final _idolRepo = IdolRepository();
  final _recordRepo = RecordRepository();

  static const _header = ['ID', '应援色', '团体', '日期', '数量', '单价', '小计', '场地', '创建时间'];

  /// Import CSV from file bytes. Merge-append semantics.
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

    // Normalize line endings to \n for reliable parsing
    content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final rows = const CsvToListConverter(eol: '\n').convert(content);
    if (rows.isEmpty) return result;

    // Validate header
    final header = rows.first.map((e) => e.toString().trim()).toList();
    if (header.length < 9) {
      result.errors = 1;
      result.errorDetails.add('行1: 列数不足,期望9列');
      return result;
    }

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final lineNum = i + 1;

      try {
        if (row.length < 9) {
          throw FormatException('列数不足');
        }

        final name = row[0].toString().trim();
        final color = row[1].toString().trim();
        final group = row[2].toString().trim();
        final date = row[3].toString().trim();
        // row[4] and row[5] may be parsed as int, double, or String by CsvToListConverter
        final countVal = row[4];
        final priceVal = row[5];
        // row[6] is subtotal - we recalculate
        final venue = row[7].toString().trim();
        final createdAt = row[8].toString().trim();

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

        if (name.isEmpty || date.isEmpty || venue.isEmpty) {
          throw FormatException('必填字段为空');
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
          );
          await _idolRepo.insertWithFirstRecord(idolObj, record);
          result.newIdols++;
          result.newRecords++;
          newIdol = true;
          // Re-fetch for subsequent rows
          idol = await _idolRepo.findByTriple(name, color, group);
        }

        if (!newIdol) {
          // Check dedup
          final exists = await _recordRepo.existsByDedupKey(
            idolId: idol!.id!,
            date: date,
            count: count,
            unitPrice: unitPrice,
            venue: venue,
            createdAt: createdAt,
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

  /// Export all records to a CSV file. Returns the file path.
  Future<String> exportCsv() async {
    final db = await DatabaseHelper.instance.database;

    final rows = await db.rawQuery('''
      SELECT i.name, i.color, i.group_name,
             r.date, r.count, r.unit_price, r.subtotal, r.venue, r.created_at
      FROM records r
      JOIN idols i ON i.id = r.idol_id
      ORDER BY r.created_at DESC
    ''');

    final csvRows = <List<dynamic>>[
      _header,
      ...rows.map((r) => [
            r['name'],
            r['color'],
            r['group_name'],
            r['date'],
            r['count'],
            r['unit_price'],
            (r['subtotal'] as int).toStringAsFixed(2),
            r['venue'],
            r['created_at'],
          ]),
    ];

    final csvString = const ListToCsvConverter().convert(csvRows);

    // Write with UTF-8 BOM
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/cheki_export.csv');
    final bom = [0xEF, 0xBB, 0xBF];
    await file.writeAsBytes([...bom, ...utf8.encode(csvString)]);

    return file.path;
  }
}
