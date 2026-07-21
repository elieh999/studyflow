import 'dart:math' as math;

import 'package:flutter/material.dart';

// A quick, dependency-free confetti burst. Drop it into a Stack; it plays once
// and calls [onComplete] so the parent can remove it.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.onComplete});

  final VoidCallback? onComplete;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Particle> _particles;

  static const _colors = [
    Color(0xFF4F86C6),
    Color(0xFF2E9E67),
    Color(0xFFE0952B),
    Color(0xFFD6608E),
    Color(0xFF7A5CC6),
    Color(0xFF20A4A0),
  ];

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42);
    _particles = List.generate(80, (i) {
      final angle = rng.nextDouble() * math.pi * 2;
      final speed = 140 + rng.nextDouble() * 260;
      return _Particle(
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 120,
        color: _colors[i % _colors.length],
        size: 5 + rng.nextDouble() * 7,
        rotation: rng.nextDouble() * math.pi,
        spin: (rng.nextDouble() - 0.5) * 12,
      );
    });
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onComplete?.call();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _ConfettiPainter(_particles, _c.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.rotation,
    required this.spin,
  });
  final double vx, vy, size, rotation, spin;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.t);
  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.42);
    const gravity = 520.0;
    final paint = Paint();
    for (final p in particles) {
      final x = origin.dx + p.vx * t;
      final y = origin.dy + p.vy * t + 0.5 * gravity * t * t;
      final opacity = (1 - t).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.spin * t);
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.5),
          paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
