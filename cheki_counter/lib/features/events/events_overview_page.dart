import 'package:flutter/material.dart';
import 'package:cheki_counter/data/event_repository.dart';
import 'package:cheki_counter/features/events/event_card.dart';
import 'package:cheki_counter/features/events/event_detail_page.dart';

class EventsOverviewPage extends StatefulWidget {
  const EventsOverviewPage({super.key});

  @override
  State<EventsOverviewPage> createState() => _EventsOverviewPageState();
}

class _EventsOverviewPageState extends State<EventsOverviewPage> {
  final _repo = EventRepository();
  List<EventWithSummary> _events = [];
  List<String> _years = [];
  String? _selectedYear;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final years = await _repo.getDistinctYears();
    if (_selectedYear != null && !years.contains(_selectedYear)) {
      _selectedYear = null;
    }
    final events = await _repo.getAllWithRecordsSummary(year: _selectedYear);
    if (!mounted) return;
    setState(() {
      _years = years;
      _events = events;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalEvents = _events.length;
    final withRecords = _events.where((e) => e.hasRecords).length;
    final totalTicketAmount = _events.fold(0, (sum, e) => sum + e.ticketPrice);
    final totalChekiAmount = _events.fold(0, (sum, e) => sum + e.totalAmount);
    final grandAmount = _events.fold(0, (sum, e) => sum + e.grandAmount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('偶活总览'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedYear,
                items: [
                  const DropdownMenuItem(value: null, child: Text('全部')),
                  ..._years.map(
                    (y) => DropdownMenuItem(value: y, child: Text('$y年')),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _selectedYear = v);
                  _load();
                },
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
          ? const Center(child: Text('暂无活动'))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _events.length,
                    itemBuilder: (context, i) {
                      final s = _events[i];
                      return EventCard(
                        summary: s,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EventDetailPage(eventId: s.event.id!),
                            ),
                          );
                          if (mounted) _load();
                        },
                      );
                    },
                  ),
                ),
                EventTotalsBar(
                  totalEvents: totalEvents,
                  withRecords: withRecords,
                  totalTicketAmount: totalTicketAmount,
                  totalChekiAmount: totalChekiAmount,
                  grandAmount: grandAmount,
                ),
              ],
            ),
    );
  }
}

class EventTotalsBar extends StatelessWidget {
  final int totalEvents;
  final int withRecords;
  final int totalTicketAmount;
  final int totalChekiAmount;
  final int grandAmount;

  const EventTotalsBar({
    super.key,
    required this.totalEvents,
    required this.withRecords,
    required this.totalTicketAmount,
    required this.totalChekiAmount,
    required this.grandAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 4,
        children:
            [
                  Text('$totalEvents 场'),
                  Text('$withRecords 场有切奇'),
                  Text('门票 ¥$totalTicketAmount'),
                  Text('切 ¥$totalChekiAmount'),
                  Text('合计 ¥$grandAmount'),
                ]
                .map(
                  (w) => DefaultTextStyle.merge(
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    child: w,
                  ),
                )
                .toList(),
      ),
    );
  }
}
