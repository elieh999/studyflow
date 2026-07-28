import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyflow/app_scope.dart';
import 'package:studyflow/logic/pomodoro_controller.dart';

void main() {
  late SettingsController settings;
  late List<({int courseId, int distractions, int seconds})> saved;
  late PomodoroController c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsController(await SharedPreferences.getInstance());
    saved = [];
    c = PomodoroController(
      settings: settings,
      saveSession: ({
        required courseId,
        required start,
        required durationSeconds,
        required distractions,
        required note,
      }) async {
        saved.add((
          courseId: courseId,
          distractions: distractions,
          seconds: durationSeconds
        ));
      },
    );
  });

  tearDown(() => c.dispose());

  test('finishing a study block saves it and moves to a break', () async {
    c.setCourse(1);
    c.start();
    await c.finishPhase();

    expect(saved, hasLength(1));
    expect(saved.single.courseId, 1);
    expect(c.isStudy, isFalse);
    expect(c.completed, 1);
    expect(c.celebrate, isTrue);
  });

  test('a study block with no course selected is not saved', () async {
    c.setCourse(null);
    c.start();
    await c.finishPhase();
    expect(saved, isEmpty);
    expect(c.completed, 0);
  });

  test('distraction taps are counted and stored with the session', () async {
    c.setCourse(1);
    c.start();
    c.addDistraction();
    c.addDistraction();
    await c.finishPhase();
    expect(saved.single.distractions, 2);
  });

  test('every Nth session earns a long break', () async {
    Future<void> completeStudy() async {
      c.setCourse(1);
      c.start();
      await c.finishPhase(); // study -> break
    }

    Future<void> completeBreak() async {
      c.start();
      await c.finishPhase(); // break -> study
    }

    for (var i = 1; i <= settings.longBreakEvery; i++) {
      await completeStudy();
      if (i < settings.longBreakEvery) {
        expect(c.isLongBreak, isFalse, reason: 'session $i should be short');
        await completeBreak();
      }
    }
    // On the Nth completion the break should be the long one.
    expect(c.completed, settings.longBreakEvery);
    expect(c.isLongBreak, isTrue);
    expect(c.breakLenMin, settings.longBreakMinutes);
  });

  test('reset returns to the full study time', () {
    c.setStudyMinutes(30);
    c.start();
    c.reset();
    expect(c.running, isFalse);
    expect(c.remaining, 30 * 60);
    expect(c.isStudy, isTrue);
  });
}
