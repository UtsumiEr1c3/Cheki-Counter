import 'package:cheki_counter/data/db.dart';
import 'package:cheki_counter/shared/colors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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

  test('v5 数据库升级时回填预设色与未知色灰色', () async {
    final path = await _databasePath();
    final oldDb = await openDatabase(
      path,
      version: 5,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE idols (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            stable_id TEXT NOT NULL,
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

    final presetId = await oldDb.insert('idols', {
      'name': '小五',
      'stable_id': 'idol_preset',
      'color': '紫色',
      'group_name': 'EAUX',
      'created_at': '2026-01-01T00:00:00',
    });
    final unknownId = await oldDb.insert('idols', {
      'name': '桃子',
      'stable_id': 'idol_unknown',
      'color': '星空色',
      'group_name': 'EAUX',
      'created_at': '2026-01-01T00:00:01',
    });
    await oldDb.insert('records', {
      'idol_id': presetId,
      'date': '2026-01-01',
      'count': 1,
      'unit_price': 60,
      'subtotal': 60,
      'venue': '上海',
      'created_at': '2026-01-01T00:00:02',
      'is_online': 0,
    });
    await oldDb.close();

    final upgraded = await DatabaseHelper.instance.database;
    final idols = await upgraded.query('idols', orderBy: 'id ASC');
    final records = await upgraded.query('records');

    expect(idols, hasLength(2));
    expect(idols[0]['id'], presetId);
    expect(idols[0]['stable_id'], 'idol_preset');
    expect(idols[0]['color'], '紫色');
    expect(idols[0]['color_value'], colorValueForName('紫色'));
    expect(idols[1]['id'], unknownId);
    expect(idols[1]['stable_id'], 'idol_unknown');
    expect(idols[1]['color'], '星空色');
    expect(idols[1]['color_value'], fallbackIdolColorValue);
    expect(records.single['idol_id'], presetId);
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
