import 'package:flutter/foundation.dart';
import 'package:cheki_counter/data/idol_repository.dart';
import 'package:cheki_counter/data/models/idol.dart';

class IdolListNotifier extends ChangeNotifier {
  final IdolRepository _repo = IdolRepository();

  List<Idol> _idols = [];
  List<Idol> get idols => _idols;

  String _sortBy = 'count'; // 'count' or 'amount'
  String get sortBy => _sortBy;

  int get totalIdols => _idols.length;
  int get totalCount => _idols.fold(0, (sum, i) => sum + i.totalCount);
  int get totalAmount => _idols.fold(0, (sum, i) => sum + i.totalAmount);

  Future<void> load() async {
    _idols = await _repo.getAllWithAggregates(sortBy: _sortBy);
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
