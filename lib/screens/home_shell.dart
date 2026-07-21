import 'package:flutter/material.dart';

import '../app_scope.dart';
import 'assignments_screen.dart';
import 'courses_screen.dart';
import 'dashboard_screen.dart';
import 'flashcards_screen.dart';
import 'grades_screen.dart';
import 'insights_screen.dart';
import 'plan_screen.dart';
import 'schedule_screen.dart';
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
    (icon: Icons.grade_outlined, selected: Icons.grade, label: 'Grades'),
    (icon: Icons.event_note_outlined, selected: Icons.event_note, label: 'Plan'),
    (icon: Icons.insights_outlined, selected: Icons.insights, label: 'Insights'),
  ];

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final theme = AppScope.of(context).theme;

    final screens = [
      DashboardScreen(onStartStudying: () => _go(3)),
      const CoursesScreen(),
      const AssignmentsScreen(),
      const TimerScreen(),
      const ScheduleScreen(),
      const FlashcardsScreen(),
      const GradesScreen(),
      const PlanScreen(),
      const InsightsScreen(),
    ];

    return Scaffold(
      body: Row(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                                color: Theme.of(context).colorScheme.primary,
                                size: 30),
                            const SizedBox(height: 4),
                            const Text('StudyFlow',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      trailing: Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: IconButton(
                              tooltip: theme.isDark
                                  ? 'Switch to light mode'
                                  : 'Switch to dark mode',
                              icon: Icon(theme.isDark
                                  ? Icons.light_mode
                                  : Icons.dark_mode),
                              onPressed: () => theme.setDark(!theme.isDark),
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
          Expanded(child: screens[_index]),
        ],
      ),
    );
  }
}
