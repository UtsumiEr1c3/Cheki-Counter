import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:cheki_counter/shared/colors.dart';

class IdolColorSelection {
  final String name;
  final int colorValue;

  const IdolColorSelection({required this.name, required this.colorValue});
}

class IdolColorField extends StatefulWidget {
  final String initialName;
  final int initialColorValue;
  final ValueChanged<IdolColorSelection> onChanged;

  const IdolColorField({
    super.key,
    required this.initialName,
    required this.initialColorValue,
    required this.onChanged,
  });

  @override
  State<IdolColorField> createState() => _IdolColorFieldState();
}

class _IdolColorFieldState extends State<IdolColorField> {
  late final TextEditingController _nameController;
  late int _colorValue;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _colorValue = opaqueColorValue(widget.initialColorValue);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _notifyChanged() {
    widget.onChanged(
      IdolColorSelection(name: _nameController.text, colorValue: _colorValue),
    );
  }

  void _selectPreset(String name) {
    setState(() {
      _nameController.text = name;
      _colorValue = colorValueForName(name);
    });
    _notifyChanged();
  }

  Future<void> _openColorPicker() async {
    var draftColor = colorFromValue(_colorValue);
    final selected = await showDialog<Color>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('选择应援色'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: draftColor,
            onColorChanged: (color) => draftColor = color,
            enableAlpha: false,
            displayThumbColor: true,
            paletteType: PaletteType.hsvWithHue,
            labelTypes: const [],
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(draftColor),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _colorValue = opaqueColorValue(selected.toARGB32()));
    _notifyChanged();
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor = colorFromValue(_colorValue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('应援色', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: presetColorNames.map((name) {
            final value = colorValueForName(name);
            final color = colorFromValue(value);
            final isSelected = value == _colorValue;
            return SizedBox.square(
              dimension: 38,
              child: Tooltip(
                message: name,
                child: InkWell(
                  key: ValueKey('idol-color-preset-$name'),
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _selectPreset(name),
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
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: selectedColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black26),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(colorValueToHex(_colorValue))),
            OutlinedButton.icon(
              key: const ValueKey('idol-color-custom-button'),
              onPressed: _openColorPicker,
              icon: const Icon(Icons.palette_outlined),
              label: const Text('自定义'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          key: const ValueKey('idol-color-name-field'),
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: '颜色名称',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _notifyChanged(),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return '请填写颜色名称';
            return null;
          },
        ),
      ],
    );
  }
}
