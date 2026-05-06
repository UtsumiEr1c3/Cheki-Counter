import 'dart:convert';
import 'dart:io';

import 'package:cheki_counter/data/csv_service.dart';
import 'package:cheki_counter/data/db.dart';
import 'package:cheki_counter/data/event_repository.dart';
import 'package:cheki_counter/data/idol_repository.dart';
import 'package:cheki_counter/data/models/event.dart';
import 'package:cheki_counter/features/events/event_card.dart';
import 'package:cheki_counter/features/events/events_overview_page.dart';
import 'package:cheki_counter/features/statistics/group_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await _resetTestDatabase();
  });

  tearDown(() async {
    await _resetTestDatabase();
  });

  test('CheckiEvent maps ticket price with a zero default', () {
    final legacy = CheckiEvent.fromMap({
      'id': 1,
      'name': '定期公演',
      'venue': '武汉MAO',
      'date': '2026-04-20',
      'created_at': '2026-04-01T12:00:00',
    });

    expect(legacy.ticketPrice, 0);

    final event = legacy.toMap()..['ticket_price'] = 180;
    expect(CheckiEvent.fromMap(event).ticketPrice, 180);
  });

  test('EventRepository upsert writes ticket price conservatively', () async {
    final executor = _FakeEventExecutor();
    final repo = EventRepository();

    final id = await repo.upsertByTriple(
      '定期公演',
      '武汉MAO',
      '2026-04-20',
      '2026-04-01T12:00:00',
      ticketPrice: 0,
      executor: executor,
    );
    expect(id, 1);
    expect(executor.events.single['ticket_price'], 0);

    final sameId = await repo.upsertByTriple(
      '定期公演',
      '武汉MAO',
      '2026-04-20',
      '2026-04-02T12:00:00',
      ticketPrice: 180,
      executor: executor,
    );
    expect(sameId, id);
    expect(executor.events.single['ticket_price'], 180);

    await repo.upsertByTriple(
      '定期公演',
      '武汉MAO',
      '2026-04-20',
      '2026-04-03T12:00:00',
      ticketPrice: 220,
      executor: executor,
    );
    expect(executor.events.single['ticket_price'], 180);
  });

  test('database migration adds zero ticket prices to v3 events', () async {
    final path = await _databasePath();
    final oldDb = await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE idols (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            color TEXT NOT NULL,
            group_name TEXT NOT NULL,
            created_at TEXT NOT NULL,
            UNIQUE (name, color, group_name)
          )
        ''');
        await db.execute('''
          CREATE TABLE events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            venue TEXT NOT NULL,
            date TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE UNIQUE INDEX idx_events_triple ON events(name, venue, date)',
        );
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
    await oldDb.insert('events', {
      'name': '定期公演',
      'venue': '武汉MAO',
      'date': '2026-04-20',
      'created_at': '2026-04-01T12:00:00',
    });
    await oldDb.close();

    final upgradedDb = await DatabaseHelper.instance.database;
    final rows = await upgradedDb.query('events');

    expect(rows.single['ticket_price'], 0);
  });

  test('CSV import treats 13-column rows as ticket price zero', () async {
    final result = await CsvService().importCsv(
      utf8.encode(
        [
          '偶像名,应援色,团体,日期,数量,单价,小计,场地,创建时间,活动名,活动场地,活动日期,电切',
          '小五,蓝色,EAUX,2026-04-20,2,70,140.00,武汉MAO,2026-04-20T10:00:00,VoltFes 2.0,武汉MAO,2026-04-20,0',
        ].join('\n'),
      ),
    );
    final db = await DatabaseHelper.instance.database;
    final events = await db.query('events');

    expect(result.newEvents, 1);
    expect(events.single['ticket_price'], 0);
  });

  test('CSV import reads ticket price and keeps existing non-zero value', () async {
    final service = CsvService();
    final first = await service.importCsv(
      utf8.encode(
        [
          '偶像名,应援色,团体,日期,数量,单价,小计,场地,创建时间,活动名,活动场地,活动日期,电切,门票价格',
          '小五,蓝色,EAUX,2026-04-20,2,70,140.00,武汉MAO,2026-04-20T10:00:00,VoltFes 2.0,武汉MAO,2026-04-20,0,180',
        ].join('\n'),
      ),
    );
    final second = await service.importCsv(
      utf8.encode(
        [
          '偶像名,应援色,团体,日期,数量,单价,小计,场地,创建时间,活动名,活动场地,活动日期,电切,门票价格',
          '小五,蓝色,EAUX,2026-04-20,2,70,140.00,武汉MAO,2026-04-20T10:00:00,VoltFes 2.0,武汉MAO,2026-04-20,0,220',
        ].join('\n'),
      ),
    );
    final db = await DatabaseHelper.instance.database;
    final events = await db.query('events');
    final records = await db.query('records');

    expect(first.newEvents, 1);
    expect(first.newRecords, 1);
    expect(second.newEvents, 0);
    expect(second.skipped, 1);
    expect(events.single['ticket_price'], 180);
    expect(records, hasLength(1));
  });

  test('CSV export can be imported again without duplicate data', () async {
    final tempDir = Directory.systemTemp.createTempSync('cheki_csv_test_');
    final previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    addTearDown(() {
      PathProviderPlatform.instance = previousPathProvider;
      tempDir.deleteSync(recursive: true);
    });

    final service = CsvService();
    await service.importCsv(
      utf8.encode(
        [
          '偶像名,应援色,团体,日期,数量,单价,小计,场地,创建时间,活动名,活动场地,活动日期,电切,门票价格',
          '小五,蓝色,EAUX,2026-04-20,2,70,140.00,武汉MAO,2026-04-20T10:00:00,VoltFes 2.0,武汉MAO,2026-04-20,0,180',
        ].join('\n'),
      ),
    );

    final exportPath = await service.exportCsv();
    final exportedBytes = await File(exportPath).readAsBytes();
    final result = await service.importCsv(exportedBytes);
    final db = await DatabaseHelper.instance.database;
    final events = await db.query('events');
    final records = await db.query('records');

    expect(result.newEvents, 0);
    expect(result.newRecords, 0);
    expect(result.skipped, 1);
    expect(result.errors, 0);
    expect(events.single['ticket_price'], 180);
    expect(records, hasLength(1));
  });

  test(
    'CSV import records invalid ticket price and falls back to zero',
    () async {
      final result = await CsvService().importCsv(
        utf8.encode(
          [
            '偶像名,应援色,团体,日期,数量,单价,小计,场地,创建时间,活动名,活动场地,活动日期,电切,门票价格',
            '小五,蓝色,EAUX,2026-04-20,2,70,140.00,武汉MAO,2026-04-20T10:00:00,VoltFes 2.0,武汉MAO,2026-04-20,0,abc',
          ].join('\n'),
        ),
      );
      final db = await DatabaseHelper.instance.database;
      final events = await db.query('events');

      expect(result.errors, 1);
      expect(result.errorDetails.single, contains('门票价格无效'));
      expect(events.single['ticket_price'], 0);
    },
  );

  testWidgets('EventCard shows ticket, cheki, and grand totals', (
    tester,
  ) async {
    final summary = EventWithSummary(
      event: CheckiEvent(
        id: 1,
        name: 'VoltFes 2.0',
        venue: '武汉MAO',
        date: '2026-04-20',
        createdAt: '2026-04-01T12:00:00',
        ticketPrice: 180,
      ),
      totalCount: 5,
      totalAmount: 350,
      recordCount: 2,
      idolSummary: [
        IdolSummaryEntry(name: '小五', color: '蓝色', count: 3),
        IdolSummaryEntry(name: '桃子', color: '粉色', count: 2),
      ],
      ticketPrice: 180,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EventCard(summary: summary)),
      ),
    );

    expect(find.text('票 ¥180'), findsOneWidget);
    expect(find.text('切 ¥350'), findsOneWidget);
    expect(find.text('合计 ¥530'), findsOneWidget);
  });

  testWidgets('EventTotalsBar shows ticket, cheki, and grand totals', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EventTotalsBar(
            totalEvents: 12,
            withRecords: 9,
            totalTicketAmount: 2160,
            totalChekiAmount: 2450,
            grandAmount: 4610,
          ),
        ),
      ),
    );

    expect(find.text('12 场'), findsOneWidget);
    expect(find.text('9 场有切奇'), findsOneWidget);
    expect(find.text('门票 ¥2160'), findsOneWidget);
    expect(find.text('切 ¥2450'), findsOneWidget);
    expect(find.text('合计 ¥4610'), findsOneWidget);
  });

  test('IdolRepository filters group aggregates by year', () async {
    await _seedGroupStatisticsData();
    final repo = IdolRepository();

    final allGroups = await repo.getGroupAggregates();
    final allEaux = allGroups.firstWhere((g) => g['group_name'] == 'EAUX');
    expect(allEaux['idol_count'], 2);
    expect(allEaux['total_count'], 6);
    expect(allEaux['total_amount'], 550);

    final groups2026 = await repo.getGroupAggregates(year: '2026');
    expect(groups2026, hasLength(1));
    expect(groups2026.single['group_name'], 'EAUX');
    expect(groups2026.single['idol_count'], 2);
    expect(groups2026.single['total_count'], 3);
    expect(groups2026.single['total_amount'], 340);
  });

  test('IdolRepository returns group idols by year and sort mode', () async {
    await _seedGroupStatisticsData();
    final repo = IdolRepository();

    final byCount = await repo.getByGroupWithAggregates(
      groupName: 'EAUX',
      year: '2026',
    );
    expect(byCount.map((idol) => idol.name), ['小五', '花枝']);
    expect(byCount.map((idol) => idol.totalCount), [2, 1]);

    final byAmount = await repo.getByGroupWithAggregates(
      groupName: 'EAUX',
      year: '2026',
      sortBy: 'amount',
    );
    expect(byAmount.map((idol) => idol.name), ['花枝', '小五']);
    expect(byAmount.map((idol) => idol.totalAmount), [200, 140]);
  });

  testWidgets('GroupDetailPage inherits year and sorts by amount', (
    tester,
  ) async {
    await _seedGroupStatisticsData();

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/idol-detail': (_) => const Scaffold(body: Text('idol detail')),
        },
        home: const GroupDetailPage(groupName: 'EAUX', initialYear: '2026'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('2026年'), findsOneWidget);
    expect(find.text('小五'), findsOneWidget);
    expect(find.text('花枝'), findsOneWidget);
    expect(find.text('¥340'), findsOneWidget);

    expect(
      tester.getTopLeft(find.text('小五')).dy,
      lessThan(tester.getTopLeft(find.text('花枝')).dy),
    );

    await tester.tap(find.text('按金额'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.getTopLeft(find.text('花枝')).dy,
      lessThan(tester.getTopLeft(find.text('小五')).dy),
    );
  });
}

