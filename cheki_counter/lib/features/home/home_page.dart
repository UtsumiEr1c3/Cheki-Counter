import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cheki_counter/features/home/idol_list_notifier.dart';
import 'package:cheki_counter/features/home/idol_card.dart';
import 'package:cheki_counter/features/home/add_idol_dialog.dart';
import 'package:cheki_counter/features/home/add_record_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    context.read<IdolListNotifier>().load();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<IdolListNotifier>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cheki Counter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: '统计',
            onPressed: () async {
              await Navigator.pushNamed(context, '/statistics');
              if (context.mounted) context.read<IdolListNotifier>().refresh();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () async {
              await Navigator.pushNamed(context, '/settings');
              if (context.mounted) context.read<IdolListNotifier>().refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryItem(label: '总切数', value: '${notifier.totalCount}'),
                _SummaryItem(label: '偶像数', value: '${notifier.totalIdols}'),
                _SummaryItem(label: '总金额', value: '¥${notifier.totalAmount}'),
              ],
            ),
          ),
          // Sort controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('排序: '),
                ChoiceChip(
                  label: const Text('按切数'),
                  selected: notifier.sortBy == 'count',
                  onSelected: (_) => notifier.setSortBy('count'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('按金额'),
                  selected: notifier.sortBy == 'amount',
                  onSelected: (_) => notifier.setSortBy('amount'),
                ),
              ],
            ),
          ),
          // Idol grid
          Expanded(
            child: notifier.idols.isEmpty
                ? const Center(child: Text('暂无数据,点击右下角 + 新建偶像'))
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.9,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: notifier.idols.length,
                    itemBuilder: (context, index) {
                      final idol = notifier.idols[index];
                      return IdolCard(
                        idol: idol,
                        onTap: () async {
                          await Navigator.pushNamed(
                            context,
                            '/idol-detail',
                            arguments: {
                              'idolId': idol.id,
                              'idolName': idol.name,
                              'idolColor': idol.color,
                            },
                          );
                          if (context.mounted) {
                            context.read<IdolListNotifier>().refresh();
                          }
                        },
                        onAddRecord: () async {
                          await showDialog(
                            context: context,
                            builder: (_) => AddRecordDialog(
                              idolId: idol.id!,
                              idolName: idol.name,
                              idolColor: idol.color,
                              idolGroup: idol.groupName,
                            ),
                          );
                          if (context.mounted) {
                            context.read<IdolListNotifier>().refresh();
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showDialog(
            context: context,
            builder: (_) => const AddIdolDialog(),
          );
          if (context.mounted) context.read<IdolListNotifier>().refresh();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
