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
import 'package:cheki_counter/shared/colors.dart';

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
    '偶像ID',
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
    '门票价格',
    '应援色值',
    '活动ID',
    '活动方式',
    '切奇类型',
    '切奇名称',
    '团切成员',
  ];

  /// Import CSV from file bytes. Merge-append semantics.
  /// Accepts legacy formats and the current header-based extended format.
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
    final hasStableIdColumn = header.isNotEmpty && header.first == '偶像ID';
    final colorValueIndex = header.indexOf('应援色值');
    final eventStableIdIndex = header.indexOf('活动ID');
    final eventModeIndex = header.indexOf('活动方式');
    final recordTypeIndex = header.indexOf('切奇类型');
    final specialNameIndex = header.indexOf('切奇名称');
    final groupMembersIndex = header.indexOf('团切成员');
    final offset = hasStableIdColumn ? 1 : 0;
    if (header.length < 9 + offset) {
      result.errors = 1;
      result.errorDetails.add('行1: 列数不足,期望至少9列');
      return result;
    }

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final lineNum = i + 1;

      try {
        if (row.length < 9 + offset) {
          throw const FormatException('列数不足');
        }

        String col(int idx) =>
            idx < row.length ? row[idx].toString().trim() : '';

        // Idol/record side
        final stableId = hasStableIdColumn ? col(0) : '';
        final name = col(offset);
        final color = col(offset + 1);
        final group = col(offset + 2);
        final date = col(offset + 3);
        final countVal = row.length > offset + 4 ? row[offset + 4] : '';
        final priceVal = row.length > offset + 5 ? row[offset + 5] : '';
        final venue = col(offset + 7);
        final createdAt = col(offset + 8);
        final rawRecordType = recordTypeIndex >= 0 ? col(recordTypeIndex) : '';
        const supportedRecordTypes = {
          '',
          '普通切',
          '主题切',
          '团切',
          'normal',
          'theme',
          'group',
        };
        if (!supportedRecordTypes.contains(rawRecordType)) {
          throw FormatException('切奇类型无效: $rawRecordType');
        }
        final recordType = ChekiRecordType.fromCsv(rawRecordType);
        final specialName = specialNameIndex >= 0 ? col(specialNameIndex) : '';
        final groupMembers = groupMembersIndex >= 0
            ? col(groupMembersIndex)
            : '';

        // Event side
        final eventName = col(offset + 9);
        final eventVenue = col(offset + 10);
        final eventDate = col(offset + 11);
        final hasEvent =
            eventName.isNotEmpty &&
            eventVenue.isNotEmpty &&
            eventDate.isNotEmpty;

        var ticketPrice = 0;
        if (hasEvent && row.length > offset + 13) {
          final rawTicketPrice = col(offset + 13);
          if (rawTicketPrice.isNotEmpty) {
            final parsed = int.tryParse(rawTicketPrice);
            if (parsed == null || parsed < 0) {
              result.errors++;
              result.errorDetails.add('行$lineNum: 门票价格无效,已按0处理');
            } else {
              ticketPrice = parsed;
            }
          }
        }

        // is_online (col 12 in legacy format, col 13 in stable-id format)
        bool isOnline = false;
        if (row.length > offset + 12) {
          final raw = col(offset + 12);
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
        final hasRecordFields =
            date.isNotEmpty &&
            venue.isNotEmpty &&
            countVal.toString().trim().isNotEmpty &&
            priceVal.toString().trim().isNotEmpty;
        final hasIndividualRecord = name.isNotEmpty && hasRecordFields;
        final hasGroupRecord =
            recordType == ChekiRecordType.group &&
            group.isNotEmpty &&
            hasRecordFields;
        final hasRecord = hasIndividualRecord || hasGroupRecord;

        if (recordType == ChekiRecordType.theme) {
          if (!hasIndividualRecord) {
            throw const FormatException('主题切缺少偶像或切奇记录');
          }
          if (specialName.isEmpty) {
            throw const FormatException('主题切缺少切奇名称');
          }
          if (hasEvent) {
            throw const FormatException('主题切不能关联活动');
          }
        }
        if (recordType == ChekiRecordType.group) {
          if (!hasGroupRecord) {
            throw const FormatException('团切缺少团体或切奇记录');
          }
          if (!hasEvent) {
            throw const FormatException('团切必须关联活动');
          }
          if (groupMembers.isEmpty) {
            throw const FormatException('团切缺少成员');
          }
        }
        final eventStableId = eventStableIdIndex >= 0
            ? col(eventStableIdIndex)
            : '';
        final rawEventMode = eventModeIndex >= 0 ? col(eventModeIndex) : '';
        final eventIsOnline = rawEventMode == '电切' || rawEventMode == '1'
            ? true
            : rawEventMode == '现场' || rawEventMode == '0'
            ? false
            : hasRecord && isOnline;

        var colorValue = colorValueForName(color);
        if (hasIndividualRecord && colorValueIndex >= 0) {
          final rawColorValue = col(colorValueIndex);
          if (rawColorValue.isNotEmpty) {
            final parsed = tryParseColorHex(rawColorValue);
            if (parsed == null) {
              result.errors++;
              result.errorDetails.add('行$lineNum: 应援色值无效,已按灰色处理');
              colorValue = fallbackIdolColorValue;
            } else {
              colorValue = parsed;
            }
          } else if (!presetColors.containsKey(color)) {
            result.errors++;
            result.errorDetails.add('行$lineNum: 无法从应援色名称恢复色值,已按灰色处理');
          }
        } else if (hasIndividualRecord && !presetColors.containsKey(color)) {
          result.errors++;
          result.errorDetails.add('行$lineNum: 无法从旧格式恢复应援色值,已按灰色处理');
        }

        if (!hasEvent && !hasRecord) {
          throw const FormatException('既无偶像也无活动');
        }

        if (hasEvent) {
          final stableEvent = eventStableId.isEmpty
              ? null
              : await _eventRepo.getByStableId(eventStableId);
          final existingEventId =
              stableEvent?.id ??
              await _findEventId(eventName, eventVenue, eventDate);
          eventId =
              stableEvent?.id ??
              await _eventRepo.upsertByTriple(
                eventName,
                eventVenue,
                eventDate,
                createdAt.isNotEmpty
                    ? createdAt
                    : DateTime.now().toIso8601String(),
                ticketPrice: ticketPrice,
                isOnline: eventIsOnline,
                stableId: eventStableId.isEmpty ? null : eventStableId,
              );
          if (existingEventId == null) {
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
        if (unitPrice == null || unitPrice < 0) {
          throw FormatException('单价无效: $priceVal');
        }

        final normalizedSpecialName = recordType == ChekiRecordType.theme
            ? specialName
            : null;
        final normalizedGroupName = recordType == ChekiRecordType.group
            ? group
            : null;
        final normalizedGroupMembers = recordType == ChekiRecordType.group
            ? groupMembers
            : null;

        if (recordType == ChekiRecordType.group) {
          final exists = await _recordRepo.existsByDedupKey(
            idolId: null,
            date: date,
            count: count,
            unitPrice: unitPrice,
            venue: venue,
            createdAt: createdAt,
            eventId: eventId,
            isOnline: isOnline,
            recordType: recordType,
            groupName: normalizedGroupName,
            groupMembers: normalizedGroupMembers,
          );
          if (exists) {
            result.skipped++;
          } else {
            await _recordRepo.insert(
              CheckiRecord(
                date: date,
                count: count,
                unitPrice: unitPrice,
                subtotal: count * unitPrice,
                venue: venue,
                createdAt: createdAt,
                eventId: eventId,
                isOnline: isOnline,
                recordType: recordType,
                groupName: normalizedGroupName,
                groupMembers: normalizedGroupMembers,
              ),
            );
            result.newRecords++;
          }
          continue;
        }

        // Find or create idol
        var idol = stableId.isNotEmpty
            ? await _idolRepo.findByStableId(stableId)
            : await _idolRepo.findByTriple(name, color, group);
        bool newIdol = false;
        if (idol == null) {
          final idolObj = Idol(
            stableId: stableId,
            name: name,
            color: color,
            colorValue: colorValue,
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
            recordType: recordType,
            specialName: normalizedSpecialName,
          );
          await _idolRepo.insertWithFirstRecord(idolObj, record);
          result.newIdols++;
          result.newRecords++;
          newIdol = true;
          idol = stableId.isNotEmpty
              ? await _idolRepo.findByStableId(stableId)
              : await _idolRepo.findByTriple(name, color, group);
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
            recordType: recordType,
            specialName: normalizedSpecialName,
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
              recordType: recordType,
              specialName: normalizedSpecialName,
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
      SELECT i.stable_id AS idol_stable_id,
             i.name AS idol_name, i.color AS idol_color,
             i.color_value AS idol_color_value,
             i.group_name AS idol_group_name,
             r.date AS r_date, r.count, r.unit_price, r.subtotal,
             r.venue AS r_venue, r.created_at AS r_created,
             r.is_online AS r_is_online,
             r.record_type, r.special_name, r.group_members,
             r.group_name AS record_group_name,
             e.name AS e_name, e.venue AS e_venue, e.date AS e_date,
             e.ticket_price AS e_ticket_price, e.stable_id AS e_stable_id,
             e.is_online AS e_is_online,
             COALESCE(e.date, r.date) AS sort_date, r.id AS r_id
      FROM records r
      LEFT JOIN idols i ON i.id = r.idol_id
      LEFT JOIN events e ON e.id = r.event_id
      ORDER BY sort_date DESC, r_id ASC
    ''');

    final pureEventRows = await db.rawQuery('''
      SELECT e.name AS e_name, e.venue AS e_venue, e.date AS e_date,
             e.created_at AS e_created, e.ticket_price AS e_ticket_price,
             e.stable_id AS e_stable_id, e.is_online AS e_is_online
      FROM events e
      WHERE NOT EXISTS (
        SELECT 1 FROM records r WHERE r.event_id = e.id
      )
      ORDER BY e.date DESC, e.id ASC
    ''');

    // Merge-sort by event date (desc), keeping record rows' tie-break by r.id.
    final combined = <_ExportRow>[];
    for (final r in recordRows) {
      combined.add(
        _ExportRow(
          sortDate: r['sort_date'] as String? ?? '',
          isRecord: true,
          data: r,
        ),
      );
    }
    for (final e in pureEventRows) {
      combined.add(
        _ExportRow(sortDate: e['e_date'] as String, isRecord: false, data: e),
      );
    }
    combined.sort((a, b) => b.sortDate.compareTo(a.sortDate));

    final csvRows = <List<dynamic>>[
      _header,
      ...combined.map((row) {
        final d = row.data;
        if (row.isRecord) {
          return [
            d['idol_stable_id'] ?? '',
            d['idol_name'] ?? '',
            d['idol_color'] ?? '',
            d['record_group_name'] ?? d['idol_group_name'] ?? '',
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
            d['e_name'] == null
                ? ''
                : ((d['e_ticket_price'] as int?) ?? 0).toString(),
            d['idol_color_value'] == null
                ? ''
                : colorValueToHex(d['idol_color_value'] as int),
            d['e_stable_id'] ?? '',
            d['e_name'] == null
                ? ''
                : ((d['e_is_online'] as int?) == 1 ? '电切' : '现场'),
            ChekiRecordType.fromValue(d['record_type']).label,
            d['special_name'] ?? '',
            d['group_members'] ?? '',
          ];
        } else {
          return [
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            d['e_created'] ?? '',
            d['e_name'] ?? '',
            d['e_venue'] ?? '',
            d['e_date'] ?? '',
            '0',
            ((d['e_ticket_price'] as int?) ?? 0).toString(),
            '',
            d['e_stable_id'] ?? '',
            (d['e_is_online'] as int?) == 1 ? '电切' : '现场',
            '',
            '',
            '',
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
