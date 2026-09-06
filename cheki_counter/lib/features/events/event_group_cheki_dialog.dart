import 'package:flutter/material.dart';
import 'package:cheki_counter/data/idol_repository.dart';
import 'package:cheki_counter/data/models/event.dart';
import 'package:cheki_counter/features/events/event_cheki_entry_service.dart';

class EventGroupChekiDialog extends StatefulWidget {
  final CheckiEvent event;

  const EventGroupChekiDialog({super.key, required this.event});

  @override
  State<EventGroupChekiDialog> createState() => _EventGroupChekiDialogState();
}

class _EventGroupChekiDialogState extends State<EventGroupChekiDialog> {
  final _formKey = GlobalKey<FormState>();
  final _idolRepo = IdolRepository();
  final _service = EventChekiEntryService();
  final _membersController = TextEditingController();
  final _countController = TextEditingController(text: '1');
  final _priceController = TextEditingController(text: '60');
  List<String> _groups = [];
  String _group = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _membersController.dispose();
    _countController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _prefillMembers(String groupName) async {
    final names = await _idolRepo.getMemberNamesByGroup(groupName);
    if (!mounted || _group != groupName) return;
    _membersController.text = names.join('、');
  }

  Future<void> _loadGroups() async {
    final groups = await _idolRepo.getDistinctGroupNames();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await _service.addGroupRecord(
      event: widget.event,
      groupName: _group,
      groupMembers: _membersController.text,
      count: int.parse(_countController.text.trim()),
      unitPrice: int.parse(_priceController.text.trim()),
    );
    if (mounted) Navigator.pop(context, true);
  }

  String? _positiveInt(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    return number == null || number <= 0 ? '请输入正整数' : null;
  }

  String? _nonNegativeInt(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    return number == null || number < 0 ? '请输入非负整数' : null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加团切'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: '当前活动',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  '${widget.event.name}\n${widget.event.date} · ${widget.event.venue}',
                ),
              ),
              const SizedBox(height: 12),
              if (_loading) const LinearProgressIndicator(),
              if (_loading) const SizedBox(height: 12),
              Autocomplete<String>(
                optionsBuilder: (textEditingValue) {
                  final query = textEditingValue.text.trim().toLowerCase();
                  if (query.isEmpty) return _groups;
                  return _groups.where(
                    (group) => group.toLowerCase().contains(query),
                  );
                },
                onSelected: (value) {
                  _group = value;
                  _prefillMembers(value);
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: '团体',
                          hintText: '选择已有团体或输入新团体',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => _group = value,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? '请输入团体'
                            : null,
                      );
                    },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _membersController,
                decoration: const InputDecoration(
                  labelText: '当时成员',
                  hintText: '用顿号或逗号分隔，可自由增删',
                  border: OutlineInputBorder(),
                ),
                minLines: 1,
                maxLines: 3,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入当时成员' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _countController,
                decoration: const InputDecoration(
                  labelText: '数量',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: _positiveInt,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: '单价',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: _nonNegativeInt,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving || _loading ? null : _submit,
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
}
