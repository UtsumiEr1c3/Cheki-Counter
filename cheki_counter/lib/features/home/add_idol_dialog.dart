import 'package:flutter/material.dart';
import 'package:cheki_counter/data/idol_repository.dart';
import 'package:cheki_counter/data/models/idol.dart';
import 'package:cheki_counter/data/models/record.dart';
import 'package:cheki_counter/shared/colors.dart';
import 'package:cheki_counter/shared/formatters.dart';

class AddIdolDialog extends StatefulWidget {
  const AddIdolDialog({super.key});

  @override
  State<AddIdolDialog> createState() => _AddIdolDialogState();
}

class _AddIdolDialogState extends State<AddIdolDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _groupController = TextEditingController();
  final _countController = TextEditingController();
  final _priceController = TextEditingController(text: '60');
  final _venueController = TextEditingController();
  late DateTime _selectedDate;
  String _selectedColor = presetColorNames.first;
  final _repo = IdolRepository();
  String? _tripleError;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _groupController.dispose();
    _countController.dispose();
    _priceController.dispose();
    _venueController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    setState(() => _tripleError = null);
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final color = _selectedColor;
    final group = _groupController.text.trim();

    // Check triple uniqueness
    final existing = await _repo.findByTriple(name, color, group);
    if (existing != null) {
      setState(() => _tripleError = '该偶像已存在,请直接在卡片上加记录');
      return;
    }

    final count = int.parse(_countController.text);
    final unitPrice = int.parse(_priceController.text);
    final now = DateTime.now();

    final idol = Idol(
      name: name,
      color: color,
      groupName: group,
      createdAt: now.toIso8601String(),
    );

    final record = CheckiRecord(
      idolId: 0, // will be set in transaction
      date: formatDate(_selectedDate),
      count: count,
      unitPrice: unitPrice,
      subtotal: count * unitPrice,
      venue: _venueController.text.trim(),
      createdAt: now.toIso8601String(),
    );

    await _repo.insertWithFirstRecord(idol, record);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建偶像'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '名字',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请填写名字';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Color picker - 4x5 grid
              const Text('应援色', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 4),
              _ColorGrid(
                selected: _selectedColor,
                onSelected: (c) => setState(() => _selectedColor = c),
              ),
              const SizedBox(height: 12),
              // Group
              TextFormField(
                controller: _groupController,
                decoration: const InputDecoration(
                  labelText: '团体',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请填写团体';
                  return null;
                },
              ),
              if (_tripleError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _tripleError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(),
              const Text('首条切奇记录',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              // Date picker
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '日期',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(formatDate(_selectedDate)),
                ),
              ),
              const SizedBox(height: 12),
              // Count
              TextFormField(
                controller: _countController,
                decoration: const InputDecoration(
                  labelText: '数量',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return '请填写数量';
                  final n = int.tryParse(v);
                  if (n == null || n <= 0) return '请输入正整数';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Unit price
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: '单价',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return '请填写单价';
                  final n = int.tryParse(v);
                  if (n == null || n <= 0) return '请输入正整数';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Venue
              TextFormField(
                controller: _venueController,
                decoration: const InputDecoration(
                  labelText: '场地',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请填写场地';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('确定'),
        ),
      ],
    );
  }
}

class _ColorGrid extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _ColorGrid({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final names = presetColorNames;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: names.length,
      itemBuilder: (context, index) {
        final name = names[index];
        final color = colorFor(name);
        final isSelected = name == selected;
        return GestureDetector(
          onTap: () => onSelected(name),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? Colors.black : Colors.grey[300]!,
                width: isSelected ? 3 : 1,
              ),
            ),
            child: isSelected
                ? Icon(Icons.check,
                    size: 16,
                    color:
                        color.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                : null,
          ),
        );
      },
    );
  }
}
