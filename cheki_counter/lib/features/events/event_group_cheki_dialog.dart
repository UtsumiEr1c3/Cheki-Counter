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
  final List<String> _selectedGroups = [];
  TextEditingController? _groupInputController;
  String? _groupError;
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

  Future<void> _addGroup(String rawGroupName) async {
    final groupName = rawGroupName.trim();
    if (groupName.isEmpty) return;
    if (!_selectedGroups.contains(groupName)) {
      setState(() {
        _selectedGroups.add(groupName);
        _groupError = null;
      });
    }
    _groupInputController?.clear();

    final names = await _idolRepo.getSuggestedMemberNamesByGroup(groupName);
    if (!mounted || !_selectedGroups.contains(groupName)) return;
    final merged = <String>[];
    final seen = <String>{};
    for (final name in [
      ..._membersController.text.split(RegExp(r'[,，、\n]')),
      ...names,
    ]) {
      final trimmed = name.trim();
      if (trimmed.isNotEmpty && seen.add(trimmed)) merged.add(trimmed);
    }
    _membersController.text = merged.join('、');
  }

  void _removeGroup(String groupName) {
    setState(() => _selectedGroups.remove(groupName));
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
    final pendingGroup = _groupInputController?.text.trim() ?? '';
    if (pendingGroup.isNotEmpty) await _addGroup(pendingGroup);
    if (_selectedGroups.isEmpty) {
      setState(() => _groupError = '请至少添加一个团体');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await _service.addGroupRecord(
      event: widget.event,
      groupNames: _selectedGroups,
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
                  final availableGroups = _groups.where(
                    (group) => !_selectedGroups.contains(group),
                  );
                  if (query.isEmpty) return availableGroups;
                  return availableGroups.where(
                    (group) => group.toLowerCase().contains(query),
                  );
                },
                onSelected: _addGroup,
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                      _groupInputController = controller;
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: '添加团体',
                          hintText: '选择或输入后按回车添加',
                          border: OutlineInputBorder(),
                        ).copyWith(errorText: _groupError),
                        onFieldSubmitted: _addGroup,
                      );
                    },
              ),
              if (_selectedGroups.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _selectedGroups
                        .map(
                          (group) => InputChip(
                            label: Text(group),
                            onDeleted: () => _removeGroup(group),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
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
