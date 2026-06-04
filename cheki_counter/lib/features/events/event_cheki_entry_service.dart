import 'package:cheki_counter/data/idol_repository.dart';
import 'package:cheki_counter/data/models/event.dart';
import 'package:cheki_counter/data/models/idol.dart';
import 'package:cheki_counter/data/models/record.dart';
import 'package:cheki_counter/data/record_repository.dart';

class DuplicateIdolForEventException implements Exception {
  final Idol existing;

  DuplicateIdolForEventException(this.existing);
}

class EventChekiEntryService {
  final IdolRepository _idolRepo;
  final RecordRepository _recordRepo;

  EventChekiEntryService({
    IdolRepository? idolRepo,
    RecordRepository? recordRepo,
  }) : _idolRepo = idolRepo ?? IdolRepository(),
       _recordRepo = recordRepo ?? RecordRepository();

  Future<int> addExistingIdolRecord({
    required CheckiEvent event,
    required Idol idol,
    required int count,
    required int unitPrice,
    String? createdAt,
  }) async {
    _validateEvent(event);
    _validateIdol(idol);
    _validatePositive(count, 'count');
    _validatePositive(unitPrice, 'unitPrice');

    return _recordRepo.insert(
      CheckiRecord(
        idolId: idol.id!,
        date: event.date,
        count: count,
        unitPrice: unitPrice,
        subtotal: count * unitPrice,
        venue: event.venue,
        createdAt: createdAt ?? DateTime.now().toIso8601String(),
        eventId: event.id,
        isOnline: false,
      ),
    );
  }

  Future<int> createIdolWithEventRecord({
    required CheckiEvent event,
    required String name,
    required String color,
    required String groupName,
    required int count,
    required int unitPrice,
    String? createdAt,
  }) async {
    _validateEvent(event);
    _validatePositive(count, 'count');
    _validatePositive(unitPrice, 'unitPrice');

    final trimmedName = name.trim();
    final trimmedGroup = groupName.trim();
    final existing = await _idolRepo.findByTriple(
      trimmedName,
      color,
      trimmedGroup,
    );
    if (existing != null) {
      throw DuplicateIdolForEventException(existing);
    }

    final nowIso = createdAt ?? DateTime.now().toIso8601String();
    return _idolRepo.insertWithFirstRecord(
      Idol(
        name: trimmedName,
        color: color,
        groupName: trimmedGroup,
        createdAt: nowIso,
      ),
      CheckiRecord(
        idolId: 0,
        date: event.date,
        count: count,
        unitPrice: unitPrice,
        subtotal: count * unitPrice,
        venue: event.venue,
        createdAt: nowIso,
        eventId: event.id,
        isOnline: false,
      ),
    );
  }

  void _validateEvent(CheckiEvent event) {
    if (event.id == null) {
      throw ArgumentError.value(event.id, 'event.id', 'must not be null');
    }
  }

  void _validateIdol(Idol idol) {
    if (idol.id == null) {
      throw ArgumentError.value(idol.id, 'idol.id', 'must not be null');
    }
  }

  void _validatePositive(int value, String name) {
    if (value <= 0) {
      throw ArgumentError.value(value, name, 'must be positive');
    }
  }
}
