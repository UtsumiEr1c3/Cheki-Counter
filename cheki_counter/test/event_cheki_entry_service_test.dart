import 'package:cheki_counter/data/db.dart';
import 'package:cheki_counter/data/idol_repository.dart';
import 'package:cheki_counter/data/models/event.dart';
import 'package:cheki_counter/data/models/idol.dart';
import 'package:cheki_counter/data/models/record.dart';
import 'package:cheki_counter/data/record_repository.dart';
import 'package:cheki_counter/features/events/event_cheki_entry_service.dart';
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

  test('IdolRepository lists idols for event selection by name', () async {
    final repo = IdolRepository();

    await repo.insertWithFirstRecord(
      Idol(
        name: 'Momo',
        color: '粉色',
        colorValue: colorValueForName('粉色'),
        groupName: 'EAUX',
        createdAt: '2026-01-01T00:00:00',
      ),
      CheckiRecord(
        idolId: 0,
        date: '2026-01-01',
        count: 1,
        unitPrice: 60,
        subtotal: 60,
        venue: 'Shanghai',
        createdAt: '2026-01-01T00:00:01',
      ),
    );
    await repo.insertWithFirstRecord(
      Idol(
        name: 'Aki',
        color: '蓝色',
        colorValue: colorValueForName('蓝色'),
        groupName: 'EAUX',
        createdAt: '2026-01-02T00:00:00',
      ),
      CheckiRecord(
        idolId: 0,
        date: '2026-01-02',
        count: 1,
        unitPrice: 60,
        subtotal: 60,
        venue: 'Shanghai',
        createdAt: '2026-01-02T00:00:01',
      ),
    );

    final idols = await repo.getAllForSelection();

    expect(idols.map((idol) => idol.name), ['Aki', 'Momo']);
  });

  test('adds an existing idol record scoped to the current event', () async {
    final db = await DatabaseHelper.instance.database;
    final idolRepo = IdolRepository();
    final idolId = await idolRepo.insertWithFirstRecord(
      Idol(
        name: 'Aki',
        color: '蓝色',
        colorValue: colorValueForName('蓝色'),
        groupName: 'EAUX',
        createdAt: '2026-01-01T00:00:00',
      ),
      CheckiRecord(
        idolId: 0,
        date: '2026-01-01',
        count: 1,
        unitPrice: 60,
        subtotal: 60,
        venue: 'Shanghai',
        createdAt: '2026-01-01T00:00:01',
      ),
    );
    final event = CheckiEvent(
      id: await db.insert('events', {
        'stable_id': 'event_existing_idol',
        'name': 'VoltFes',
        'venue': 'Wuhan MAO',
        'date': '2026-04-20',
        'created_at': '2026-04-01T00:00:00',
        'ticket_price': 180,
        'is_online': 0,
      }),
      name: 'VoltFes',
      venue: 'Wuhan MAO',
      date: '2026-04-20',
      createdAt: '2026-04-01T00:00:00',
      ticketPrice: 180,
    );

    await EventChekiEntryService().addExistingIdolRecord(
      event: event,
      idol: Idol(
        id: idolId,
        name: 'Aki',
        color: '蓝色',
        colorValue: colorValueForName('蓝色'),
        groupName: 'EAUX',
        createdAt: '2026-01-01T00:00:00',
      ),
      count: 3,
      unitPrice: 70,
      createdAt: '2026-04-20T12:00:00',
    );

    final records = await db.query(
      'records',
      where: 'event_id = ?',
      whereArgs: [event.id],
    );

    expect(records, hasLength(1));
    expect(records.single['idol_id'], idolId);
    expect(records.single['date'], '2026-04-20');
    expect(records.single['venue'], 'Wuhan MAO');
    expect(records.single['count'], 3);
    expect(records.single['unit_price'], 70);
    expect(records.single['subtotal'], 210);
    expect(records.single['is_online'], 0);
  });

  test(
    'creates a new idol with a first record scoped to the current event',
    () async {
      final db = await DatabaseHelper.instance.database;
      final event = CheckiEvent(
        id: await db.insert('events', {
          'stable_id': 'event_new_idol',
          'name': 'VoltFes',
          'venue': 'Wuhan MAO',
          'date': '2026-04-20',
          'created_at': '2026-04-01T00:00:00',
          'ticket_price': 180,
          'is_online': 0,
        }),
        name: 'VoltFes',
        venue: 'Wuhan MAO',
        date: '2026-04-20',
        createdAt: '2026-04-01T00:00:00',
        ticketPrice: 180,
      );

      final idolId = await EventChekiEntryService().createIdolWithEventRecord(
        event: event,
        name: 'Rin',
        color: '星空蓝',
        colorValue: 0xFF3478F6,
        groupName: 'EAUX',
        count: 2,
        unitPrice: 80,
        createdAt: '2026-04-20T12:00:00',
      );

      final idols = await db.query(
        'idols',
        where: 'id = ?',
        whereArgs: [idolId],
      );
      final records = await db.query(
        'records',
        where: 'idol_id = ?',
        whereArgs: [idolId],
      );

      expect(idols.single['name'], 'Rin');
      expect(idols.single['color'], '星空蓝');
      expect(idols.single['color_value'], 0xFF3478F6);
      expect(idols.single['stable_id'], isA<String>());
      expect(idols.single['stable_id'], isNotEmpty);
      expect(records, hasLength(1));
      expect(records.single['event_id'], event.id);
      expect(records.single['date'], '2026-04-20');
      expect(records.single['venue'], 'Wuhan MAO');
      expect(records.single['subtotal'], 160);
      expect(records.single['is_online'], 0);

      final eventRows = await RecordRepository().getByEventId(event.id!);
      expect(eventRows.single['idol_color'], '星空蓝');
      expect(eventRows.single['idol_color_value'], 0xFF3478F6);
    },
  );

  test(
    'rejects duplicate idol triples in event-scoped new idol flow',
    () async {
      final db = await DatabaseHelper.instance.database;
      final event = CheckiEvent(
        id: await db.insert('events', {
          'stable_id': 'event_duplicate_idol',
          'name': 'VoltFes',
          'venue': 'Wuhan MAO',
          'date': '2026-04-20',
          'created_at': '2026-04-01T00:00:00',
          'ticket_price': 180,
          'is_online': 0,
        }),
        name: 'VoltFes',
        venue: 'Wuhan MAO',
        date: '2026-04-20',
        createdAt: '2026-04-01T00:00:00',
        ticketPrice: 180,
      );
      await EventChekiEntryService().createIdolWithEventRecord(
        event: event,
        name: 'Rin',
        color: '红色',
        colorValue: colorValueForName('红色'),
        groupName: 'EAUX',
        count: 2,
        unitPrice: 80,
        createdAt: '2026-04-20T12:00:00',
      );

      expect(
        () => EventChekiEntryService().createIdolWithEventRecord(
          event: event,
          name: 'Rin',
          color: '红色',
          colorValue: colorValueForName('红色'),
          groupName: 'EAUX',
          count: 1,
          unitPrice: 80,
          createdAt: '2026-04-20T12:01:00',
        ),
        throwsA(isA<DuplicateIdolForEventException>()),
      );

      expect(await db.query('idols'), hasLength(1));
      expect(await db.query('records'), hasLength(1));
    },
  );

  test(
    'updates idol profile without changing id, stable id, or records',
    () async {
      final db = await DatabaseHelper.instance.database;
      final repo = IdolRepository();
      final idolId = await repo.insertWithFirstRecord(
        Idol(
          name: 'Aki',
          color: '蓝色',
          colorValue: colorValueForName('蓝色'),
          groupName: 'EAUX',
          createdAt: '2026-01-01T00:00:00',
        ),
        CheckiRecord(
          idolId: 0,
          date: '2026-01-01',
          count: 2,
          unitPrice: 60,
          subtotal: 120,
          venue: 'Shanghai',
          createdAt: '2026-01-01T00:00:01',
        ),
      );
      final before = (await db.query(
        'idols',
        where: 'id = ?',
        whereArgs: [idolId],
      )).single;

      await repo.updateCurrentProfile(
        idolId: idolId,
        name: 'Aki',
        color: '红色',
        colorValue: colorValueForName('红色'),
        groupName: 'New EAUX',
      );

      final after = (await db.query(
        'idols',
        where: 'id = ?',
        whereArgs: [idolId],
      )).single;
      final records = await db.query('records');

      expect(after['id'], before['id']);
      expect(after['stable_id'], before['stable_id']);
      expect(after['color'], '红色');
      expect(after['color_value'], colorValueForName('红色'));
      expect(after['group_name'], 'New EAUX');
      expect(records.single['idol_id'], idolId);
    },
  );

  test('rejects editing idol profile to another idol triple', () async {
    final repo = IdolRepository();
    final firstId = await repo.insertWithFirstRecord(
      Idol(
        name: 'Aki',
        color: '蓝色',
        colorValue: colorValueForName('蓝色'),
        groupName: 'EAUX',
        createdAt: '2026-01-01T00:00:00',
      ),
      CheckiRecord(
        idolId: 0,
        date: '2026-01-01',
        count: 1,
        unitPrice: 60,
        subtotal: 60,
        venue: 'Shanghai',
        createdAt: '2026-01-01T00:00:01',
      ),
    );
    final secondId = await repo.insertWithFirstRecord(
      Idol(
        name: 'Rin',
        color: '红色',
        colorValue: colorValueForName('红色'),
        groupName: 'Other',
        createdAt: '2026-01-02T00:00:00',
      ),
      CheckiRecord(
        idolId: 0,
        date: '2026-01-02',
        count: 1,
        unitPrice: 60,
        subtotal: 60,
        venue: 'Shanghai',
        createdAt: '2026-01-02T00:00:01',
      ),
    );

    expect(
      () => repo.updateCurrentProfile(
        idolId: secondId,
        name: 'Aki',
        color: '蓝色',
        colorValue: colorValueForName('蓝色'),
        groupName: 'EAUX',
      ),
      throwsA(isA<DuplicateIdolTripleException>()),
    );
    expect((await repo.findById(firstId))!.name, 'Aki');
    expect((await repo.findById(secondId))!.name, 'Rin');
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
