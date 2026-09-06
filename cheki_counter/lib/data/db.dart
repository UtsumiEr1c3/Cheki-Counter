import 'dart:math';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:cheki_counter/shared/colors.dart';
import 'package:cheki_counter/data/models/event.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'cheki_counter.db');

    return await openDatabase(
      path,
      version: 9,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE idols (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        stable_id TEXT NOT NULL,
        color TEXT NOT NULL,
        color_value INTEGER NOT NULL,
        group_name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE (name, color, group_name)
      )
    ''');

    await db.execute(
      'CREATE UNIQUE INDEX idx_idols_stable_id ON idols(stable_id)',
    );

    await db.execute('''
      CREATE TABLE events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stable_id TEXT NOT NULL,
        name TEXT NOT NULL,
        venue TEXT NOT NULL,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        ticket_price INTEGER NOT NULL DEFAULT 0,
        is_online INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX idx_events_stable_id ON events(stable_id)',
    );

    await db.execute(
      'CREATE UNIQUE INDEX idx_events_triple ON events(name, venue, date)',
    );

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
        group_name TEXT,
        group_members TEXT,
        FOREIGN KEY (idol_id) REFERENCES idols (id),
        FOREIGN KEY (event_id) REFERENCES events (id)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
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
      await db.execute('ALTER TABLE records ADD COLUMN event_id INTEGER');
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE records ADD COLUMN is_online INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('''
        UPDATE records SET is_online = 1
        WHERE LOWER(venue) LIKE '%电切%' OR LOWER(venue) LIKE '%電切%'
      ''');
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE events ADD COLUMN ticket_price INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE idols ADD COLUMN stable_id TEXT');
      final rows = await db.query('idols', columns: ['id']);
      final random = Random.secure();
      for (final row in rows) {
        final id = row['id'] as int;
        await db.update(
          'idols',
          {'stable_id': _generateStableId(random, id)},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      await db.execute(
        'CREATE UNIQUE INDEX idx_idols_stable_id ON idols(stable_id)',
      );
    }
    if (oldVersion < 6) {
      await db.execute(
        'ALTER TABLE idols ADD COLUMN color_value INTEGER NOT NULL '
        'DEFAULT $fallbackIdolColorValue',
      );
      for (final entry in presetColors.entries) {
        await db.update(
          'idols',
          {'color_value': entry.value},
          where: 'color = ?',
          whereArgs: [entry.key],
        );
      }
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE events ADD COLUMN stable_id TEXT');
      final events = await db.query('events', columns: ['id']);
      for (final event in events) {
        await db.update(
          'events',
          {'stable_id': generateEventStableId()},
          where: 'id = ?',
          whereArgs: [event['id']],
        );
      }
      await db.execute(
        'CREATE UNIQUE INDEX idx_events_stable_id ON events(stable_id)',
      );
      await db.execute(
        'ALTER TABLE events ADD COLUMN is_online INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('''
        UPDATE events SET is_online = 1
        WHERE EXISTS (
          SELECT 1 FROM records r
          WHERE r.event_id = events.id AND r.is_online = 1
        )
        AND NOT EXISTS (
          SELECT 1 FROM records r
          WHERE r.event_id = events.id AND r.is_online = 0
        )
      ''');
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE records_v8 (
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
          group_name TEXT,
          FOREIGN KEY (idol_id) REFERENCES idols (id),
          FOREIGN KEY (event_id) REFERENCES events (id)
        )
      ''');
      await db.execute('''
        INSERT INTO records_v8 (
          id, idol_id, date, count, unit_price, subtotal, venue,
          created_at, event_id, is_online, record_type
        )
        SELECT id, idol_id, date, count, unit_price, subtotal, venue,
               created_at, event_id, is_online, 'normal'
        FROM records
      ''');
      await db.execute('DROP TABLE records');
      await db.execute('ALTER TABLE records_v8 RENAME TO records');
    }
    if (oldVersion < 9) {
      await db.execute('ALTER TABLE records ADD COLUMN group_members TEXT');
    }
  }

  String _generateStableId(Random random, int id) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final suffix = random.nextInt(0x7fffffff).toRadixString(16);
    return 'idol_${timestamp}_${id}_$suffix';
  }
}
