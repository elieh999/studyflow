import 'dart:math' as math;

import 'package:flutter/material.dart';

// A little plant that grows the more total time you've studied. Purely visual
// motivation — drawn with a CustomPainter, no assets.
class FocusGarden extends StatelessWidget {
  const FocusGarden({super.key, required this.totalMinutes});

  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    // Growth saturates around 10 hours of study.
    final growth = (totalMinutes / 600).clamp(0.0, 1.0);
    final stage = switch (totalMinutes) {
      0 => 'Plant a seed by studying',
      < 30 => 'A sprout appears',
      < 120 => 'It\'s growing',
      < 360 => 'Looking healthy',
      < 600 => 'Almost in bloom',
      _ => 'In full bloom!',
    };
    return Column(
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: CustomPaint(
            painter: _GardenPainter(
              growth: growth,
              leaf: Theme.of(context).colorScheme.primary,
              soil: Theme.of(context).colorScheme.tertiary,
            ),
          ),
        ),
        Text(stage, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _GardenPainter extends CustomPainter {
  _GardenPainter({required this.growth, required this.leaf, required this.soil});

  final double growth;
  final Color leaf;
  final Color soil;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final potTop = size.height - 34.0;

    // Pot.
    final pot = Paint()..color = soil.withValues(alpha: 0.8);
    final path = Path()
      ..moveTo(cx - 26, potTop)
      ..lineTo(cx + 26, potTop)
      ..lineTo(cx + 20, size.height)
      ..lineTo(cx - 20, size.height)
      ..close();
    canvas.drawPath(path, pot);

    if (growth <= 0) {
      // Just a seed mound.
      canvas.drawCircle(
          Offset(cx, potTop - 2), 3, Paint()..color = leaf.withValues(alpha: 0.6));
      return;
    }

    // Stem.
    final stemHeight = (potTop - 18) * growth;
    final stemTop = Offset(cx, potTop - stemHeight);
    final stem = Paint()
      ..color = leaf
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, potTop), stemTop, stem);

    // Leaves along the stem.
    final leafPaint = Paint()..color = leaf.withValues(alpha: 0.85);
    final leaves = (growth * 5).round();
    for (var i = 1; i <= leaves; i++) {
      final t = i / (leaves + 1);
      final y = potTop - stemHeight * t;
      final side = i.isEven ? 1 : -1;
      final size0 = 8.0 + 6 * growth;
      canvas.save();
      canvas.translate(cx, y);
      canvas.scale(side.toDouble(), 1);
      final leafPath = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(size0, -size0 * 0.6, size0 * 1.6, 0)
        ..quadraticBezierTo(size0, size0 * 0.6, 0, 0);
      canvas.drawPath(leafPath, leafPaint);
      canvas.restore();
    }

    // Flower once mostly grown.
    if (growth > 0.75) {
      final petal = Paint()..color = const Color(0xFFE0A458);
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3;
        canvas.drawCircle(
            stemTop + Offset(math.cos(a) * 7, math.sin(a) * 7), 5, petal);
      }
      canvas.drawCircle(stemTop, 4, Paint()..color = const Color(0xFF8A5A2B));
    }
  }

  @override
  bool shouldRepaint(covariant _GardenPainter old) =>
      old.growth != growth || old.leaf != leaf;
}
