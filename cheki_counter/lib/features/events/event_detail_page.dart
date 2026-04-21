import 'package:flutter/material.dart';
import 'package:cheki_counter/data/event_repository.dart';
import 'package:cheki_counter/data/record_repository.dart';
import 'package:cheki_counter/data/models/event.dart';
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
    final event = await _eventRepo.getById(widget.eventId);
    final records = await _recordRepo.getByEventId(widget.eventId);
    if (!mounted) return;
    setState(() {
      _event = event;
      _records = records;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final event = _event;
    if (event == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('活动已不存在')),
      );
    }

    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final r in _records) {
      final idolId = r['idol_id'] as int;
      grouped.putIfAbsent(idolId, () => []).add(r);
    }

    final totalCount = _records.fold<int>(
      0,
      (s, r) => s + (r['count'] as int),
    );
    final totalAmount = _records.fold<int>(
      0,
      (s, r) => s + (r['subtotal'] as int),
    );

    return Scaffold(
      appBar: AppBar(title: Text(event.name)),
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
                if (_records.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('共 $totalCount 切 · ¥$totalAmount'),
                ],
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
              final idolName = first['idol_name'] as String;
              final idolColor = first['idol_color'] as String;
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
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: colorFor(idolColor),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$idolName ×$groupCount',
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
                        '${r['venue']}  单价¥${r['unit_price']}',
                      ),
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }
}
