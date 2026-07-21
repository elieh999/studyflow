# StudyFlow

StudyFlow is a planner I built to keep my coursework in one place instead of
scattered across sticky notes and three different apps. You add your courses,
throw your assignments in with due dates, run a Pomodoro-style focus timer while
you study, track your grades, and drill flashcards. Everything is stored locally
on your own machine — there's no account, no login, and it works completely
offline.

I wrote it in Flutter (Dart) with a local SQLite database (via the `drift`
package). It's a single-user, offline app.

## What it does

- **Dashboard** — today's classes, your soonest upcoming assignments, study time
  this week, a "due within 48 hours" alert, and a "Start studying" button.
- **Courses** — add / edit / delete courses with an instructor and a colour.
  Each course shows its total study time and how many assignments are still open.
- **Assignments** — add / edit / delete, mark complete, set priority
  (low / medium / high), a due date, and an estimated number of hours. Search
  and filter by course, status or priority; sorts by due date.
- **Focus timer** — a Pomodoro timer (25 min study / 5 min break, both
  adjustable). Pick the course, then start / pause / reset. Finished study blocks
  save automatically. You can jot a note per session and tap a button to log
  distractions. A little "focus garden" plant grows the more you study.
- **Weekly schedule** — add your recurring class times per day; these feed the
  "today's classes" list on the dashboard.
- **Flashcards** — make decks per course and review them with spaced repetition
  (an SM-2 scheduler, the same idea Anki uses). If you have a local AI model
  running (see below), you can paste your notes and it'll draft cards for you.
- **Study plan** — give assignments an estimated time and it builds a suggested
  day-by-day plan, earliest-deadline-first, capped at how much you want to study
  per day. It warns you when something won't fit before it's due.
- **Grades** — break each course into weighted items (Midterm 30%, Final 40%…),
  see your current grade, letter and GPA point, and a "what do I need on the
  rest to hit X%?" calculator.
- **Insights** — study time per course (bar chart), a 12-week study-activity
  heatmap, your daily streak, achievement badges, a "how much last-minute
  studying you do" figure, and export buttons (see below).
- **Export & backup** — save a weekly PDF report, export your assignments and
  classes to a calendar (.ics) file for Google/Outlook, and back up or restore
  all your data as a JSON file.
- **Dark mode** — toggle at the bottom of the sidebar; it remembers your choice.

## The optional local-AI bit

The flashcard generator and the "quick add" for assignments use a local AI model
through [Ollama](https://ollama.com), so nothing leaves your machine. These
features only show up when Ollama is running with a model pulled — the rest of
the app works completely fine without it. I tested with the small
`qwen2.5:0.5b` model; a larger model gives noticeably better cards. The launcher
talks to Ollama for the app so the browser doesn't have to.

## How to open it

Double-click **`Open StudyFlow.exe`**. That's it — the app opens in its own
window. There's nothing to install and no setup step. Your data is created
automatically the first time you add something and is still there next time.

## Known limitations

- **Windows only** for now — that's the only platform I've actually built and
  tested.
- Because this is my locked-down laptop (no admin rights), I couldn't install the
  Visual Studio C++ build tools that `flutter build windows` needs, so I couldn't
  produce a fully standalone native `.exe`. Instead `Open StudyFlow.exe` is a
  small launcher I compiled with `dart compile exe` (a real compiled program, not
  a batch file) that serves the app locally and opens it in an app window using
  the Edge/Chrome already on the PC. It still runs offline and stores data
  locally.
- Data lives in this machine's local browser storage — there's no cloud sync, so
  it doesn't follow you to another computer (that's what the JSON backup is for).
- The AI features need Ollama installed and running; without it they're just
  hidden.
- No pop-up reminders while the app is closed — deadlines show up inside the app
  (including the "due within 48 hours" banner) but it won't notify you in the
  background.

## What I'd add next

- Get it building as a proper native Windows `.exe` once I'm on a machine where I
  can install the C++ build tools.
- Background desktop notifications for deadlines.
- Editing schedule entries instead of deleting and re-adding them.
- Let the study planner work around my actual class times, not just a daily cap.
- Maybe cloud sync much later so my phone and laptop share the same data.

## How it's put together

- `lib/data/database.dart` — the drift tables (Course, Assignment, StudySession,
  ScheduleEntry, Flashcard, GradeItem) and all the queries.
- `lib/logic/` — the pure logic I could unit-test on its own: the SM-2 flashcard
  scheduler, grade maths, the study-plan generator, and the insight helpers.
- `lib/ai/ollama_service.dart` — talks to the local model through the launcher.
- `lib/export/` — the PDF, .ics and JSON backup builders.
- `lib/screens/` — one file per screen.
- `launcher/studyflow_launcher.dart` — the source for the `Open StudyFlow.exe`
  launcher (also proxies AI requests to Ollama).
- `test/` — tests for the database, the SM-2/grade/planner logic, backup
  round-trips, and the small helpers.

If you have the Flutter SDK and want to run it from source: `flutter run -d
chrome` (or `-d windows` on a machine with the C++ build tools installed).
