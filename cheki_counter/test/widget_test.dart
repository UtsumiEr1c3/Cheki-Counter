import 'dart:convert';
import 'dart:io';

import 'package:cheki_counter/data/csv_service.dart';
import 'package:cheki_counter/data/db.dart';
import 'package:cheki_counter/data/event_repository.dart';
import 'package:cheki_counter/data/models/event.dart';
import 'package:cheki_counter/features/events/event_card.dart';
import 'package:cheki_counter/features/events/events_overview_page.dart';
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
}

Future<String> _databasePath() async {
  final dbPath = await getDatabasesPath();
  return p.join(dbPath, 'cheki_counter.db');
}

Future<void> _resetTestDatabase() async {
  await DatabaseHelper.instance.close();
  await deleteDatabase(await _databasePath());
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
