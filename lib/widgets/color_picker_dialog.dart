import 'package:flutter/material.dart';

// ---- pure helpers (unit tested) --------------------------------------------

int _r(Color c) => (c.toARGB32() >> 16) & 0xFF;
int _g(Color c) => (c.toARGB32() >> 8) & 0xFF;
int _b(Color c) => c.toARGB32() & 0xFF;

String colorToHex(Color c) {
  final rgb = c.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

// Parses "#RRGGBB", "RRGGBB" or short "#RGB"; returns null if invalid.
Color? hexToColor(String input) {
  var s = input.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 3) {
    s = s.split('').map((ch) => '$ch$ch').join();
  }
  if (s.length != 6) return null;
  final value = int.tryParse(s, radix: 16);
  if (value == null) return null;
  return Color(0xFF000000 | value);
}

// ---- the dialog -------------------------------------------------------------

Future<Color?> showAccentColorPicker(BuildContext context, Color initial) {
  return showDialog<Color>(
    context: context,
    builder: (_) => _ColorPickerDialog(initial: initial),
  );
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial});
  final Color initial;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late int _red = _r(widget.initial);
  late int _green = _g(widget.initial);
  late int _blue = _b(widget.initial);
  late final TextEditingController _hexCtrl =
      TextEditingController(text: colorToHex(widget.initial));

  Color get _color => Color.fromARGB(255, _red, _green, _blue);

  void _syncHexField() {
    final hex = colorToHex(_color);
    if (_hexCtrl.text.toUpperCase() != hex) _hexCtrl.text = hex;
  }

  void _onHexChanged(String v) {
    final c = hexToColor(v);
    if (c != null) {
      setState(() {
        _red = _r(c);
        _green = _g(c);
        _blue = _b(c);
      });
    }
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom accent colour'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 64,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _hexCtrl,
              decoration: const InputDecoration(
                labelText: 'Hex',
                prefixIcon: Icon(Icons.tag),
              ),
              onChanged: _onHexChanged,
            ),
            const SizedBox(height: 12),
            _channel('R', _red, const Color(0xFFD64545),
                (v) => setState(() { _red = v; _syncHexField(); })),
            _channel('G', _green, const Color(0xFF3F9142),
                (v) => setState(() { _green = v; _syncHexField(); })),
            _channel('B', _blue, const Color(0xFF4F86C6),
                (v) => setState(() { _blue = v; _syncHexField(); })),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _color),
            child: const Text('Use this colour')),
      ],
    );
  }

  Widget _channel(
      String label, int value, Color tint, ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(width: 18, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            activeColor: tint,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
            width: 34,
            child: Text('$value', textAlign: TextAlign.right)),
      ],
    );
  }
}
