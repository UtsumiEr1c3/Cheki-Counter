import 'package:flutter/material.dart';
import 'package:cheki_counter/data/idol_repository.dart';

class GroupOverviewPage extends StatefulWidget {
  const GroupOverviewPage({super.key});

  @override
  State<GroupOverviewPage> createState() => _GroupOverviewPageState();
}

class _GroupOverviewPageState extends State<GroupOverviewPage> {
  final _repo = IdolRepository();
  List<Map<String, dynamic>> _groups = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final groups = await _repo.getGroupAggregates();
    if (mounted) setState(() => _groups = groups);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('团体总览')),
      body: _groups.isEmpty
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
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    title: Text(groupName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle:
                        Text('$idolCount 位偶像 · $totalCount 切 · ¥$totalAmount'),
                  ),
                );
              },
            ),
    );
  }
}
