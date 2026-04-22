import 'package:flutter/material.dart';
import 'package:cheki_counter/data/db.dart';
import 'package:cheki_counter/data/event_repository.dart';
import 'package:cheki_counter/data/record_repository.dart';
import 'package:cheki_counter/data/models/event.dart';
import 'package:cheki_counter/data/models/record.dart';
import 'package:cheki_counter/shared/colors.dart';
import 'package:cheki_counter/shared/formatters.dart';
import 'package:cheki_counter/shared/widgets/venue_field.dart';
import 'package:cheki_counter/shared/widgets/event_field.dart';

class AddRecordDialog extends StatefulWidget {
  final int idolId;
  final String idolName;
  final String idolColor;
  final String idolGroup;

  const AddRecordDialog({
    super.key,
    required this.idolId,
    required this.idolName,
    required this.idolColor,
    required this.idolGroup,
  });

  @override
  State<AddRecordDialog> createState() => _AddRecordDialogState();
}

class _AddRecordDialogState extends State<AddRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _countController = TextEditingController();
  final _priceController = TextEditingController();
  final _venueController = TextEditingController();
  final _eventController = TextEditingController();
  late DateTime _selectedDate;
  bool _isOnline = false;
  final _repo = RecordRepository();
  final _eventRepo = EventRepository();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadDefaultPrice();
  }

  Future<void> _loadDefaultPrice() async {
    final lastPrice = await _repo.lastUnitPriceOf(widget.idolId);
    _priceController.text = (lastPrice ?? 60).toString();
  }

  @override
  void dispose() {
    _countController.dispose();
    _priceController.dispose();
    _venueController.dispose();
    _eventController.dispose();
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
          (await _repo.canonicalVenueFor('电切')) ?? '电切';
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final count = int.parse(_countController.text);
    final unitPrice = int.parse(_priceController.text);
    final now = DateTime.now();
    final nowIso = now.toIso8601String();

    final trimmedVenue = _venueController.text.trim();
    final canonicalVenue =
        (await _repo.canonicalVenueFor(trimmedVenue)) ?? trimmedVenue;
    final eventName = _eventController.text.trim();
    final dateStr = formatDate(_selectedDate);

    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      int? eventId;
      if (eventName.isNotEmpty) {
        eventId = await _eventRepo.upsertByTriple(
          eventName,
          canonicalVenue,
          dateStr,
          nowIso,
          executor: txn,
        );
      }

      final record = CheckiRecord(
        idolId: widget.idolId,
        date: dateStr,
        count: count,
        unitPrice: unitPrice,
        subtotal: count * unitPrice,
        venue: canonicalVenue,
        createdAt: nowIso,
        eventId: eventId,
        isOnline: _isOnline,
      );

      await _repo.insert(record, executor: txn);
    });

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = colorFor(widget.idolColor);

    return AlertDialog(
      title: const Text('添加切奇记录'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Locked idol info
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: borderColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.idolName} · ${widget.idolGroup}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
