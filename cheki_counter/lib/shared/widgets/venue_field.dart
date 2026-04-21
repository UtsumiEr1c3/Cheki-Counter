import 'package:flutter/material.dart';
import 'package:cheki_counter/data/record_repository.dart';

/// A venue input that surfaces historical venues via [Autocomplete],
/// filtering by case-insensitive substring and ordering by most recent use.
///
/// The passed-in [controller] is used directly as Autocomplete's text
/// controller, so parents read the same controller at submit time just like
/// they would with a plain [TextFormField].
class VenueField extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const VenueField({
    super.key,
    required this.controller,
    this.validator,
  });

  @override
  State<VenueField> createState() => _VenueFieldState();
}

class _VenueFieldState extends State<VenueField> {
  final RecordRepository _repo = RecordRepository();
  final FocusNode _focusNode = FocusNode();
  List<String> _options = const [];

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final venues = await _repo.getDistinctVenues();
    if (!mounted) return;
    setState(() => _options = venues);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (TextEditingValue value) {
        if (_options.isEmpty) return const Iterable<String>.empty();
        final input = value.text;
        if (input.isEmpty) return _options;
        final lower = input.toLowerCase();
        return _options.where((v) => v.toLowerCase().contains(lower));
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: '场地',
            border: OutlineInputBorder(),
          ),
          validator: widget.validator,
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
                          horizontal: 16, vertical: 12),
                      child: Text(option),
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
