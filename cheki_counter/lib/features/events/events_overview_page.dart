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
  bool? _eventFilter = false;
  EventSpendingSummary? _spending;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final years = await _repo.getSpendingYears();
    if (_selectedYear != null && !years.contains(_selectedYear)) {
      _selectedYear = null;
    }
    final events = await _repo.getAllWithRecordsSummary(
      year: _selectedYear,
      isOnline: _eventFilter,
    );
    final spending = await _repo.getSpendingSummary(year: _selectedYear);
    if (!mounted) return;
    setState(() {
      _years = years;
      _events = events;
      _spending = spending;
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          bottom: const TabBar(
            tabs: [
              Tab(text: '活动'),
              Tab(text: '支出'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: SegmentedButton<bool?>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('现场')),
                            ButtonSegment(value: true, label: Text('电切')),
                            ButtonSegment(value: null, label: Text('全部')),
                          ],
                          selected: {_eventFilter},
                          onSelectionChanged: (value) {
                            setState(() => _eventFilter = value.first);
                            _load();
                          },
                        ),
                      ),
                      Expanded(
                        child: _events.isEmpty
                            ? const Center(child: Text('当前筛选下暂无活动'))
                            : ListView.builder(
                                itemCount: _events.length,
                                itemBuilder: (context, i) {
                                  final summary = _events[i];
                                  return EventCard(
                                    summary: summary,
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => EventDetailPage(
                                            eventId: summary.event.id!,
                                          ),
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
                  _SpendingPanel(summary: _spending!),
                ],
              ),
      ),
    );
  }
}

class _SpendingPanel extends StatelessWidget {
  final EventSpendingSummary summary;

  const _SpendingPanel({required this.summary});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text('累计支出'),
                const SizedBox(height: 4),
                Text(
                  '¥${summary.totalSpending}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _SpendingItem(
          icon: Icons.photo_camera_outlined,
          label: '全部切奇费用',
          value: '¥${summary.allChekiAmount}',
        ),
        _SpendingItem(
          icon: Icons.location_on_outlined,
          label: '现场切',
          value: '¥${summary.onsiteChekiAmount}',
        ),
        _SpendingItem(
          icon: Icons.phone_outlined,
          label: '电切',
          value: '¥${summary.onlineChekiAmount}',
        ),
        _SpendingItem(
          icon: Icons.confirmation_number_outlined,
          label: '现场活动门票',
          value: '¥${summary.onsiteTicketAmount}',
        ),
        _SpendingItem(
          icon: Icons.event_available_outlined,
          label: '现场参加',
          value: '${summary.onsiteEventCount} 场',
        ),
      ],
    );
  }
}

class _SpendingItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SpendingItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
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
