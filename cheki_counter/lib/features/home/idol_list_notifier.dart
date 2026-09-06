import 'package:flutter/foundation.dart';
import 'package:cheki_counter/data/idol_repository.dart';
import 'package:cheki_counter/data/models/idol.dart';
import 'package:cheki_counter/data/record_repository.dart';

class IdolListNotifier extends ChangeNotifier {
  final IdolRepository _repo = IdolRepository();
  final RecordRepository _recordRepo = RecordRepository();

  List<Idol> _idols = [];
  int _groupChekiCount = 0;
  int _groupChekiAmount = 0;
  List<Idol> get idols => _idols;

  String _sortBy = 'count'; // 'count' or 'amount'
  String get sortBy => _sortBy;

  int get totalIdols => _idols.length;
  int get totalCount =>
      _idols.fold(0, (sum, i) => sum + i.totalCount) + _groupChekiCount;
  int get totalAmount =>
      _idols.fold(0, (sum, i) => sum + i.totalAmount) + _groupChekiAmount;

  Future<void> load() async {
    _idols = await _repo.getAllWithAggregates(sortBy: _sortBy);
    final groupCheki = await _recordRepo.getAllGroupChekiAggregate();
    _groupChekiCount = groupCheki['total_count']!;
    _groupChekiAmount = groupCheki['total_amount']!;
    notifyListeners();
  }

  void setSortBy(String sortBy) {
    if (_sortBy == sortBy) return;
    _sortBy = sortBy;
    load();
  }

  void refresh() {
    load();
  }
}
