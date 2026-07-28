import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/pomodoro_controller.dart';
import '../widgets/confetti.dart';

// A distraction free, full screen focus view driven by the shared
// PomodoroController. Whatever is running here is the same session as the
// normal timer screen.
class ZenTimerScreen extends StatelessWidget {
  const ZenTimerScreen({super.key, required this.controller});

  final PomodoroController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () =>
            controller.running ? controller.pause() : controller.start(),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final accent =
                controller.isStudy ? scheme.primary : scheme.tertiary;
            return Scaffold(
              body: Stack(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accent.withValues(alpha: 0.12),
                          scheme.surface,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            controller.isStudy
                                ? 'Focus'
                                : (controller.isLongBreak
                                    ? 'Long break'
                                    : 'Break'),
                            style: TextStyle(
                                color: accent,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2),
                          ),
                          const SizedBox(height: 40),
                          SizedBox(
                            width: 340,
                            height: 340,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 340,
                                  height: 340,
                                  child: CircularProgressIndicator(
                                    value: controller.progress,
                                    strokeWidth: 12,
                                    valueColor:
                                        AlwaysStoppedAnimation(accent),
                                    backgroundColor:
                                        scheme.surfaceContainerHighest,
                                  ),
                                ),
                                Text(controller.clockLabel,
                                    style: const TextStyle(
                                        fontSize: 84,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 48),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilledButton.icon(
                                onPressed: controller.running
                                    ? controller.pause
                                    : controller.start,
                                icon: Icon(controller.running
                                    ? Icons.pause
                                    : Icons.play_arrow),
                                label: Text(
                                    controller.running ? 'Pause' : 'Start'),
                              ),
                              const SizedBox(width: 14),
                              OutlinedButton.icon(
                                onPressed: controller.reset,
                                icon: const Icon(Icons.replay),
                                label: const Text('Reset'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text('Press space to start or pause',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 12,
                    child: IconButton(
                      tooltip: 'Exit zen mode',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  if (controller.celebrate)
                    Positioned.fill(
                      child: ConfettiBurst(
                          onComplete: controller.clearCelebrate),
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
