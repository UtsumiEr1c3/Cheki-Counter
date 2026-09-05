import 'package:flutter/material.dart';
import 'package:cheki_counter/data/event_repository.dart';
import 'package:cheki_counter/data/models/event.dart';
import 'package:cheki_counter/data/record_repository.dart';
import 'package:cheki_counter/shared/formatters.dart';
import 'package:cheki_counter/shared/widgets/venue_field.dart';

class EditEventDialog extends StatefulWidget {
  final CheckiEvent event;

  const EditEventDialog({super.key, required this.event});

  @override
  State<EditEventDialog> createState() => _EditEventDialogState();
}

class _EditEventDialogState extends State<EditEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _eventRepo = EventRepository();
  final _recordRepo = RecordRepository();
  late final TextEditingController _nameController;
  late final TextEditingController _venueController;
  late final TextEditingController _ticketPriceController;
  late DateTime _selectedDate;
  late bool _isOnline;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _nameController = TextEditingController(text: event.name);
    _venueController = TextEditingController(text: event.venue);
    _ticketPriceController = TextEditingController(
      text: event.ticketPrice.toString(),
    );
    _selectedDate = DateTime.parse(event.date);
    _isOnline = event.isOnline;
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
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final venueInput = _venueController.text.trim();
    final venue =
        (await _recordRepo.canonicalVenueFor(venueInput)) ?? venueInput;
    final updated = CheckiEvent(
      id: widget.event.id,
      stableId: widget.event.stableId,
      name: _nameController.text.trim(),
      venue: venue,
      date: formatDate(_selectedDate),
      createdAt: widget.event.createdAt,
      ticketPrice: int.parse(_ticketPriceController.text.trim()),
      isOnline: _isOnline,
    );

    try {
      await _eventRepo.update(widget.event, updated);
      if (mounted) Navigator.of(context).pop(true);
    } on EventAlreadyExistsException {
      if (mounted) {
        setState(() {
          _error = '同名、同场地、同日期的活动已存在';
          _saving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = '保存失败，请稍后重试';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑活动'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '活动名',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? '请填写活动名'
                    : null,
              ),
              const SizedBox(height: 12),
              VenueField(
                controller: _venueController,
                validator: (value) => value == null || value.trim().isEmpty
                    ? '请填写场地'
                    : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _saving ? null : _pickDate,
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
                  labelText: '门票价格',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final price = int.tryParse(value?.trim() ?? '');
                  return price == null || price < 0 ? '请输入非负整数' : null;
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('仅电切活动'),
                subtitle: const Text('不计入现场参加场数和门票支出'),
                value: _isOnline,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _isOnline = value),
              ),
              if (_error != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 4),
              const Text(
                '修改日期或场地时，仍使用原活动日期或场地的关联记录会同步更新。',
                style: TextStyle(fontSize: 12),
              ),
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
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }
}
