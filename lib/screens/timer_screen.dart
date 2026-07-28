import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../data/database.dart';
import '../logic/pomodoro_controller.dart';
import '../widgets/common.dart';
import '../widgets/confetti.dart';
import '../widgets/focus_garden.dart';
import 'zen_timer_screen.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  PomodoroController? _controller;
  final _noteCtrl = TextEditingController();
  int _lastCompleted = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      final scope = AppScope.of(context);
      _controller = PomodoroController(
        settings: scope.settings,
        saveSession: _save,
      )..addListener(_onControllerChanged);
    }
  }

  Future<void> _save({
    required int courseId,
    required DateTime start,
    required int durationSeconds,
    required int distractions,
    required String note,
  }) async {
    final db = AppScope.of(context).db;
    await db.addSession(StudySessionsCompanion(
      courseId: Value(courseId),
      startTime: Value(start),
      duration: Value(durationSeconds),
      sessionDate: Value(DateTime.now()),
      distractions: Value(distractions),
      note: Value(note.trim()),
    ));
  }

  void _onControllerChanged() {
    final c = _controller!;
    if (c.note.isEmpty && _noteCtrl.text.isNotEmpty) _noteCtrl.clear();
    if (c.completed > _lastCompleted) {
      _lastCompleted = c.completed;
      _snack(c.isLongBreak
          ? 'Session saved. Enjoy a longer ${c.breakLenMin}-minute break!'
          : 'Study session saved. Time for a ${c.breakLenMin}-minute break.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = AppScope.of(context).db;
    final c = _controller!;
    final scheme = Theme.of(context).colorScheme;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () =>
            c.running ? c.pause() : c.start(),
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Focus timer'),
          automaticallyImplyLeading: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => ZenTimerScreen(controller: c),
                )),
                icon: const Icon(Icons.center_focus_strong),
                label: const Text('Zen mode'),
              ),
            ),
          ],
        ),
        body: StreamBuilder<List<Course>>(
          stream: db.watchCourses(),
          builder: (context, snap) {
            final courses = snap.data ?? [];
            if (courses.isEmpty) {
              return const EmptyHint(
                icon: Icons.timer_outlined,
                text:
                    'Add a course first,\nthen you can track focus sessions for it.',
              );
            }
            c.initCourseIfNeeded(courses.first.id);

            return ListenableBuilder(
              listenable: c,
              builder: (context, _) => Stack(
                children: [
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StreamBuilder<List<StudySession>>(
                            stream: db.watchSessions(),
                            builder: (context, s) {
                              final total = (s.data ?? []).fold<int>(
                                      0, (t, x) => t + x.duration) ~/
                                  60;
                              return FocusGarden(totalMinutes: total);
                            },
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: (c.isStudy
                                      ? scheme.primary
                                      : scheme.tertiary)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              c.isStudy
                                  ? 'Study session'
                                  : (c.isLongBreak ? 'Long break' : 'Break'),
                              style: TextStyle(
                                color:
                                    c.isStudy ? scheme.primary : scheme.tertiary,
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
                                    value: c.progress,
                                    strokeWidth: 10,
                                    backgroundColor:
                                        scheme.surfaceContainerHighest,
                                  ),
                                ),
                                Text(c.clockLabel,
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
                              initialValue: c.courseId,
                              decoration: const InputDecoration(
                                  labelText: 'Studying for'),
                              items: [
                                for (final course in courses)
                                  DropdownMenuItem(
                                      value: course.id,
                                      child: Text(course.name)),
                              ],
                              onChanged:
                                  c.running ? null : (v) => c.setCourse(v),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilledButton.icon(
                                onPressed: c.running ? c.pause : c.start,
                                icon: Icon(c.running
                                    ? Icons.pause
                                    : Icons.play_arrow),
                                label: Text(c.running ? 'Pause' : 'Start'),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: c.reset,
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
                                    onChanged: c.setNote,
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
                                    onPressed: (c.running && c.isStudy)
                                        ? c.addDistraction
                                        : null,
                                    icon: const Icon(
                                        Icons.notifications_active_outlined),
                                    label: Text('${c.distractions}'),
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
                                value: c.studyMinutes,
                                enabled: !c.running && c.isStudy,
                                onChanged: c.setStudyMinutes,
                              ),
                              const SizedBox(width: 24),
                              _DurationStepper(
                                label: 'Break min',
                                value: c.breakMinutes,
                                enabled: !c.running && !c.isStudy,
                                onChanged: c.setBreakMinutes,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text('Sessions completed this run: ${c.completed}',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                  if (c.celebrate)
                    Positioned.fill(
                      child:
                          ConfettiBurst(onComplete: c.clearCelebrate),
                    ),
                ],
              ),
            );
          },
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
