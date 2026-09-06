import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cheki_counter/features/home/idol_list_notifier.dart';
import 'package:cheki_counter/features/home/idol_card.dart';
import 'package:cheki_counter/features/home/add_idol_dialog.dart';
import 'package:cheki_counter/features/home/add_record_dialog.dart';
import 'package:cheki_counter/features/home/add_theme_cheki_dialog.dart';
import 'package:cheki_counter/features/events/add_event_dialog.dart';
import 'package:cheki_counter/features/events/events_overview_page.dart';

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
    final textScaler = MediaQuery.textScalerOf(context);
    final titleHeight = textScaler.scale(16) * 1.2 * 2;
    final statisticsHeight = textScaler.scale(14) * 1.2 * 2 + 4;
    final cardHeight =
        8 +
        24 +
        titleHeight +
        8 +
        statisticsHeight.clamp(48.0, double.infinity).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cheki Counter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event),
            tooltip: '偶活总览',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EventsOverviewPage()),
              );
              if (context.mounted) context.read<IdolListNotifier>().refresh();
            },
          ),
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
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 240,
                      mainAxisExtent: cardHeight,
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
                              'idolColorValue': idol.colorValue,
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
                              idolColorValue: idol.colorValue,
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
        onPressed: () => _showAddMenu(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddMenu(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('新建偶像'),
              onTap: () => Navigator.pop(ctx, 'idol'),
            ),
            ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text('新建活动(无偶像)'),
              onTap: () => Navigator.pop(ctx, 'event'),
            ),
            ListTile(
              leading: const Icon(Icons.celebration_outlined),
              title: const Text('添加主题切'),
              onTap: () => Navigator.pop(ctx, 'theme'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || choice == null) return;

    if (choice == 'idol') {
      await showDialog(context: context, builder: (_) => const AddIdolDialog());
    } else if (choice == 'event') {
      await showDialog(
        context: context,
        builder: (_) => const AddEventDialog(),
      );
    } else if (choice == 'theme') {
      await showDialog(
        context: context,
        builder: (_) => const AddThemeChekiDialog(),
      );
    }

    if (context.mounted) context.read<IdolListNotifier>().refresh();
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
