import 'package:flutter/material.dart';
import 'package:cheki_counter/data/record_repository.dart';
import 'package:cheki_counter/data/models/record.dart';
import 'package:cheki_counter/shared/colors.dart';
import 'package:cheki_counter/shared/formatters.dart';
import 'package:cheki_counter/shared/widgets/venue_field.dart';

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
  late DateTime _selectedDate;
  final _repo = RecordRepository();

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

    final count = int.parse(_countController.text);
    final unitPrice = int.parse(_priceController.text);
    final now = DateTime.now();

    final trimmedVenue = _venueController.text.trim();
    final canonicalVenue =
        (await _repo.canonicalVenueFor(trimmedVenue)) ?? trimmedVenue;

    final record = CheckiRecord(
      idolId: widget.idolId,
      date: formatDate(_selectedDate),
      count: count,
      unitPrice: unitPrice,
      subtotal: count * unitPrice,
      venue: canonicalVenue,
      createdAt: now.toIso8601String(),
    );

    await _repo.insert(record);
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
              const SizedBox(height: 16),
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
              VenueField(
                controller: _venueController,
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
