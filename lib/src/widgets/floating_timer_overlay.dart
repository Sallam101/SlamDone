import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/models.dart';
import '../services/timer_engine.dart';

class SlamDoneFloatingTimerOverlay extends StatefulWidget {
  const SlamDoneFloatingTimerOverlay({
    super.key,
    required this.controller,
    required this.onClose,
    required this.onDragDelta,
    this.compact = false,
  });

  final AppController controller;
  final VoidCallback onClose;
  final ValueChanged<Offset> onDragDelta;
  final bool compact;

  @override
  State<SlamDoneFloatingTimerOverlay> createState() =>
      _SlamDoneFloatingTimerOverlayState();
}

class _SlamDoneFloatingTimerOverlayState
    extends State<SlamDoneFloatingTimerOverlay> {
  int _colorIndex = 0;

  static const _timerColors = <Color>[
    Color(0xFF2457D6),
    Color(0xFF00897B),
    Color(0xFF7B1FA2),
    Color(0xFFC62828),
    Color(0xFFEF6C00),
    Color(0xFF455A64),
  ];

  @override
  Widget build(BuildContext context) {
    final engine = widget.controller.timerEngine;
    final accent = _timerColors[_colorIndex % _timerColors.length];
    final width = widget.compact ? 286.0 : 326.0;
    return Material(
      elevation: 18,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: width,
        child: AnimatedBuilder(
          animation: engine,
          builder: (context, _) {
            final state = engine.state;
            final displaySeconds = state.mode == TimerMode.stopwatch
                ? state.elapsedSeconds
                : state.remainingSeconds;
            final progress = state.mode == TimerMode.stopwatch
                ? 0.0
                : engine.progress.clamp(0, 1).toDouble();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) => widget.onDragDelta(details.delta),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    color: accent.withValues(alpha: .14),
                    child: Row(
                      children: [
                        Icon(Icons.drag_indicator, color: accent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SlamDone Floating Timer',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                state.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<int>(
                          tooltip: 'Timer color',
                          icon: const Icon(Icons.palette_outlined),
                          onSelected: (value) =>
                              setState(() => _colorIndex = value),
                          itemBuilder: (context) => List.generate(
                            _timerColors.length,
                            (index) => PopupMenuItem<int>(
                              value: index,
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: _timerColors[index],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('Color ${index + 1}'),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close floating timer',
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(widget.compact ? 12 : 16),
                  child: Column(
                    children: [
                      SizedBox(
                        width: widget.compact ? 150 : 172,
                        height: widget.compact ? 150 : 172,
                        child: CustomPaint(
                          painter: _TimerDialPainter(
                            progress: progress,
                            accent: accent,
                            stopwatch: state.mode == TimerMode.stopwatch,
                            elapsedSeconds: state.elapsedSeconds,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  engine.formatSeconds(displaySeconds),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  state.mode == TimerMode.stopwatch
                                      ? 'STOPWATCH'
                                      : state.mode.name.toUpperCase(),
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: accent,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: .8,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (!engine.isActive)
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                              ),
                              onPressed: () => engine.start(
                                mode: TimerMode.general,
                                title: 'General focus',
                                durationMinutes:
                                    widget.controller.defaultSessionMinutes,
                              ),
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Start'),
                            )
                          else if (state.paused)
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                              ),
                              onPressed: engine.resume,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Resume'),
                            )
                          else
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                              ),
                              onPressed: engine.pause,
                              icon: const Icon(Icons.pause),
                              label: const Text('Pause'),
                            ),
                          OutlinedButton.icon(
                            onPressed: engine.reset,
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('Reset'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => engine.stop(saveSession: true),
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: const Text('Log & stop'),
                          ),
                          TextButton.icon(
                            onPressed: () => engine.start(
                              mode: TimerMode.stopwatch,
                              title: 'Study stopwatch',
                            ),
                            icon: const Icon(Icons.hourglass_bottom),
                            label: const Text('Stopwatch'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TimerDialPainter extends CustomPainter {
  const _TimerDialPainter({
    required this.progress,
    required this.accent,
    required this.stopwatch,
    required this.elapsedSeconds,
  });

  final double progress;
  final Color accent;
  final bool stopwatch;
  final int elapsedSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: .16);
    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = accent;
    canvas.drawCircle(center, radius, track);
    final dialProgress = stopwatch
        ? ((elapsedSeconds % 60) / 60).clamp(0.0, 1.0)
        : progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * dialProgress,
      false,
      active,
    );
    for (var i = 0; i < 12; i++) {
      final angle = -math.pi / 2 + (math.pi * 2 * i / 12);
      final start = Offset(
        center.dx + math.cos(angle) * (radius - 16),
        center.dy + math.sin(angle) * (radius - 16),
      );
      final end = Offset(
        center.dx + math.cos(angle) * (radius - 10),
        center.dy + math.sin(angle) * (radius - 10),
      );
      canvas.drawLine(
        start,
        end,
        Paint()
          ..strokeWidth = 2
          ..color = accent.withValues(alpha: .55),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimerDialPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accent != accent ||
      oldDelegate.stopwatch != stopwatch ||
      oldDelegate.elapsedSeconds != elapsedSeconds;
}
