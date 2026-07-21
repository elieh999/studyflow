import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow/util.dart';

void main() {
  test('formatDuration reads nicely', () {
    expect(formatDuration(30), '30s');
    expect(formatDuration(90), '1m');
    expect(formatDuration(3600), '1h 0m');
    expect(formatDuration(4800), '1h 20m');
  });

  test('priority labels map correctly', () {
    expect(priorityLabel(0), 'Low');
    expect(priorityLabel(1), 'Medium');
    expect(priorityLabel(2), 'High');
  });

  test('startOfWeek returns the Monday of that week at midnight', () {
    // 2026-07-21 is a Tuesday; its week starts Monday 2026-07-20.
    final monday = startOfWeek(DateTime(2026, 7, 21, 15, 30));
    expect(monday, DateTime(2026, 7, 20));
    expect(monday.weekday, DateTime.monday);
  });
}
