import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PaletteAction {
  const PaletteAction(this.label, this.icon, this.run, {this.hint = ''});
  final String label;
  final IconData icon;
  final String hint;
  final VoidCallback run;
}

Future<void> showCommandPalette(
    BuildContext context, List<PaletteAction> actions) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (context) => _CommandPalette(actions: actions),
  );
}

class _CommandPalette extends StatefulWidget {
  const _CommandPalette({required this.actions});
  final List<PaletteAction> actions;

  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  String _query = '';
  int _highlight = 0;
  final _focus = FocusNode();

  List<PaletteAction> get _filtered {
    if (_query.isEmpty) return widget.actions;
    final q = _query.toLowerCase();
    return widget.actions
        .where((a) =>
            a.label.toLowerCase().contains(q) ||
            a.hint.toLowerCase().contains(q))
        .toList();
  }

  void _runHighlighted() {
    final list = _filtered;
    if (list.isEmpty) return;
    final action = list[_highlight.clamp(0, list.length - 1)];
    Navigator.pop(context);
    action.run();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 90, left: 24, right: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 440),
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                setState(() => _highlight =
                    (_highlight + 1).clamp(0, (list.length - 1).clamp(0, 999))),
            const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                setState(() => _highlight = (_highlight - 1).clamp(0, 999)),
            const SingleActivator(LogicalKeyboardKey.enter): _runHighlighted,
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                Navigator.pop(context),
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  focusNode: _focus,
                  autofocus: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Jump to… or type a command',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() {
                    _query = v;
                    _highlight = 0;
                  }),
                  onSubmitted: (_) => _runHighlighted(),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: list.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No matches'))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final a = list[i];
                          final selected = i == _highlight;
                          return Container(
                            color: selected
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.12)
                                : null,
                            child: ListTile(
                              leading: Icon(a.icon),
                              title: Text(a.label),
                              subtitle: a.hint.isEmpty ? null : Text(a.hint),
                              onTap: () {
                                Navigator.pop(context);
                                a.run();
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
