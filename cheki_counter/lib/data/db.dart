import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'cheki_counter.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
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
        is_online INTEGER NOT NULL DEFAULT 0,
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
  }
}