Future<String> _databasePath() async {
  final dbPath = await getDatabasesPath();
  return p.join(dbPath, 'cheki_counter.db');
}

Future<void> _resetTestDatabase() async {
  await DatabaseHelper.instance.close();
  await deleteDatabase(await _databasePath());
}

Future<void> _seedGroupStatisticsData() async {
  final db = await DatabaseHelper.instance.database;
  final xiaowu = await db.insert('idols', {
    'name': '小五',
    'color': '蓝色',
    'group_name': 'EAUX',
    'created_at': '2026-01-01T00:00:00',
  });
  final huazhi = await db.insert('idols', {
    'name': '花枝',
    'color': '红色',
    'group_name': 'EAUX',
    'created_at': '2026-01-01T00:00:01',
  });
  final heita = await db.insert('idols', {
    'name': '黑塔',
    'color': '绿色',
    'group_name': '心率研究所',
    'created_at': '2026-01-01T00:00:02',
  });

  await db.insert('records', {
    'idol_id': xiaowu,
    'date': '2026-05-04',
    'count': 2,
    'unit_price': 70,
    'subtotal': 140,
    'venue': '上海摩登天空',
    'created_at': '2026-05-04T12:00:00',
    'is_online': 0,
  });
  await db.insert('records', {
    'idol_id': huazhi,
    'date': '2026-05-04',
    'count': 1,
    'unit_price': 200,
    'subtotal': 200,
    'venue': '上海摩登天空',
    'created_at': '2026-05-04T12:01:00',
    'is_online': 0,
  });
  await db.insert('records', {
    'idol_id': xiaowu,
    'date': '2025-12-24',
    'count': 3,
    'unit_price': 70,
    'subtotal': 210,
    'venue': '育音堂',
    'created_at': '2025-12-24T12:00:00',
    'is_online': 0,
  });
  await db.insert('records', {
    'idol_id': heita,
    'date': '2025-12-25',
    'count': 1,
    'unit_price': 70,
    'subtotal': 70,
    'venue': '育音堂',
    'created_at': '2025-12-25T12:00:00',
    'is_online': 0,
  });
}

class _FakeEventExecutor implements DatabaseExecutor {
  final events = <Map<String, Object?>>[];
  int _nextId = 1;

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    _checkEventsTable(table);
    return events
        .where(
          (e) =>
              e['name'] == whereArgs![0] &&
              e['venue'] == whereArgs[1] &&
              e['date'] == whereArgs[2],
        )
        .map((e) => {for (final column in columns ?? e.keys) column: e[column]})
        .toList();
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    _checkEventsTable(table);
    final id = _nextId++;
    events.add({...values, 'id': id});
    return id;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    _checkEventsTable(table);
    final id = whereArgs!.single;
    final index = events.indexWhere((e) => e['id'] == id);
    if (index == -1) return 0;
    events[index].addAll(values);
    return 1;
  }

  void _checkEventsTable(String table) {
    if (table != 'events') {
      throw StateError('Unexpected table $table');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePathProvider extends PathProviderPlatform {
  final String temporaryPath;

  _FakePathProvider(this.temporaryPath);

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;
}
