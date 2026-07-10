import 'package:flutter/material.dart';
import 'package:cheki_counter/data/idol_repository.dart';
import 'package:cheki_counter/data/models/idol.dart';
import 'package:cheki_counter/shared/colors.dart';

class EditIdolDialog extends StatefulWidget {
  final Idol idol;

  const EditIdolDialog({super.key, required this.idol});

  @override
  State<EditIdolDialog> createState() => _EditIdolDialogState();
}

class _EditIdolDialogState extends State<EditIdolDialog> {
  final _formKey = GlobalKey<FormState>();
  final _repo = IdolRepository();
  late final TextEditingController _nameController;
  late final TextEditingController _groupController;
  late String _selectedColor;
  String? _tripleError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.idol.name);
    _groupController = TextEditingController(text: widget.idol.groupName);
    _selectedColor = presetColors.containsKey(widget.idol.color)
        ? widget.idol.color
        : presetColorNames.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _tripleError = null);
    if (!_formKey.currentState!.validate()) return;

    try {
      await _repo.updateCurrentProfile(
        idolId: widget.idol.id!,
        name: _nameController.text.trim(),
        color: _selectedColor,
        groupName: _groupController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on DuplicateIdolTripleException {
      if (!mounted) return;
      setState(() {
        _tripleError = '已存在相同名字、应援色和团体的偶像';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑偶像'),
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
                  labelText: '名字',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return '请填写名字';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              const Text('应援色', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 4),
              _EditColorGrid(
                selected: _selectedColor,
                onSelected: (color) => setState(() => _selectedColor = color),
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
              if (_tripleError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _tripleError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}

class _EditColorGrid extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _EditColorGrid({required this.selected, required this.onSelected});

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
                ? Icon(
                    Icons.check,
                    size: 16,
                    color: color.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                  )
                : null,
          ),
        );
      },
    );
  }
}
