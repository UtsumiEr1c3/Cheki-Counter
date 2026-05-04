import 'package:flutter/material.dart';
import 'package:cheki_counter/data/event_repository.dart';
import 'package:cheki_counter/data/models/event.dart';

/// An event name input with autocomplete from existing events.
/// On selection of an existing event, calls [onEventSelected] so the parent
/// can link venue/date fields.
class EventField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<CheckiEvent?> onEventSelected;

  const EventField({
    super.key,
    required this.controller,
    required this.onEventSelected,
  });

  @override
  State<EventField> createState() => _EventFieldState();
}

class _EventFieldState extends State<EventField> {
  final EventRepository _repo = EventRepository();
  final FocusNode _focusNode = FocusNode();
  List<CheckiEvent> _options = const [];

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final events = await _repo.getAll();
    if (!mounted) return;
    setState(() => _options = events);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<CheckiEvent>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      displayStringForOption: (e) => e.name,
      optionsBuilder: (TextEditingValue value) {
        if (_options.isEmpty) return const Iterable<CheckiEvent>.empty();
        final input = value.text;
        if (input.isEmpty) return _options;
        final lower = input.toLowerCase();
        return _options.where((e) => e.name.toLowerCase().contains(lower));
      },
      onSelected: (CheckiEvent e) {
        widget.onEventSelected(e);
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: '活动(可选)',
                border: OutlineInputBorder(),
              ),
              onFieldSubmitted: (_) => onFieldSubmitted(),
            );
          },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            option.ticketPrice > 0
                                ? '${option.date} · ${option.venue} · 票¥${option.ticketPrice}'
                                : '${option.date} · ${option.venue}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
