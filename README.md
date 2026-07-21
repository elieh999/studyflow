# StudyFlow

StudyFlow is a little planner I built to keep my coursework in one place instead
of scattered across sticky notes and three different apps. You add your courses,
throw your assignments in with due dates, run a Pomodoro-style focus timer while
you study, and it keeps track of how much time you've actually put in per course.
Everything is stored locally on your own machine — there's no account, no login,
and it works completely offline.

I wrote it in Flutter (Dart) with a local SQLite database (via the `drift`
package). It's a single-user, offline app.

## What it does

- **Dashboard** — today's classes, your soonest upcoming assignments, and how
  much you've studied this week, plus a "Start studying" button that jumps
  straight to the timer.
- **Courses** — add / edit / delete courses with an instructor and a colour.
  Each course shows its total study time and how many assignments are still open.
- **Assignments** — add / edit / delete, mark complete, set a priority
  (low / medium / high) and a due date. You can search them and filter by course,
  status or priority, and they sort by due date.
- **Focus timer** — a Pomodoro timer (25 min study / 5 min break, both
  adjustable). Pick the course you're studying, then start / pause / reset. When
  a study block finishes it saves the session to the database automatically.
- **Weekly schedule** — add your recurring class times per day; these also feed
  the "today's classes" list on the dashboard.
- **Statistics** — a bar chart of study time per course, assignments completed,
  your current daily study streak, and your most-studied course this week. It's
  all pulled from your real saved data, not sample data.
- **Dark mode** — toggle at the bottom of the sidebar; it remembers your choice.

## How to open it

Double-click **`Open StudyFlow.exe`**. That's it — the app opens in its own
window. There's nothing to install and no setup step.

The first time you add anything, the database is created automatically; you don't
have to do anything for that to happen. Your data stays on this PC and is still
there next time you open the app.

## Known limitations

- **Windows only** for now — that's the only platform I've actually built and
  tested.
- Because this is my locked-down college/work laptop (no admin rights), I
  couldn't install the Visual Studio C++ build tools that `flutter build windows`
  needs, so I couldn't produce a fully standalone native `.exe`. Instead
  `Open StudyFlow.exe` is a small launcher I compiled with `dart compile exe`
  (a real compiled program, not a batch file) that serves the app locally and
  opens it in an app window using the Edge/Chrome that's already on the PC. It
  still runs offline and stores data locally — it just leans on the browser
  engine that ships with Windows.
- Your data lives in this machine's local app storage. There's no cloud sync, so
  it doesn't follow you to another computer.
- No notifications yet — deadlines show up in the app but it won't pop up a
  reminder while it's closed.

## What I'd add next

- Get it building as a proper native Windows `.exe` once I'm on a machine where I
  can install the C++ build tools.
- Desktop notifications for assignments that are due soon.
- A way to export a weekly study report (probably as a PDF).
- Editing schedule entries instead of deleting and re-adding them.
- Maybe cloud sync much later, so my phone and laptop share the same data.

## How it's put together

- `lib/data/database.dart` — the drift tables (Course, Assignment, StudySession,
  ScheduleEntry) and all the queries.
- `lib/screens/` — one file per screen (dashboard, courses, assignments, timer,
  schedule, statistics).
- `lib/main.dart` / `lib/app_scope.dart` — app startup, theme, and passing the
  database down to the screens.
- `launcher/studyflow_launcher.dart` — the source for the `Open StudyFlow.exe`
  launcher.
- `test/` — tests for the database (create / update / delete, cascade deletes,
  marking assignments done) and the small helper functions.

If you have the Flutter SDK and just want to run it from source: `flutter run -d
chrome` (or `-d windows` on a machine with the C++ build tools installed).
