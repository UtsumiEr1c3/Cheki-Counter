import 'package:cheki_counter/data/models/record.dart';
import 'package:cheki_counter/data/record_repository.dart';
import 'package:cheki_counter/features/events/event_detail_page.dart';
import 'package:cheki_counter/features/idol_detail/idol_detail_page.dart';
import 'package:flutter/material.dart';

class SpendingRecordsPage extends StatefulWidget {
  final SpendingRecordFilter filter;
  final String? year;

  const SpendingRecordsPage({super.key, required this.filter, this.year});

  @override
  State<SpendingRecordsPage> createState() => _SpendingRecordsPageState();
}

class _SpendingRecordsPageState extends State<SpendingRecordsPage> {
  final _repo = RecordRepository();
  List<SpendingRecordRow> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final records = await _repo.listForSpending(
      year: widget.year,
      filter: widget.filter,
    );
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  Future<void> _openRecord(SpendingRecordRow row) async {
    final record = row.record;
    if (record.eventId != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailPage(eventId: record.eventId!),
        ),
      );
    } else if (record.idolId != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IdolDetailPage(
            idolId: record.idolId!,
            idolName: row.idolName ?? '偶像',
            idolColor: row.idolColor ?? '',
            idolColorValue: row.idolColorValue ?? 0,
          ),
        ),
      );
    }
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final yearLabel = widget.year == null ? '' : ' · ${widget.year}年';
    return Scaffold(
      appBar: AppBar(title: Text('${_filterLabel(widget.filter)}$yearLabel')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
          ? const Center(child: Text('当前筛选下暂无切奇记录'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _records.length,
                itemBuilder: (context, index) {
                  final row = _records[index];
                  return SpendingRecordTile(
                    row: row,
                    onTap: () => _openRecord(row),
                  );
                },
              ),
            ),
    );
  }
}

class SpendingRecordTile extends StatelessWidget {
  final SpendingRecordRow row;
  final VoidCallback onTap;

  const SpendingRecordTile({super.key, required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final record = row.record;
    final details = <String>[
      '${record.recordType.label} · ${record.date}',
      if (record.recordType == ChekiRecordType.theme)
        '主题：${record.specialName ?? '未命名主题切'}',
      '${record.count} 切 · 单价 ¥${record.unitPrice} · ${record.isOnline ? '电切' : '现场'}',
      if (row.eventName != null) '活动：${row.eventName}',
    ];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(_recordIcon(record.recordType)),
        title: Text(_recordTitle(row)),
        subtitle: Text(details.join('\n')),
        isThreeLine: details.length >= 3,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¥${record.subtotal}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _recordTitle(SpendingRecordRow row) {
    final record = row.record;
    return switch (record.recordType) {
      ChekiRecordType.normal => row.idolName ?? '未知偶像',
      ChekiRecordType.theme => row.idolName ?? '未知偶像',
      ChekiRecordType.group => record.groupDisplayName ?? '未命名团体',
    };
  }

  IconData _recordIcon(ChekiRecordType type) {
    return switch (type) {
      ChekiRecordType.normal => Icons.person_outline,
      ChekiRecordType.theme => Icons.celebration_outlined,
      ChekiRecordType.group => Icons.groups_outlined,
    };
  }
}

String _filterLabel(SpendingRecordFilter filter) {
  return switch (filter) {
    SpendingRecordFilter.all => '全部切奇明细',
    SpendingRecordFilter.normal => '普通切明细',
    SpendingRecordFilter.theme => '主题切明细',
    SpendingRecordFilter.group => '团切明细',
    SpendingRecordFilter.onsite => '现场切明细',
    SpendingRecordFilter.online => '电切明细',
  };
}
