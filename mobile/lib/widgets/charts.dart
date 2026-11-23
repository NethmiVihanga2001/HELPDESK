import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// One slice of a [DonutChart].
typedef ChartSlice = ({String label, int value, Color color});

/// Animated donut chart with the total in the middle (DSH-1).
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.slices, this.size = 150, this.centerLabel = 'tickets'});

  final List<ChartSlice> slices;
  final double size;
  final String centerLabel;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<int>(0, (a, s) => a + s.value);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _DonutPainter(slices: slices, total: total, progress: progress),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${(total * progress).round()}',
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.1)),
                Text(centerLabel, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices, required this.total, required this.progress});

  final List<ChartSlice> slices;
  final int total;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.line;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, track);
    if (total == 0) return;

    final visible = slices.where((s) => s.value > 0).toList();
    final gap = visible.length > 1 ? 0.06 : 0.0;
    var start = -math.pi / 2;
    for (final s in visible) {
      final sweep = (s.value / total) * math.pi * 2 * progress;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = s.color;
      canvas.drawArc(arcRect, start + gap / 2, math.max(0.001, sweep - gap), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.progress != progress || old.total != total || old.slices != slices;
}

/// Coloured dot + label + value rows next to a chart.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.slices});

  final List<ChartSlice> slices;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final s in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(s.label,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
                ),
                const SizedBox(width: 8),
                Text('${s.value}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Horizontal bars, e.g. open tickets per agent (DSH-4).
class BarList extends StatelessWidget {
  const BarList({super.key, required this.items, this.color = AppColors.primary});

  final List<({String label, int value})> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final max = items.fold<int>(1, (a, i) => math.max(a, i.value));
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(item.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500))),
                    Text('${item.value} open', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                  ],
                ),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: item.value / max),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Stack(
                    children: [
                      Container(height: 10, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(6))),
                      FractionallySizedBox(
                        widthFactor: v.clamp(0.0, 1.0),
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(gradient: AppColors.brand, borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
