import 'package:flutter/material.dart';
import 'package:cheki_counter/data/event_repository.dart';
import 'package:cheki_counter/data/record_repository.dart';
import 'package:cheki_counter/data/models/event.dart';
import 'package:cheki_counter/features/events/event_cheki_dialog.dart';
import 'package:cheki_counter/features/events/event_group_cheki_dialog.dart';
import 'package:cheki_counter/features/events/edit_event_dialog.dart';
import 'package:cheki_counter/shared/colors.dart';

class EventDetailPage extends StatefulWidget {
  final int eventId;

  const EventDetailPage({super.key, required this.eventId});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  final _eventRepo = EventRepository();
  final _recordRepo = RecordRepository();
  CheckiEvent? _event;
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final event = await _eventRepo.getById(widget.eventId);
    final records = await _recordRepo.getByEventId(widget.eventId);
    if (!mounted) return;
    setState(() {
      _event = event;
      _records = records;
      _loading = false;
    });
  }

  Future<void> _openAddCheki(CheckiEvent event) async {
    final type = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_alt),
              title: const Text('添加个人切'),
              onTap: () => Navigator.pop(context, 'idol'),
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('添加团切'),
              onTap: () => Navigator.pop(context, 'group'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || type == null) return;
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => type == 'group'
          ? EventGroupChekiDialog(event: event)
          : EventChekiDialog(event: event),
    );
    if (added == true && mounted) {
      await _load();
    }
  }

  Future<void> _editEvent(CheckiEvent event) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => EditEventDialog(event: event),
    );
    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final event = _event;
    if (event == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('活动已不存在')),
      );
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final r in _records) {
      final isGroup = r['record_type'] == 'group';
      final key = isGroup
          ? 'group:${_groupDisplayName(r)}'
          : 'idol:${r['idol_id']}';
      grouped.putIfAbsent(key, () => []).add(r);
    }

    final totalCount = _records.fold<int>(0, (s, r) => s + (r['count'] as int));
    final totalAmount = _records.fold<int>(
      0,
      (s, r) => s + (r['subtotal'] as int),
    );
    final grandAmount = event.ticketPrice + totalAmount;

    return Scaffold(
      appBar: AppBar(
        title: Text(event.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '编辑活动',
            onPressed: () => _editEvent(event),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddCheki(event),
        icon: const Icon(Icons.add),
        label: const Text('添加切奇'),
      ),
      body: ListView(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text('${event.date} · ${event.venue}'),
                Text(event.isOnline ? '仅电切' : '现场参加'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text('共 $totalCount 切'),
                    Text('门票 ¥${event.ticketPrice}'),
                    Text('切 ¥$totalAmount'),
                    Text('合计 ¥$grandAmount'),
                  ],
                ),
              ],
            ),
          ),
          if (_records.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('暂无切奇记录')),
            )
          else
            ...grouped.entries.map((entry) {
              final rows = entry.value;
              final first = rows.first;
              final isGroup = first['record_type'] == 'group';
              final subjectName = isGroup
                  ? '${_groupDisplayName(first)}团切'
                  : first['idol_name'] as String;
              final idolColorValue = first['idol_color_value'] as int?;
              final groupCount = rows.fold<int>(
                0,
                (s, r) => s + (r['count'] as int),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Row(
                      children: [
                        if (isGroup)
                          const Icon(Icons.groups_outlined, size: 18)
                        else
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: colorFromValue(idolColorValue!),
                              shape: BoxShape.circle,
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          '$subjectName ×$groupCount',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...rows.map(
                    (r) => ListTile(
                      dense: true,
                      title: Text('${r['count']} 切 · ¥${r['subtotal']}'),
                      subtitle: Text(
                        isGroup
                            ? '${r['venue']}  单价¥${r['unit_price']}\n成员：${r['group_members']}'
                            : '${r['venue']}  单价¥${r['unit_price']}',
                      ),
                      isThreeLine: isGroup,
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  String _groupDisplayName(Map<String, dynamic> row) {
    final groupNames = row['group_names'] as String?;
    if (groupNames != null && groupNames.isNotEmpty) {
      return groupNames.split(RecordRepository.groupNamesSeparator).join(' / ');
    }
    return row['group_name'] as String? ?? '未命名团体';
  }
}
