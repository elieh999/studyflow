import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../data/database.dart';
import '../widgets/common.dart';
import '../widgets/confetti.dart';
import '../widgets/focus_garden.dart';

enum Phase { study, breakTime }

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  int _studyMinutes = 25;
  int _breakMinutes = 5;
  int _breakLenMin = 5; // length of the current break (regular or long)

  Phase _phase = Phase.study;
  late int _remaining = _studyMinutes * 60;
  bool _running = false;
  Timer? _ticker;
  int? _courseId;
  DateTime? _blockStart;
  int _completedToday = 0;
  int _distractions = 0;
  bool _isLongBreak = false;
  bool _celebrate = false;
  bool _loadedDefaults = false;
  final _noteCtrl = TextEditingController();

  int get _phaseTotal =>
      (_phase == Phase.study ? _studyMinutes : _breakLenMin) * 60;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Seed the timer from the user's saved defaults, once, while idle.
    if (!_loadedDefaults) {
      _loadedDefaults = true;
      final s = AppScope.of(context).settings;
      _studyMinutes = s.studyMinutes;
      _breakMinutes = s.breakMinutes;
      _breakLenMin = s.breakMinutes;
      if (!_running && _phase == Phase.study) _remaining = _studyMinutes * 60;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _start() {
    if (_running) return;
    setState(() {
      _running = true;
      if (_blockStart == null) {
        _blockStart = DateTime.now();
        if (_phase == Phase.study) _distractions = 0;
      }
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining > 1) {
        setState(() => _remaining--);
      } else {
        _onPhaseComplete();
      }
    });
  }

  void _pause() {
    _ticker?.cancel();
    setState(() => _running = false);
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      _running = false;
      _remaining = _phaseTotal;
      _blockStart = null;
    });
  }

  Future<void> _onPhaseComplete() async {
    _ticker?.cancel();
    // Read settings before any await so we don't touch context afterwards.
    final settings = AppScope.of(context).settings;
    if (_phase == Phase.study) {
      // Save the finished study block.
      if (_courseId != null && _blockStart != null) {
        final db = AppScope.of(context).db;
        await db.addSession(StudySessionsCompanion(
          courseId: Value(_courseId!),
          startTime: Value(_blockStart!),
          duration: Value(_studyMinutes * 60),
          sessionDate: Value(DateTime.now()),
          distractions: Value(_distractions),
          note: Value(_noteCtrl.text.trim()),
        ));
        _completedToday++;
      }
      _noteCtrl.clear();
      // Every Nth session earns a longer break.
      _isLongBreak =
          _completedToday > 0 && _completedToday % settings.longBreakEvery == 0;
      _breakLenMin = _isLongBreak ? settings.longBreakMinutes : _breakMinutes;
      setState(() {
        _phase = Phase.breakTime;
        _remaining = _breakLenMin * 60;
        _running = false;
        _blockStart = null;
        _distractions = 0;
        _celebrate = true;
      });
      _snack(_isLongBreak
          ? 'Session saved. Enjoy a longer $_breakLenMin-minute break!'
          : 'Study session saved. Time for a $_breakLenMin-minute break.');
    } else {
      setState(() {
        _phase = Phase.study;
        _remaining = _studyMinutes * 60;
        _running = false;
        _blockStart = null;
        _isLongBreak = false;
      });
      _snack('Break over — ready for another study session.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String get _clock {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final db = AppScope.of(context).db;
    final isStudy = _phase == Phase.study;
    final scheme = Theme.of(context).colorScheme;
    final progress =
        _phaseTotal == 0 ? 0.0 : 1 - (_remaining / _phaseTotal);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () =>
            _running ? _pause() : _start(),
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Focus timer'),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          StreamBuilder<List<Course>>(
        stream: db.watchCourses(),
        builder: (context, snap) {
          final courses = snap.data ?? [];
          if (courses.isEmpty) {
            return const EmptyHint(
              icon: Icons.timer_outlined,
              text: 'Add a course first,\nthen you can track focus sessions for it.',
            );
          }
          _courseId ??= courses.first.id;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StreamBuilder<List<StudySession>>(
                    stream: db.watchSessions(),
                    builder: (context, s) {
                      final total = (s.data ?? [])
                              .fold<int>(0, (t, x) => t + x.duration) ~/
                          60;
                      return FocusGarden(totalMinutes: total);
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: (isStudy ? scheme.primary : scheme.tertiary)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isStudy
                          ? 'Study session'
                          : (_isLongBreak ? 'Long break' : 'Break'),
                      style: TextStyle(
                        color: isStudy ? scheme.primary : scheme.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 240,
                          height: 240,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 10,
                            backgroundColor:
                                scheme.surfaceContainerHighest,
                          ),
                        ),
                        Text(_clock,
                            style: const TextStyle(
                                fontSize: 56,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 320,
                    child: DropdownButtonFormField<int>(
                      initialValue: _courseId,
                      decoration:
                          const InputDecoration(labelText: 'Studying for'),
                      items: [
                        for (final c in courses)
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged:
                          _running ? null : (v) => setState(() => _courseId = v),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.icon(
                        onPressed: _running ? _pause : _start,
                        icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                        label: Text(_running ? 'Pause' : 'Start'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.replay),
                        label: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 320,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _noteCtrl,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'Session note (optional)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Tooltip(
                          message: 'Log a distraction',
                          child: OutlinedButton.icon(
                            onPressed: (_running && isStudy)
                                ? () => setState(() => _distractions++)
                                : null,
                            icon: const Icon(Icons.notifications_active_outlined),
                            label: Text('$_distractions'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _DurationStepper(
                        label: 'Study min',
                        value: _studyMinutes,
                        enabled: !_running && _phase == Phase.study,
                        onChanged: (v) => setState(() {
                          _studyMinutes = v;
                          if (_phase == Phase.study && !_running) {
                            _remaining = v * 60;
                          }
                        }),
                      ),
                      const SizedBox(width: 24),
                      _DurationStepper(
                        label: 'Break min',
                        value: _breakMinutes,
                        enabled: !_running && _phase == Phase.breakTime,
                        onChanged: (v) => setState(() {
                          _breakMinutes = v;
                          if (_phase == Phase.breakTime && !_running) {
                            _remaining = v * 60;
                          }
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Sessions completed this run: $_completedToday',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          );
        },
          ),
          if (_celebrate)
            Positioned.fill(
              child: ConfettiBurst(
                onComplete: () {
                  if (mounted) setState(() => _celebrate = false);
                },
              ),
            ),
        ],
      ),
      ),
    );
  }
}

class _DurationStepper extends StatelessWidget {
  const _DurationStepper({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed:
                  enabled && value > 1 ? () => onChanged(value - 1) : null,
            ),
            SizedBox(
              width: 28,
              child: Text('$value',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed:
                  enabled && value < 120 ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      ],
    );
  }
}
