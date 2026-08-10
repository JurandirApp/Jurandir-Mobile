import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Donut chart (rosca) via CustomPainter. Segmentos partem do topo (-90°).
/// Reutilizado no KPIs do estabelecimento e no Dashboard do admin.
class DonutChart extends StatelessWidget {
  /// Lista de (cor, fração 0..1). A soma das frações idealmente = 1.
  final List<(Color, double)> segments;
  final double size;
  final double strokeWidth;
  final Widget? center;

  const DonutChart({
    super.key,
    required this.segments,
    this.size = 110,
    this.strokeWidth = 15,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size.square(size), painter: _DonutPainter(segments, strokeWidth)),
          ?center,
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<(Color, double)> segments;
  final double strokeWidth;

  _DonutPainter(this.segments, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: c, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = AppColors.inkA(0.06);
    canvas.drawCircle(c, radius, track);

    var start = -math.pi / 2;
    for (final (color, frac) in segments) {
      if (frac <= 0) continue;
      final sweep = frac * 2 * math.pi;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color;
      canvas.drawArc(rect, start, sweep, false, p);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.segments != segments || old.strokeWidth != strokeWidth;
}
