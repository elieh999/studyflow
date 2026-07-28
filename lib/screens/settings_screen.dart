import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../export/backup_actions.dart';
import '../theme.dart';
import '../widgets/color_picker_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: AnimatedBuilder(
        animation: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _section(context, 'Account'),
            _card(context, [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      (AppScope.of(context).auth.currentUser ?? '?')
                          .substring(0, 1)
                          .toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppScope.of(context).auth.currentUser ?? '',
                            style: Theme.of(context).textTheme.titleMedium),
                        Text('Signed in on this device',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Log out'),
                    onPressed: () => AppScope.of(context).auth.logout(),
                  ),
                ],
              ),
            ]),
            _section(context, 'Appearance'),
            _card(context, [
              _rowLabel(context, 'Theme'),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto),
                      label: Text('System')),
                  ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode),
                      label: Text('Light')),
                  ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode),
                      label: Text('Dark')),
                ],
                selected: {settings.mode},
                onSelectionChanged: (s) => settings.setMode(s.first),
              ),
              const SizedBox(height: 20),
              _rowLabel(context, 'Accent colour'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final a in accentThemes)
                    _swatch(context, settings, a),
                  _customSwatch(context, settings),
                ],
              ),
              const SizedBox(height: 20),
              _rowLabel(context, 'Text size'),
              const SizedBox(height: 8),
              SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: 0.9, label: Text('Compact')),
                  ButtonSegment(value: 1.0, label: Text('Normal')),
                  ButtonSegment(value: 1.15, label: Text('Large')),
                ],
                selected: {_nearestScale(settings.textScale)},
                onSelectionChanged: (s) => settings.setTextScale(s.first),
              ),
            ]),
            _section(context, 'Focus timer defaults'),
            _card(context, [
              _stepperRow(context, 'Study minutes', settings.studyMinutes, 5, 90,
                  settings.setStudyMinutes),
              _stepperRow(context, 'Short break', settings.breakMinutes, 1, 30,
                  settings.setBreakMinutes),
              _stepperRow(context, 'Long break', settings.longBreakMinutes, 5, 45,
                  settings.setLongBreakMinutes),
              _stepperRow(context, 'Long break every', settings.longBreakEvery, 2,
                  8, settings.setLongBreakEvery,
                  suffix: ' sessions'),
            ]),
            _section(context, 'Goals'),
            _card(context, [
              _rowLabel(context,
                  'Daily study goal: ${settings.dailyGoalMinutes} minutes'),
              Slider(
                value: settings.dailyGoalMinutes.toDouble(),
                min: 15,
                max: 480,
                divisions: 31,
                label: '${settings.dailyGoalMinutes} min',
                onChanged: (v) => settings.setDailyGoal(v.round()),
              ),
            ]),
            _section(context, 'Local AI (Ollama)'),
            _card(context, [
              Text(
                'Model used for flashcard generation and quick-add. Pull a bigger '
                'model in Ollama for better results, then put its name here.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              _AiModelField(initial: settings.aiModel, onSave: settings.setAiModel),
            ]),
            _section(context, 'Data'),
            _card(context, [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Backup'),
                    onPressed: () =>
                        exportBackupFlow(context, AppScope.of(context).db),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.upload_outlined),
                    label: const Text('Restore'),
                    onPressed: () =>
                        restoreBackupFlow(context, AppScope.of(context).db),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error),
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Reset all data'),
                    onPressed: () => _reset(context),
                  ),
                ],
              ),
            ]),
            _section(context, 'About'),
            _card(context, [
              Text('StudyFlow', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'A local, offline student planner and study tracker. '
                'Your data stays on this device. Version 2.0.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text('Tip: press Ctrl+K anywhere to jump around quickly.',
                  style: Theme.of(context).textTheme.bodySmall),
            ]),
          ],
        ),
      ),
    );
  }

  static double _nearestScale(double v) {
    const options = [0.9, 1.0, 1.15];
    var best = options.first;
    for (final o in options) {
      if ((o - v).abs() < (best - v).abs()) best = o;
    }
    return best;
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      );

  Widget _card(BuildContext context, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      );

  Widget _rowLabel(BuildContext context, String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );

  Widget _swatch(
      BuildContext context, SettingsController settings, AccentTheme a) {
    final selected = settings.seed.toARGB32() == a.seed.toARGB32();
    return Tooltip(
      message: a.name,
      child: GestureDetector(
        onTap: () => settings.setSeed(a.seed),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: a.seed,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 3,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }

  // A "pick any colour" swatch. Selected when the current seed is not one of
  // the built in presets.
  Widget _customSwatch(BuildContext context, SettingsController settings) {
    final isPreset = accentThemes
        .any((a) => a.seed.toARGB32() == settings.seed.toARGB32());
    final selected = !isPreset;
    return Tooltip(
      message: 'Custom colour',
      child: GestureDetector(
        onTap: () async {
          final picked = await showAccentColorPicker(context, settings.seed);
          if (picked != null) await settings.setSeed(picked);
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const SweepGradient(colors: [
              Color(0xFFD64545),
              Color(0xFFE0952B),
              Color(0xFF3F9142),
              Color(0xFF4F86C6),
              Color(0xFF7A5CC6),
              Color(0xFFD64545),
            ]),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 3,
            ),
          ),
          child: Icon(
            selected ? Icons.check : Icons.add,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _stepperRow(BuildContext context, String label, int value, int min,
      int max, ValueChanged<int> onChanged,
      {String suffix = ''}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 64,
            child: Text('$value$suffix', textAlign: TextAlign.center),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _reset(BuildContext context) async {
    final db = AppScope.of(context).db;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset all data?'),
        content: const Text(
            'This permanently deletes every course, assignment, session, '
            'flashcard and grade. Consider making a backup first.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await db.clearAllData();
      messenger.showSnackBar(const SnackBar(content: Text('All data cleared.')));
    }
  }
}

class _AiModelField extends StatefulWidget {
  const _AiModelField({required this.initial, required this.onSave});
  final String initial;
  final ValueChanged<String> onSave;

  @override
  State<_AiModelField> createState() => _AiModelFieldState();
}

class _AiModelFieldState extends State<_AiModelField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Ollama model name',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: () {
            widget.onSave(_ctrl.text);
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI model saved.')));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
