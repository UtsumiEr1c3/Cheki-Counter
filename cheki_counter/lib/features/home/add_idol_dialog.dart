import 'package:flutter/material.dart';
import 'package:cheki_counter/data/event_repository.dart';
import 'package:cheki_counter/data/idol_repository.dart';
import 'package:cheki_counter/data/models/event.dart';
import 'package:cheki_counter/data/models/idol.dart';
import 'package:cheki_counter/data/models/record.dart';
import 'package:cheki_counter/data/record_repository.dart';
import 'package:cheki_counter/shared/colors.dart';
import 'package:cheki_counter/shared/formatters.dart';
import 'package:cheki_counter/shared/widgets/event_field.dart';
import 'package:cheki_counter/shared/widgets/venue_field.dart';

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
  final _eventController = TextEditingController();
  late DateTime _selectedDate;
  String _selectedColor = presetColorNames.first;
  bool _isOnline = false;
  final _repo = IdolRepository();
  final _recordRepo = RecordRepository();
  final _eventRepo = EventRepository();
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
    _eventController.dispose();
    super.dispose();
  }

  void _onEventSelected(CheckiEvent? e) {
    if (e == null) return;
    setState(() {
      if (!_isOnline) {
        _venueController.text = e.venue;
      }
      try {
        _selectedDate = DateTime.parse(e.date);
      } catch (_) {}
    });
  }

  Future<void> _onToggleOnline(bool on) async {
    if (on) {
      final canonical =
          (await _recordRepo.canonicalVenueFor('电切')) ?? '电切';
      if (!mounted) return;
      setState(() {
        _isOnline = true;
        _venueController.text = canonical;
      });
    } else {
      setState(() {
        _isOnline = false;
        _venueController.text = '';
      });
    }
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
    final nowIso = now.toIso8601String();
    final dateStr = formatDate(_selectedDate);

    final trimmedVenue = _venueController.text.trim();
    final canonicalVenue =
        (await _recordRepo.canonicalVenueFor(trimmedVenue)) ?? trimmedVenue;

    final eventName = _eventController.text.trim();
    int? eventId;
    if (eventName.isNotEmpty) {
      eventId = await _eventRepo.upsertByTriple(
        eventName,
        canonicalVenue,
        dateStr,
        nowIso,
      );
    }

    final idol = Idol(
      name: name,
      color: color,
      groupName: group,
      createdAt: nowIso,
    );

    final record = CheckiRecord(
      idolId: 0, // will be set in transaction
      date: dateStr,
      count: count,
      unitPrice: unitPrice,
      subtotal: count * unitPrice,
      venue: canonicalVenue,
      createdAt: nowIso,
      eventId: eventId,
      isOnline: _isOnline,
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
              const SizedBox(height: 4),
              // 电切 switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('电切'),
                value: _isOnline,
                onChanged: (v) => _onToggleOnline(v),
              ),
              const SizedBox(height: 4),
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
              // Venue — locked as "电切" when 电切 switch is ON
              if (_isOnline)
                TextFormField(
                  controller: _venueController,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: '场地',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.lock_outline, size: 18),
                  ),
                )
              else
                VenueField(
                  controller: _venueController,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '请填写场地';
                    return null;
                  },
                ),
              const SizedBox(height: 12),
              // Event (optional)
              EventField(
                controller: _eventController,
                onEventSelected: _onEventSelected,
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
