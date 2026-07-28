import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app_scope.dart';

enum Phase { study, breakTime }

// Called when a study block finishes so the caller can persist it.
typedef SaveSession = Future<void> Function({
  required int courseId,
  required DateTime start,
  required int durationSeconds,
  required int distractions,
  required String note,
});

// Owns the running state of the Pomodoro timer so the normal timer screen and
// the fullscreen "Zen" screen can drive and reflect the exact same countdown.
class PomodoroController extends ChangeNotifier {
  PomodoroController({
    required this.settings,
    required this.saveSession,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    studyMinutes = settings.studyMinutes;
    breakMinutes = settings.breakMinutes;
    breakLenMin = settings.breakMinutes;
    remaining = studyMinutes * 60;
  }

  final SettingsController settings;
  final SaveSession saveSession;
  final DateTime Function() _clock;

  late int studyMinutes;
  late int breakMinutes;
  late int breakLenMin; // length of the current break (regular or long)
  Phase phase = Phase.study;
  late int remaining; // seconds
  bool running = false;
  int? courseId;
  int completed = 0;
  int distractions = 0;
  bool isLongBreak = false;
  bool celebrate = false;
  String note = '';

  Timer? _ticker;
  DateTime? _blockStart;

  bool get isStudy => phase == Phase.study;
  int get phaseTotal => (isStudy ? studyMinutes : breakLenMin) * 60;
  double get progress => phaseTotal == 0 ? 0 : 1 - remaining / phaseTotal;

  String get clockLabel {
    final m = (remaining ~/ 60).toString().padLeft(2, '0');
    final s = (remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // Safe to call from build: sets a default course without notifying.
  void initCourseIfNeeded(int id) => courseId ??= id;

  void start() {
    if (running) return;
    running = true;
    if (_blockStart == null) {
      _blockStart = _clock();
      if (isStudy) distractions = 0;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remaining > 1) {
        remaining--;
        notifyListeners();
      } else {
        finishPhase();
      }
    });
    notifyListeners();
  }

  void pause() {
    _ticker?.cancel();
    running = false;
    notifyListeners();
  }

  void reset() {
    _ticker?.cancel();
    running = false;
    remaining = phaseTotal;
    _blockStart = null;
    notifyListeners();
  }

  // Runs the end-of-phase transition. Called by the ticker at zero, and by
  // tests directly. On a finished study block it saves the session and decides
  // whether the next break is a long one.
  Future<void> finishPhase() async {
    _ticker?.cancel();
    if (isStudy) {
      if (courseId != null && _blockStart != null) {
        await saveSession(
          courseId: courseId!,
          start: _blockStart!,
          durationSeconds: studyMinutes * 60,
          distractions: distractions,
          note: note,
        );
        completed++;
      }
      isLongBreak =
          completed > 0 && completed % settings.longBreakEvery == 0;
      breakLenMin = isLongBreak ? settings.longBreakMinutes : breakMinutes;
      phase = Phase.breakTime;
      remaining = breakLenMin * 60;
      running = false;
      _blockStart = null;
      distractions = 0;
      note = '';
      celebrate = true;
    } else {
      phase = Phase.study;
      remaining = studyMinutes * 60;
      running = false;
      _blockStart = null;
      isLongBreak = false;
    }
    notifyListeners();
  }

  void clearCelebrate() {
    celebrate = false;
    notifyListeners();
  }

  void addDistraction() {
    if (running && isStudy) {
      distractions++;
      notifyListeners();
    }
  }

  void setCourse(int? id) {
    if (running) return;
    courseId = id;
    notifyListeners();
  }

  void setNote(String value) => note = value;

  void setStudyMinutes(int m) {
    studyMinutes = m;
    if (isStudy && !running) remaining = m * 60;
    notifyListeners();
  }

  void setBreakMinutes(int m) {
    breakMinutes = m;
    if (!isStudy && !running && !isLongBreak) {
      breakLenMin = m;
      remaining = m * 60;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
