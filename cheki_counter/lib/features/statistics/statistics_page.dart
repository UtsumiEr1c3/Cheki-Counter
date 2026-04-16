import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cheki_counter/data/idol_repository.dart';
import 'package:cheki_counter/data/record_repository.dart';
import 'package:cheki_counter/data/models/idol.dart';
import 'package:cheki_counter/shared/colors.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final _idolRepo = IdolRepository();
  final _recordRepo = RecordRepository();

  List<Idol> _idols = [];
  List<String> _years = [];
  String? _selectedYear; // null = all
  String _mode = 'count'; // 'count' or 'amount'

  @override
  void initState() {
    super.initState();
    _loadYears();
    _loadData();
  }

  Future<void> _loadYears() async {
    final years = await _recordRepo.getDistinctYears();
    if (mounted) setState(() => _years = years);
  }

  Future<void> _loadData() async {
    final idols = await _idolRepo.getAllWithAggregates(
      sortBy: _mode,
      year: _selectedYear,
    );
    if (mounted) setState(() => _idols = idols);
  }

  @override
  Widget build(BuildContext context) {
    final total = _mode == 'count'
        ? _idols.fold(0, (sum, i) => sum + i.totalCount)
        : _idols.fold(0, (sum, i) => sum + i.totalAmount);

    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Year dropdown + mode toggle
            Row(
              children: [
                // Year dropdown
                DropdownButton<String?>(
                  value: _selectedYear,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('全部')),
                    ..._years.map((y) =>
                        DropdownMenuItem(value: y, child: Text('$y年'))),
                  ],
                  onChanged: (v) {
                    _selectedYear = v;
                    _loadData();
                  },
                ),
                const Spacer(),
                // Mode toggle
                ChoiceChip(
                  label: const Text('按切数'),
                  selected: _mode == 'count',
                  onSelected: (_) {
                    _mode = 'count';
                    _loadData();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('按金额'),
                  selected: _mode == 'amount',
                  onSelected: (_) {
                    _mode = 'amount';
                    _loadData();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Pie chart
            if (_idols.isNotEmpty && total > 0) ...[
              SizedBox(
                height: 240,
                child: Row(
                  children: [
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          sections: _buildPieSections(total),
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Legend
                    SizedBox(
                      width: 140,
                      child: ListView(
                        shrinkWrap: true,
                        children: _idols.map((idol) {
                          final value = _mode == 'count'
                              ? idol.totalCount
                              : idol.totalAmount;
                          final pct =
                              total > 0 ? (value / total * 100) : 0.0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: colorFor(idol.color),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${idol.name} ${pct.toStringAsFixed(1)}%',
                                    style: const TextStyle(fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            // Ranking list
            const Text('排行榜',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._idols.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final idol = entry.value;
              final value = _mode == 'count'
                  ? '${idol.totalCount} 切'
                  : '¥${idol.totalAmount}';
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorFor(idol.color),
                  foregroundColor:
                      colorFor(idol.color).computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                  child: Text('$rank'),
                ),
                title: Text(idol.name),
                trailing: Text(value,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              );
            }),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(int total) {
    return _idols.map((idol) {
      final value =
          _mode == 'count' ? idol.totalCount : idol.totalAmount;
      final pct = total > 0 ? (value / total * 100) : 0.0;
      return PieChartSectionData(
        value: value.toDouble(),
        color: colorFor(idol.color),
        title: pct >= 5 ? '${pct.toStringAsFixed(1)}%' : '',
        titleStyle: const TextStyle(fontSize: 10, color: Colors.white),
        radius: 60,
      );
    }).toList();
  }
}
