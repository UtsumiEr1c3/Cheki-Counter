import 'package:flutter/material.dart';
import 'package:cheki_counter/data/idol_repository.dart';
import 'package:cheki_counter/data/models/idol.dart';
import 'package:cheki_counter/data/models/record.dart';
import 'package:cheki_counter/data/record_repository.dart';
import 'package:cheki_counter/shared/formatters.dart';

class AddThemeChekiDialog extends StatefulWidget {
  const AddThemeChekiDialog({super.key});

  @override
  State<AddThemeChekiDialog> createState() => _AddThemeChekiDialogState();
}

class _AddThemeChekiDialogState extends State<AddThemeChekiDialog> {
  final _formKey = GlobalKey<FormState>();
  final _idolRepo = IdolRepository();
  final _recordRepo = RecordRepository();
  final _nameController = TextEditingController();
  final _countController = TextEditingController(text: '1');
  final _priceController = TextEditingController(text: '60');
  List<Idol> _idols = [];
  int? _idolId;
  DateTime _date = DateTime.now();
  bool _isOnline = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadIdols();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _countController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadIdols() async {
    final idols = await _idolRepo.getAllForSelection();
    if (!mounted) return;
    setState(() {
      _idols = idols;
      _loading = false;
    });
  }

  Future<void> _selectIdol(int? id) async {
    setState(() => _idolId = id);
    if (id == null) return;
    final price = await _recordRepo.lastUnitPriceOf(id);
    if (mounted && price != null) {
      setState(() => _priceController.text = price.toString());
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final name = _nameController.text.trim();
    final count = int.parse(_countController.text.trim());
    final price = int.parse(_priceController.text.trim());
    await _recordRepo.insert(
      CheckiRecord(
        idolId: _idolId,
        date: formatDate(_date),
        count: count,
        unitPrice: price,
        subtotal: count * price,
        venue: _isOnline ? '电切' : name,
        createdAt: DateTime.now().toIso8601String(),
        isOnline: _isOnline,
        recordType: ChekiRecordType.theme,
        specialName: name,
      ),
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
      title: const Text('添加主题切'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loading)
                const CircularProgressIndicator()
              else
                DropdownButtonFormField<int>(
                  initialValue: _idolId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '偶像',
                    border: OutlineInputBorder(),
                  ),
                  items: _idols
                      .map(
                        (idol) => DropdownMenuItem(
                          value: idol.id,
                          child: Text('${idol.name} · ${idol.groupName}'),
                        ),
                      )
                      .toList(),
                  onChanged: _selectIdol,
                  validator: (value) => value == null ? '请选择偶像' : null,
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '主题名称',
                  hintText: '例如：春节主题切',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请填写主题名称' : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '日期',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(formatDate(_date)),
                ),
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('电切'),
                value: _isOnline,
                onChanged: (value) => setState(() => _isOnline = value),
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
