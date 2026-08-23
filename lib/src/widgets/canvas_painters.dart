import 'package:flutter/material.dart';

class DotGridPainter extends CustomPainter {
  DotGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const spacing = 28.0;
    for (double x = 0; x <= size.width; x += spacing) {
      for (double y = 0; y <= size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.15, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DotGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

class ConnectionPainter extends CustomPainter {
  ConnectionPainter({
    required this.rects,
    required this.parentByChild,
    required this.color,
  });

  final Map<String, Rect> rects;
  final Map<String, String?> parentByChild;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    for (final entry in parentByChild.entries) {
      final parentId = entry.value;
      if (parentId == null) continue;
      final parent = rects[parentId];
      final child = rects[entry.key];
      if (parent == null || child == null) continue;

      final start = parent.center;
      final end = child.center;
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final path = Path()..moveTo(start.dx, start.dy);
      if (dx.abs() >= dy.abs()) {
        final bend = dx * 0.5;
        path.cubicTo(
          start.dx + bend,
          start.dy,
          end.dx - bend,
          end.dy,
          end.dx,
          end.dy,
        );
      } else {
        final bend = dy * 0.5;
        path.cubicTo(
          start.dx,
          start.dy + bend,
          end.dx,
          end.dy - bend,
          end.dx,
          end.dy,
        );
      }
      canvas.drawPath(path, paint);
      canvas.drawCircle(end, 3.4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant ConnectionPainter oldDelegate) =>
      oldDelegate.rects != rects ||
      oldDelegate.parentByChild != parentByChild ||
      oldDelegate.color != color;
}
