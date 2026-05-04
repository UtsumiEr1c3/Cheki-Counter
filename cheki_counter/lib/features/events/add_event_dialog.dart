import 'package:flutter/material.dart';
import 'package:cheki_counter/data/event_repository.dart';
import 'package:cheki_counter/data/record_repository.dart';
import 'package:cheki_counter/shared/formatters.dart';
import 'package:cheki_counter/shared/widgets/venue_field.dart';

class AddEventDialog extends StatefulWidget {
  const AddEventDialog({super.key});

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _venueController = TextEditingController();
  final _ticketPriceController = TextEditingController();
  late DateTime _selectedDate;
  final _eventRepo = EventRepository();
  final _recordRepo = RecordRepository();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _venueController.dispose();
    _ticketPriceController.dispose();
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
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final trimmedVenue = _venueController.text.trim();
    final canonicalVenue =
        (await _recordRepo.canonicalVenueFor(trimmedVenue)) ?? trimmedVenue;
    final date = formatDate(_selectedDate);
    final ticketPrice = _ticketPriceController.text.trim().isEmpty
        ? 0
        : int.parse(_ticketPriceController.text.trim());
    final now = DateTime.now().toIso8601String();

    await _eventRepo.upsertByTriple(
      name,
      canonicalVenue,
      date,
      now,
      ticketPrice: ticketPrice,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建活动'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '活动名',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请填写活动名';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              VenueField(
                controller: _venueController,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请填写场地';
                  return null;
                },
              ),
              const SizedBox(height: 12),
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
              TextFormField(
                controller: _ticketPriceController,
                decoration: const InputDecoration(
                  labelText: '门票价格(可选)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final text = v?.trim() ?? '';
                  if (text.isEmpty) return null;
                  final n = int.tryParse(text);
                  if (n == null || n < 0) return '请输入非负整数';
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
        FilledButton(onPressed: _submit, child: const Text('确定')),
      ],
    );
  }
}
