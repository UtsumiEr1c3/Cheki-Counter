import 'package:flutter/material.dart';
import 'package:cheki_counter/data/idol_repository.dart';
import 'package:cheki_counter/data/record_repository.dart';
import 'package:cheki_counter/features/statistics/group_detail_page.dart';

class GroupOverviewPage extends StatefulWidget {
  const GroupOverviewPage({super.key});

  @override
  State<GroupOverviewPage> createState() => _GroupOverviewPageState();
}

class _GroupOverviewPageState extends State<GroupOverviewPage> {
  final _idolRepo = IdolRepository();
  final _recordRepo = RecordRepository();
  List<Map<String, dynamic>> _groups = [];
  List<String> _years = [];
  String? _selectedYear;

  @override
  void initState() {
    super.initState();
    _loadYears();
    _load();
  }

  Future<void> _loadYears() async {
    final years = await _recordRepo.getDistinctYears();
    if (mounted) setState(() => _years = years);
  }

  Future<void> _load() async {
    final groups = await _idolRepo.getGroupAggregates(year: _selectedYear);
    if (mounted) setState(() => _groups = groups);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('团体总览')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                DropdownButton<String?>(
                  value: _selectedYear,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('全部')),
                    ..._years.map(
                      (y) => DropdownMenuItem(value: y, child: Text('$y年')),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedYear = value);
                    _load();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _groups.isEmpty
                ? const Center(child: Text('暂无数据'))
                : ListView.builder(
                    itemCount: _groups.length,
                    itemBuilder: (context, index) {
                      final g = _groups[index];
                      final groupName = g['group_name'] as String;
                      final idolCount = g['idol_count'] as int;
                      final totalCount = g['total_count'] as int;
                      final totalAmount = g['total_amount'] as int;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: ListTile(
                          title: Text(
                            groupName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '$idolCount 位偶像 · $totalCount 切 · ¥$totalAmount',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GroupDetailPage(
                                  groupName: groupName,
                                  initialYear: _selectedYear,
                                ),
                              ),
                            );
                            _loadYears();
                            _load();
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
