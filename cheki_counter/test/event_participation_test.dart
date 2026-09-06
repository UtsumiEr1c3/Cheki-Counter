import 'dart:convert';

import 'package:cheki_counter/data/csv_service.dart';
import 'package:cheki_counter/data/db.dart';
import 'package:cheki_counter/data/event_repository.dart';
import 'package:cheki_counter/data/models/event.dart';
import 'package:cheki_counter/data/models/record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(_resetTestDatabase);
  tearDown(_resetTestDatabase);

  test('v6 迁移根据关联记录回填活动参与方式', () async {
    final oldDb = await openDatabase(
      await _databasePath(),
      version: 6,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            venue TEXT NOT NULL,
            date TEXT NOT NULL,
            created_at TEXT NOT NULL,
            ticket_price INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            idol_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            count INTEGER NOT NULL,
            unit_price INTEGER NOT NULL,
            subtotal INTEGER NOT NULL,
            venue TEXT NOT NULL,
            created_at TEXT NOT NULL,
            event_id INTEGER,
            is_online INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
    final onlineId = await oldDb.insert('events', {
      'name': '线上特典会',
      'venue': '东京',
      'date': '2026-01-01',
      'created_at': '2026-01-01T00:00:00',
    });
    final emptyId = await oldDb.insert('events', {
      'name': '纯打卡',
      'venue': '上海',
      'date': '2026-01-02',
      'created_at': '2026-01-02T00:00:00',
    });
    await oldDb.insert('records', {
      'idol_id': 1,
      'date': '2026-01-01',
      'count': 1,
      'unit_price': 60,
      'subtotal': 60,
      'venue': '电切',
      'created_at': '2026-01-01T00:01:00',
      'event_id': onlineId,
      'is_online': 1,
    });
    await oldDb.close();

    final db = await DatabaseHelper.instance.database;
    final online = await db.query(
      'events',
      where: 'id = ?',
      whereArgs: [onlineId],
    );
    final empty = await db.query(
      'events',
      where: 'id = ?',
      whereArgs: [emptyId],
    );
    final recordColumns = await db.rawQuery('PRAGMA table_info(records)');
    final migratedRecords = await db.query('records');
    expect(online.single['is_online'], 1);
    expect(empty.single['is_online'], 0);
    expect(online.single['stable_id'], isNotEmpty);
    expect(empty.single['stable_id'], isNotEmpty);
    expect(
      recordColumns.singleWhere((row) => row['name'] == 'idol_id')['notnull'],
      0,
    );
    expect(
      recordColumns.any((row) => row['name'] == 'group_members'),
      isTrue,
    );
    expect(migratedRecords.single['record_type'], 'normal');
  });

  test('v8 数据库升级时保留团切并增加成员快照列', () async {
    final oldDb = await openDatabase(
      await _databasePath(),
      version: 8,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            idol_id INTEGER,
            date TEXT NOT NULL,
            count INTEGER NOT NULL,
            unit_price INTEGER NOT NULL,
            subtotal INTEGER NOT NULL,
            venue TEXT NOT NULL,
            created_at TEXT NOT NULL,
            event_id INTEGER,
            is_online INTEGER NOT NULL DEFAULT 0,
            record_type TEXT NOT NULL DEFAULT 'normal',
            special_name TEXT,
            group_name TEXT
          )
        ''');
      },
    );
    await oldDb.insert('records', {
      'date': '2026-01-01',
      'count': 1,
      'unit_price': 200,
      'subtotal': 200,
      'venue': '上海',
      'created_at': '2026-01-01T00:00:00',
      'event_id': 1,
      'record_type': 'group',
      'group_name': '旧团体',
    });
    await oldDb.close();

    final db = await DatabaseHelper.instance.database;
    final columns = await db.rawQuery('PRAGMA table_info(records)');
    final records = await db.query('records');

    expect(columns.any((row) => row['name'] == 'group_members'), isTrue);
    expect(records.single['record_type'], 'group');
    expect(records.single['group_name'], '旧团体');
    expect(records.single['group_members'], isNull);
  });

  test('支出统计包含全部切奇且只累计现场门票', () async {
    final db = await DatabaseHelper.instance.database;
    final onsite = await _insertEvent(db, '现场活动', false, 150);
    await _insertEvent(db, '电切活动', true, 80);
    await _insertIdolAndRecord(db, onsite, 300, false);
    await _insertIdolAndRecord(db, null, 200, true, suffix: '2');
    await _insertIdolAndRecord(
      db,
      null,
      90,
      false,
      suffix: '3',
      recordType: ChekiRecordType.theme,
      specialName: '新年主题',
    );
    await db.insert('records', {
      'idol_id': null,
      'date': '2026-01-01',
      'count': 2,
      'unit_price': 80,
      'subtotal': 160,
      'venue': '上海',
      'created_at': '2026-01-01T00:00:04',
      'event_id': onsite,
      'is_online': 0,
      'record_type': 'group',
      'group_name': '团体',
      'group_members': '偶像1、偶像2',
    });

    final summary = await EventRepository().getSpendingSummary(year: '2026');
    expect(summary.allChekiAmount, 750);
    expect(summary.onsiteChekiAmount, 550);
    expect(summary.onlineChekiAmount, 200);
    expect(summary.normalChekiAmount, 500);
    expect(summary.themeChekiAmount, 90);
    expect(summary.groupChekiAmount, 160);
    expect(
      summary.normalChekiAmount +
          summary.themeChekiAmount +
          summary.groupChekiAmount,
      summary.allChekiAmount,
    );
    expect(
      summary.onsiteChekiAmount + summary.onlineChekiAmount,
      summary.allChekiAmount,
    );
    expect(summary.onsiteTicketAmount, 150);
    expect(summary.onsiteEventCount, 1);
    expect(summary.totalSpending, 900);
  });

  test('编辑活动只同步仍沿用旧日期和场地的记录', () async {
    final db = await DatabaseHelper.instance.database;
    final id = await _insertEvent(db, '旧活动', false, 100);
    await _insertIdolAndRecord(db, id, 60, false);
    await _insertIdolAndRecord(db, id, 70, true, suffix: '2');
    await db.update(
      'records',
      {'venue': '电切'},
      where: 'created_at = ?',
      whereArgs: ['2026-01-01T00:00:02'],
    );
    final repo = EventRepository();
    final original = (await repo.getById(id))!;
    await repo.update(
      original,
      CheckiEvent(
        id: id,
        stableId: original.stableId,
        name: '新活动',
        venue: '北京',
        date: '2026-02-02',
        createdAt: original.createdAt,
        ticketPrice: 180,
      ),
    );

    final rows = await db.query('records', orderBy: 'id');
    expect(rows[0]['date'], '2026-02-02');
    expect(rows[1]['date'], '2026-02-02');
    expect(rows[0]['venue'], '北京');
    expect(rows[1]['venue'], '电切');
  });

  test('旧 CSV 可导入，新 CSV 按活动稳定 ID 复用', () async {
    final oldResult = await CsvService().importCsv(
      utf8.encode(
        '偶像名,应援色,团体,日期,数量,单价,小计,场地,创建时间,活动名,活动场地,活动日期,电切,门票价格\n'
        '小五,蓝色,EAUX,2026-01-01,1,60,60,电切,2026-01-01T00:00:00,线上会,东京,2026-01-01,1,0',
      ),
    );
    expect(oldResult.newEvents, 1);
    final db = await DatabaseHelper.instance.database;
    final oldEvent = (await db.query('events')).single;
    expect(oldEvent['is_online'], 1);

    final newResult = await CsvService().importCsv(
      utf8.encode(
        '偶像ID,偶像名,应援色,团体,日期,数量,单价,小计,场地,创建时间,活动名,活动场地,活动日期,电切,门票价格,应援色值,活动ID,活动方式\n'
        ',,,,,,,,,,改名后的线上会,东京,2026-01-01,0,0,,${oldEvent['stable_id']},电切',
      ),
    );
    expect(newResult.newEvents, 0);
    expect(await db.query('events'), hasLength(1));
  });
}

Future<int> _insertEvent(Database db, String name, bool isOnline, int ticket) {
  return db.insert('events', {
    'stable_id': 'event_$name',
    'name': name,
    'venue': '上海',
    'date': '2026-01-01',
    'created_at': '2026-01-01T00:00:00',
    'ticket_price': ticket,
    'is_online': isOnline ? 1 : 0,
  });
}

Future<void> _insertIdolAndRecord(
  Database db,
  int? eventId,
  int subtotal,
  bool isOnline, {
  String suffix = '1',
  ChekiRecordType recordType = ChekiRecordType.normal,
  String? specialName,
}) async {
  final idolId = await db.insert('idols', {
    'stable_id': 'idol_$suffix',
    'name': '偶像$suffix',
    'color': '蓝色',
    'color_value': 0xFF1E88E5,
    'group_name': '团体',
    'created_at': '2026-01-01T00:00:0$suffix',
  });
  await db.insert('records', {
    'idol_id': idolId,
    'date': '2026-01-01',
    'count': 1,
    'unit_price': subtotal,
    'subtotal': subtotal,
    'venue': '上海',
    'created_at': '2026-01-01T00:00:0$suffix',
    'event_id': eventId,
    'is_online': isOnline ? 1 : 0,
    'record_type': recordType.value,
    'special_name': specialName,
  });
}

Future<String> _databasePath() async {
  final root = await getDatabasesPath();
  return p.join(root, 'cheki_counter.db');
}

Future<void> _resetTestDatabase() async {
  await DatabaseHelper.instance.close();
  await deleteDatabase(await _databasePath());
}
