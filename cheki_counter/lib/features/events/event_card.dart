import 'package:flutter/material.dart';
import 'package:cheki_counter/data/event_repository.dart';
import 'package:cheki_counter/shared/colors.dart';

class EventCard extends StatelessWidget {
  final EventWithSummary summary;
  final VoidCallback? onTap;

  const EventCard({super.key, required this.summary, this.onTap});

  @override
  Widget build(BuildContext context) {
    final event = summary.event;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${event.date} · ${event.venue}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                event.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: summary.hasRecords
                        ? Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: summary.idolSummary
                                .map((e) => _IdolChip(entry: e))
                                .toList(),
                          )
                        : Text(
                            '(未切奇)',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _AmountText(label: '票', value: '¥${summary.ticketPrice}'),
                  _AmountText(
                    label: '切',
                    value: summary.hasRecords ? '¥${summary.totalAmount}' : '—',
                  ),
                  _AmountText(label: '合计', value: '¥${summary.grandAmount}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountText extends StatelessWidget {
  final String label;
  final String value;

  const _AmountText({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label $value',
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
  }
}

class _IdolChip extends StatelessWidget {
  final IdolSummaryEntry entry;

  const _IdolChip({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = colorFor(entry.color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text('${entry.name} ×${entry.count}'),
      ],
    );
  }
}
