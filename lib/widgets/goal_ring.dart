import 'package:flutter/material.dart';

// A circular progress ring showing today's study minutes against the daily goal.
class GoalRing extends StatelessWidget {
  const GoalRing({
    super.key,
    required this.doneMinutes,
    required this.goalMinutes,
  });

  final int doneMinutes;
  final int goalMinutes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress =
        goalMinutes <= 0 ? 0.0 : (doneMinutes / goalMinutes).clamp(0.0, 1.0);
    final reached = goalMinutes > 0 && doneMinutes >= goalMinutes;
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 11,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                  reached ? const Color(0xFF2E9E67) : scheme.primary),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$doneMinutes',
                  style: Theme.of(context).textTheme.headlineSmall),
              Text('of $goalMinutes min',
                  style: Theme.of(context).textTheme.bodySmall),
              if (reached)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.check_circle,
                      size: 16, color: Color(0xFF2E9E67)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
