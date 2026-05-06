import 'package:flutter/material.dart';
import 'package:cheki_counter/data/idol_repository.dart';
import 'package:cheki_counter/data/models/idol.dart';
import 'package:cheki_counter/data/record_repository.dart';
import 'package:cheki_counter/shared/colors.dart';

class GroupDetailPage extends StatefulWidget {
  final String groupName;
  final String? initialYear;

  const GroupDetailPage({super.key, required this.groupName, this.initialYear});

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  final _idolRepo = IdolRepository();
  final _recordRepo = RecordRepository();

  List<Idol> _idols = [];
  List<String> _years = [];
  late String? _selectedYear;
  String _sortBy = 'count';

  int get _totalCount =>
      _idols.fold<int>(0, (sum, idol) => sum + idol.totalCount);
  int get _totalAmount =>
      _idols.fold<int>(0, (sum, idol) => sum + idol.totalAmount);

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear;
    _loadYears();
    _loadData();
  }

  Future<void> _loadYears() async {
    final years = await _recordRepo.getDistinctYears();
    if (mounted) setState(() => _years = years);
  }

  Future<void> _loadData() async {
    final idols = await _idolRepo.getByGroupWithAggregates(
      groupName: widget.groupName,
      sortBy: _sortBy,
      year: _selectedYear,
    );
    if (mounted) setState(() => _idols = idols);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.groupName)),
      body: Column(
        children: [
          _buildControls(),
          _buildSummary(context),
          const Divider(height: 1),
          Expanded(
            child: _idols.isEmpty
                ? const Center(child: Text('当前筛选下暂无数据'))
                : ListView.builder(
                    itemCount: _idols.length,
                    itemBuilder: (context, index) {
                      return _buildIdolTile(_idols[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
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
              _loadData();
            },
          ),
          const Spacer(),
          ChoiceChip(
            label: const Text('按切数'),
            selected: _sortBy == 'count',
            onSelected: (_) {
              setState(() => _sortBy = 'count');
              _loadData();
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('按金额'),
            selected: _sortBy == 'amount',
            onSelected: (_) {
              setState(() => _sortBy = 'amount');
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(label: '偶像数', value: '${_idols.length}'),
          _SummaryItem(label: '总切数', value: '$_totalCount'),
          _SummaryItem(label: '总金额', value: '¥$_totalAmount'),
        ],
      ),
    );
  }

  Widget _buildIdolTile(Idol idol) {
    final idolColor = colorFor(idol.color);
    final textColor = idolColor.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: idolColor,
        foregroundColor: textColor,
        child: Text(idol.name.isEmpty ? '?' : idol.name.substring(0, 1)),
      ),
      title: Text(idol.name),
      subtitle: Text(idol.color),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${idol.totalCount} 切',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('¥${idol.totalAmount}'),
        ],
      ),
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
        _loadYears();
        _loadData();
      },
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
