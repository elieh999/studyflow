import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../widgets/command_palette.dart';
import 'assignments_screen.dart';
import 'courses_screen.dart';
import 'dashboard_screen.dart';
import 'flashcards_screen.dart';
import 'grades_screen.dart';
import 'insights_screen.dart';
import 'notes_screen.dart';
import 'plan_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';
import 'timer_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _destinations = [
    (icon: Icons.dashboard_outlined, selected: Icons.dashboard, label: 'Dashboard'),
    (icon: Icons.menu_book_outlined, selected: Icons.menu_book, label: 'Courses'),
    (icon: Icons.checklist_outlined, selected: Icons.checklist, label: 'Assignments'),
    (icon: Icons.timer_outlined, selected: Icons.timer, label: 'Focus timer'),
    (icon: Icons.calendar_view_week_outlined, selected: Icons.calendar_view_week, label: 'Schedule'),
    (icon: Icons.style_outlined, selected: Icons.style, label: 'Flashcards'),
    (icon: Icons.sticky_note_2_outlined, selected: Icons.sticky_note_2, label: 'Notes'),
    (icon: Icons.grade_outlined, selected: Icons.grade, label: 'Grades'),
    (icon: Icons.event_note_outlined, selected: Icons.event_note, label: 'Plan'),
    (icon: Icons.insights_outlined, selected: Icons.insights, label: 'Insights'),
    (icon: Icons.settings_outlined, selected: Icons.settings, label: 'Settings'),
  ];

  void _go(int i) => setState(() => _index = i);

  void _openPalette() {
    final actions = <PaletteAction>[
      for (var i = 0; i < _destinations.length; i++)
        PaletteAction(_destinations[i].label, _destinations[i].icon,
            () => _go(i),
            hint: 'Go to ${_destinations[i].label}'),
      PaletteAction('Start studying', Icons.play_arrow, () => _go(3),
          hint: 'Open the focus timer'),
      PaletteAction('Toggle dark mode', Icons.dark_mode, () {
        final s = AppScope.of(context).settings;
        s.setDark(!s.isDark);
      }),
    ];
    showCommandPalette(context, actions);
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;

    final screens = [
      DashboardScreen(onStartStudying: () => _go(3)),
      const CoursesScreen(),
      const AssignmentsScreen(),
      const TimerScreen(),
      const ScheduleScreen(),
      const FlashcardsScreen(),
      const NotesScreen(),
      const GradesScreen(),
      const PlanScreen(),
      const InsightsScreen(),
      const SettingsScreen(),
    ];

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _openPalette,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _openPalette,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Row(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: NavigationRail(
                          selectedIndex: _index,
                          onDestinationSelected: _go,
                          labelType: NavigationRailLabelType.all,
                          leading: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              children: [
                                Icon(Icons.school,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 30),
                                const SizedBox(height: 4),
                                const Text('StudyFlow',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                IconButton(
                                  tooltip: 'Search (Ctrl+K)',
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.search, size: 20),
                                  onPressed: _openPalette,
                                ),
                              ],
                            ),
                          ),
                          trailing: Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: IconButton(
                                  tooltip: settings.isDark
                                      ? 'Switch to light mode'
                                      : 'Switch to dark mode',
                                  icon: Icon(settings.isDark
                                      ? Icons.light_mode
                                      : Icons.dark_mode),
                                  onPressed: () =>
                                      settings.setDark(!settings.isDark),
                                ),
                              ),
                            ),
                          ),
                          destinations: [
                            for (final d in _destinations)
                              NavigationRailDestination(
                                icon: Icon(d.icon),
                                selectedIcon: Icon(d.selected),
                                label: Text(d.label),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOut,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                              begin: const Offset(0.02, 0),
                              end: Offset.zero)
                          .animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_index),
                    child: screens[_index],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
