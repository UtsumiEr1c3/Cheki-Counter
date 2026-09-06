import 'package:flutter/material.dart';
import 'package:cheki_counter/data/idol_repository.dart';
import 'package:cheki_counter/data/models/event.dart';
import 'package:cheki_counter/data/models/idol.dart';
import 'package:cheki_counter/data/record_repository.dart';
import 'package:cheki_counter/features/events/event_cheki_entry_service.dart';
import 'package:cheki_counter/shared/colors.dart';
import 'package:cheki_counter/shared/widgets/idol_color_field.dart';

enum _EntryMode { existing, create }

class EventChekiDialog extends StatefulWidget {
  final CheckiEvent event;

  const EventChekiDialog({super.key, required this.event});

  @override
  State<EventChekiDialog> createState() => _EventChekiDialogState();
}

class _EventChekiDialogState extends State<EventChekiDialog> {
  final _formKey = GlobalKey<FormState>();
  final _idolRepo = IdolRepository();
  final _recordRepo = RecordRepository();
  final _service = EventChekiEntryService();

  final _nameController = TextEditingController();
  final _groupController = TextEditingController();
  final _countController = TextEditingController(text: '1');
  final _unitPriceController = TextEditingController(text: '60');

  _EntryMode _mode = _EntryMode.existing;
  List<Idol> _idols = [];
  int? _selectedIdolId;
  String _selectedColor = presetColorNames.first;
  int _selectedColorValue = colorValueForName(presetColorNames.first);
  bool _loadingIdols = true;
  bool _saving = false;
  String? _duplicateError;

  @override
  void initState() {
    super.initState();
    _loadIdols();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _groupController.dispose();
    _countController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadIdols() async {
    final idols = await _idolRepo.getAllForSelection();
    if (!mounted) return;
    setState(() {
      _idols = idols;
      _loadingIdols = false;
    });
  }

  Future<void> _onExistingIdolSelected(int? idolId) async {
    setState(() => _selectedIdolId = idolId);
    if (idolId == null) return;

    final lastPrice = await _recordRepo.lastUnitPriceOf(idolId);
    if (!mounted || lastPrice == null) return;
    setState(() => _unitPriceController.text = lastPrice.toString());
  }

  Future<void> _submit() async {
    setState(() => _duplicateError = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final count = int.parse(_countController.text.trim());
    final unitPrice = int.parse(_unitPriceController.text.trim());

    try {
      if (_mode == _EntryMode.existing) {
        final idol = _idols.firstWhere((i) => i.id == _selectedIdolId);
        await _service.addExistingIdolRecord(
          event: widget.event,
          idol: idol,
          count: count,
          unitPrice: unitPrice,
        );
      } else {
        await _service.createIdolWithEventRecord(
          event: widget.event,
          name: _nameController.text,
          color: _selectedColor,
          colorValue: _selectedColorValue,
          groupName: _groupController.text,
          count: count,
          unitPrice: unitPrice,
        );
      }
    } on DuplicateIdolForEventException {
      if (!mounted) return;
      setState(() {
        _duplicateError = '该偶像已存在，请改用已有偶像添加';
        _saving = false;
      });
      return;
    } finally {
      if (mounted && _saving) {
        setState(() => _saving = false);
      }
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加切奇'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EventContext(event: widget.event),
              const SizedBox(height: 16),
              SegmentedButton<_EntryMode>(
                segments: const [
                  ButtonSegment(
                    value: _EntryMode.existing,
                    label: Text('已有偶像'),
                    icon: Icon(Icons.person_search),
                  ),
                  ButtonSegment(
                    value: _EntryMode.create,
                    label: Text('新建偶像'),
                    icon: Icon(Icons.person_add_alt),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selected) {
                  setState(() {
                    _mode = selected.single;
                    _duplicateError = null;
                    if (_mode == _EntryMode.create) {
                      _unitPriceController.text = '60';
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_mode == _EntryMode.existing)
                _buildExistingIdolFields()
              else
                _buildNewIdolFields(),
              const SizedBox(height: 12),
              _buildRecordFields(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildExistingIdolFields() {
    if (_loadingIdols) {
      return const Center(child: CircularProgressIndicator());
    }

    return DropdownButtonFormField<int>(
      initialValue: _selectedIdolId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: '偶像',
        border: OutlineInputBorder(),
      ),
      items: _idols
          .map(
            (idol) => DropdownMenuItem(
              value: idol.id,
              child: Text('${idol.name} · ${idol.groupName} · ${idol.color}'),
            ),
          )
          .toList(),
      onChanged: _onExistingIdolSelected,
      validator: (value) => value == null ? '请选择偶像' : null,
    );
  }

  Widget _buildNewIdolFields() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: '名字',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return '请填写名字';
            return null;
          },
        ),
        const SizedBox(height: 12),
        IdolColorField(
          initialName: _selectedColor,
          initialColorValue: _selectedColorValue,
          onChanged: (selection) {
            _selectedColor = selection.name;
            _selectedColorValue = selection.colorValue;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _groupController,
          decoration: const InputDecoration(
            labelText: '团体',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return '请填写团体';
            return null;
          },
        ),
        if (_duplicateError != null) ...[
          const SizedBox(height: 8),
          Text(
            _duplicateError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildRecordFields() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _countController,
          decoration: const InputDecoration(
            labelText: '数量',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          validator: _positiveIntValidator,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _unitPriceController,
          decoration: const InputDecoration(
            labelText: '单价',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          validator: _nonNegativeIntValidator,
        ),
      ],
    );
  }

  String? _positiveIntValidator(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number <= 0) return '请输入正整数';
    return null;
  }

  String? _nonNegativeIntValidator(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number < 0) return '请输入非负整数';
    return null;
  }
}

class _EventContext extends StatelessWidget {
  final CheckiEvent event;

  const _EventContext({required this.event});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: '当前活动',
        border: OutlineInputBorder(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(event.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${event.date} · ${event.venue}'),
        ],
      ),
    );
  }
}
