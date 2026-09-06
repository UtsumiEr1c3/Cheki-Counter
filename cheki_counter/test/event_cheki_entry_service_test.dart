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

  test('活动个人切、新偶像首切和团切均接受零元单价', () async {
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
        'stable_id': 'event_free_cheki',
        'name': '赠送切活动',
        'venue': 'Wuhan MAO',
        'date': '2026-04-20',
        'created_at': '2026-04-01T00:00:00',
        'ticket_price': 0,
        'is_online': 0,
      }),
      name: '赠送切活动',
      venue: 'Wuhan MAO',
      date: '2026-04-20',
      createdAt: '2026-04-01T00:00:00',
    );
    final service = EventChekiEntryService();

    await service.addExistingIdolRecord(
      event: event,
      idol: (await idolRepo.findById(idolId))!,
      count: 1,
      unitPrice: 0,
      createdAt: '2026-04-20T12:00:00',
    );
    await service.createIdolWithEventRecord(
      event: event,
      name: 'Rin',
      color: '红色',
      colorValue: colorValueForName('红色'),
      groupName: 'EAUX',
      count: 1,
      unitPrice: 0,
      createdAt: '2026-04-20T12:01:00',
    );
    await service.addGroupRecord(
      event: event,
      groupNames: ['EAUX'],
      groupMembers: 'Aki、Rin',
      count: 1,
      unitPrice: 0,
      createdAt: '2026-04-20T12:02:00',
    );

    final records = await db.query(
      'records',
      where: 'event_id = ?',
      whereArgs: [event.id],
    );
    expect(records, hasLength(3));
    expect(records.every((row) => row['unit_price'] == 0), isTrue);
    expect(records.every((row) => row['subtotal'] == 0), isTrue);
  });

  test('团切关联活动并只计入团体和活动统计', () async {
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
        'stable_id': 'event_group_cheki',
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

    await EventChekiEntryService().addGroupRecord(
      event: event,
      groupNames: ['EAUX', 'Other'],
      groupMembers: 'Aki、Rin',
      count: 2,
      unitPrice: 80,
      createdAt: '2026-04-20T12:00:00',
    );

    final groupRecords = await db.query(
      'records',
      where: "record_type = 'group'",
    );
    final recordGroups = await db.query('record_groups', orderBy: 'position');
    final idol = await idolRepo.findById(idolId);
    final groups = await idolRepo.getGroupAggregates();
    final eventRows = await RecordRepository().getByEventId(event.id!);
    final suggestedMembers = await idolRepo.getSuggestedMemberNamesByGroup(
      'EAUX',
    );

    expect(groupRecords.single['idol_id'], isNull);
    expect(groupRecords.single['event_id'], event.id);
    expect(groupRecords.single['group_name'], 'EAUX');
    expect(groupRecords.single['group_members'], 'Aki、Rin');
    expect(recordGroups.map((row) => row['group_name']), ['EAUX', 'Other']);
    expect(recordGroups.map((row) => row['position']), [0, 1]);
    expect(idol!.totalCount, 0);
    final eaux = groups.singleWhere((row) => row['group_name'] == 'EAUX');
    final other = groups.singleWhere((row) => row['group_name'] == 'Other');
    expect(eaux['total_count'], 3);
    expect(eaux['total_amount'], 220);
    expect(other['total_count'], 2);
    expect(other['total_amount'], 160);
    expect(eventRows, hasLength(1));
    expect(eventRows.single['record_type'], 'group');
    expect(
      eventRows.single['group_names'],
      'EAUX${RecordRepository.groupNamesSeparator}Other',
    );
    expect(suggestedMembers, ['Aki', 'Rin']);
  });

  test('团切可使用新团体并保存成员快照', () async {
    final db = await DatabaseHelper.instance.database;
    final event = CheckiEvent(
      id: await db.insert('events', {
        'stable_id': 'event_new_group_cheki',
        'name': '新团首演',
        'venue': '上海',
        'date': '2026-05-01',
        'created_at': '2026-05-01T00:00:00',
        'ticket_price': 0,
        'is_online': 0,
      }),
      name: '新团首演',
      venue: '上海',
      date: '2026-05-01',
      createdAt: '2026-05-01T00:00:00',
      ticketPrice: 0,
    );

    await EventChekiEntryService().addGroupRecord(
      event: event,
      groupNames: ['新团体'],
      groupMembers: ' 小桃, 小凛、小桃 ',
      count: 1,
      unitPrice: 200,
      createdAt: '2026-05-01T12:00:00',
    );

    final record = (await db.query('records')).single;
    expect(record['group_name'], '新团体');
    expect(record['group_members'], '小桃、小凛');
    expect(await IdolRepository().getDistinctGroupNames(), ['新团体']);
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
