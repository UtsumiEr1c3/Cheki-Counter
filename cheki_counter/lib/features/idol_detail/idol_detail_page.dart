import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cheki_counter/data/record_repository.dart';
import 'package:cheki_counter/shared/colors.dart';

class IdolDetailPage extends StatefulWidget {
  final int idolId;
  final String idolName;
  final String idolColor;

  const IdolDetailPage({
    super.key,
    required this.idolId,
    required this.idolName,
    required this.idolColor,
  });

  @override
  State<IdolDetailPage> createState() => _IdolDetailPageState();
}

class _IdolDetailPageState extends State<IdolDetailPage> {
  final _repo = RecordRepository();
  List<IdolRecordRow> _records = [];
  bool _byMonth = false; // false = by day, true = by month

  int get _totalCount =>
      _records.fold<int>(0, (sum, row) => sum + row.record.count);
  int get _totalAmount =>
      _records.fold<int>(0, (sum, row) => sum + row.record.subtotal);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await _repo.listByIdol(widget.idolId);
    if (mounted) setState(() => _records = records);
  }

  Future<void> _deleteRecord(int recordId) async {
    final idolDeleted = await _repo.deleteAndCleanupIdolIfEmpty(recordId);
    if (idolDeleted) {
      if (mounted) Navigator.of(context).pop();
    } else {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final idolColor = colorFor(widget.idolColor);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.idolName),
        backgroundColor: idolColor.withAlpha(40),
      ),
      body: Column(
        children: [
          // Summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: idolColor.withAlpha(25),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(children: [
                  Text('$_totalCount',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text('总切数'),
                ]),
                Column(children: [
                  Text('¥$_totalAmount',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text('总金额'),
                ]),
              ],
            ),
          ),
          // Chart tab
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('按日'),
                  selected: !_byMonth,
                  onSelected: (_) => setState(() => _byMonth = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('按月'),
                  selected: _byMonth,
                  onSelected: (_) => setState(() => _byMonth = true),
                ),
              ],
            ),
          ),
          // Chart
          SizedBox(
            height: 200,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildChart(idolColor),
            ),
          ),
          const Divider(),
          // Records list
          Expanded(
            child: ListView.builder(
              itemCount: _records.length,
              itemBuilder: (context, index) {
                final row = _records[index];
                final r = row.record;
                final venueLine = '${r.venue}  单价¥${r.unitPrice}';
                final hasEvent =
                    row.eventName != null && row.eventName!.isNotEmpty;
                return ListTile(
                  title: Text('${r.date}  ${r.count}切 ¥${r.subtotal}'),
                  subtitle: hasEvent
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(row.eventName!),
                            Text(venueLine),
                          ],
                        )
                      : Text(venueLine),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmDelete(r.id!),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(int recordId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后无法恢复。如果是最后一条记录,偶像也会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteRecord(recordId);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(Color lineColor) {
    if (_records.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }
    if (_byMonth) {
      return _buildMonthlyChart(lineColor);
    } else {
      return _buildDailyChart(lineColor);
    }
  }

  Widget _buildDailyChart(Color lineColor) {
    // Aggregate by day from records (already loaded)
    final dayMap = <String, int>{};
    for (final row in _records) {
      final r = row.record;
      dayMap[r.date] = (dayMap[r.date] ?? 0) + r.count;
    }
    final sortedDays = dayMap.keys.toList()..sort();
    if (sortedDays.isEmpty) return const Center(child: Text('暂无数据'));

    final spots = <FlSpot>[];
    for (int i = 0; i < sortedDays.length; i++) {
      spots.add(FlSpot(i.toDouble(), dayMap[sortedDays[i]]!.toDouble()));
    }

    final chartColor = chartColorFor(lineColor);

    return LineChart(
      LineChartData(
        lineBarsData: [_makeLineBar(spots, chartColor)],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (sortedDays.length > 6)
                  ? (sortedDays.length / 4).ceilToDouble()
                  : 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= sortedDays.length) {
                  return const SizedBox.shrink();
                }
                final d = sortedDays[idx];
                return SideTitleWidget(
                  meta: meta,
                  child: Text(d.substring(5), style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 32),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildMonthlyChart(Color lineColor) {
    // Aggregate by month from records
    final monthMap = <String, int>{};
    for (final row in _records) {
      final r = row.record;
      final ym = r.date.substring(0, 7); // YYYY-MM
      monthMap[ym] = (monthMap[ym] ?? 0) + r.count;
    }
    if (monthMap.isEmpty) return const Center(child: Text('暂无数据'));

    final sortedMonths = monthMap.keys.toList()..sort();
    final firstMonth = _parseYm(sortedMonths.first);
    final lastMonth = _parseYm(sortedMonths.last);

    // Generate continuous month sequence
    final allMonths = <String>[];
    var cur = firstMonth;
    while (!cur.isAfter(lastMonth)) {
      allMonths
          .add('${cur.year}-${cur.month.toString().padLeft(2, '0')}');
      cur = DateTime(cur.year, cur.month + 1);
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < allMonths.length; i++) {
      final count = monthMap[allMonths[i]] ?? 0;
      spots.add(FlSpot(i.toDouble(), count.toDouble()));
    }

    return LineChart(
      LineChartData(
        lineBarsData: [_makeLineBar(spots, chartColorFor(lineColor))],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (allMonths.length > 6)
                  ? (allMonths.length / 4).ceilToDouble()
                  : 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= allMonths.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(allMonths[idx].substring(5),
                      style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 32),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  LineChartBarData _makeLineBar(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: false,
      color: color,
      barWidth: 2,
      dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(
        show: true,
        color: color.withAlpha(30),
      ),
    );
  }

  DateTime _parseYm(String ym) {
    final parts = ym.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }
}
