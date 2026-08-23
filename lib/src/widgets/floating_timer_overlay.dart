import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/models.dart';
import '../services/timer_engine.dart';
import 'slamdone_brand.dart';

enum _TimerDensity { mini, compact, regular, spacious }

class SlamDoneFloatingTimerOverlay extends StatefulWidget {
  const SlamDoneFloatingTimerOverlay({
    super.key,
    required this.controller,
    required this.onClose,
    required this.onDragDelta,
    required this.onResizeDelta,
    required this.size,
    this.compact = false,
  });

  final AppController controller;
  final VoidCallback onClose;
  final ValueChanged<Offset> onDragDelta;
  final ValueChanged<Offset> onResizeDelta;
  final Size size;
  final bool compact;

  @override
  State<SlamDoneFloatingTimerOverlay> createState() =>
      _SlamDoneFloatingTimerOverlayState();
}

class _SlamDoneFloatingTimerOverlayState
    extends State<SlamDoneFloatingTimerOverlay> {
  int _colorIndex = 0;

  static const _timerColors = <Color>[
    SlamDoneBrand.brandGreen,
    Color(0xFF2457D6),
    Color(0xFF00897B),
    Color(0xFF7B1FA2),
    Color(0xFFC62828),
    Color(0xFFEF6C00),
    Color(0xFF455A64),
    Color(0xFFAD1457),
  ];

  _TimerDensity get _density {
    final w = widget.size.width;
    final h = widget.size.height;
    if (w < 224 || h < 214) return _TimerDensity.mini;
    if (w < 310 || h < 330) return _TimerDensity.compact;
    if (w > 470 && h > 470) return _TimerDensity.spacious;
    return _TimerDensity.regular;
  }

  @override
  Widget build(BuildContext context) {
    final engine = widget.controller.timerEngine;
    final accent = _timerColors[_colorIndex % _timerColors.length];
    final density = _density;
    final radius = density == _TimerDensity.mini ? 12.0 : 20.0;

    return Material(
      elevation: 18,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: widget.size.width,
        height: widget.size.height,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: engine,
                builder: (context, _) => _buildTimerBody(
                  context,
                  engine: engine,
                  accent: accent,
                  density: density,
                ),
              ),
            ),
            // Large transparent hit target makes diagonal resizing smooth even
            // when the timer is in its tiny compact controls layout.
            Positioned(
              right: 0,
              bottom: 0,
              width: 34,
              height: 34,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeDownRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanUpdate: (details) => widget.onResizeDelta(details.delta),
                  child: Tooltip(
                    message: 'Resize timer',
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: CustomPaint(
                        size: const Size.square(30),
                        painter: _ResizeGripPainter(accent),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerBody(
    BuildContext context, {
    required TimerEngine engine,
    required Color accent,
    required _TimerDensity density,
  }) {
    final state = engine.state;
    final displaySeconds = state.mode == TimerMode.stopwatch
        ? state.elapsedSeconds
        : state.remainingSeconds;
    final progress = state.mode == TimerMode.stopwatch
        ? 0.0
        : engine.progress.clamp(0, 1).toDouble();

    return Column(
      children: [
        _buildHeader(context, accent: accent, density: density, title: state.title),
        Expanded(
          child: density == _TimerDensity.mini
              ? _buildMiniBody(
                  context,
                  engine: engine,
                  accent: accent,
                  displaySeconds: displaySeconds,
                  progress: progress,
                )
              : SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    density == _TimerDensity.compact ? 10 : 16,
                    density == _TimerDensity.compact ? 8 : 12,
                    density == _TimerDensity.compact ? 10 : 16,
                    28,
                  ),
                  child: _buildFullBody(
                    context,
                    engine: engine,
                    accent: accent,
                    density: density,
                    displaySeconds: displaySeconds,
                    progress: progress,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required Color accent,
    required _TimerDensity density,
    required String title,
  }) {
    final mini = density == _TimerDensity.mini;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) => widget.onDragDelta(details.delta),
      child: MouseRegion(
        cursor: SystemMouseCursors.move,
        child: Container(
          height: mini ? 38 : (density == _TimerDensity.compact ? 48 : 58),
          padding: EdgeInsets.fromLTRB(mini ? 8 : 10, 5, 4, 5),
          color: accent.withValues(alpha: .12),
          child: Row(
            children: [
              SlamDoneMark(size: mini ? 22 : 27),
              const SizedBox(width: 6),
              Expanded(
                child: mini
                    ? Text(
                        'SlamDone',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SlamDone Timer',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
              ),
              if (!mini)
                PopupMenuButton<int>(
                  tooltip: 'Timer color',
                  iconSize: 19,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.palette_outlined),
                  onSelected: (value) => setState(() => _colorIndex = value),
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
                          Text(index == 0 ? 'SlamDone green' : 'Color ${index + 1}'),
                        ],
                      ),
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Close floating timer',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(
                  width: mini ? 30 : 34,
                  height: mini ? 30 : 34,
                ),
                onPressed: widget.onClose,
                icon: Icon(Icons.close, size: mini ? 18 : 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBody(
    BuildContext context, {
    required TimerEngine engine,
    required Color accent,
    required int displaySeconds,
    required double progress,
  }) {
    final state = engine.state;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              engine.formatSeconds(displaySeconds),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 31,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ),
          Text(
            state.mode == TimerMode.stopwatch
                ? 'STOPWATCH'
                : state.mode.name.toUpperCase(),
            maxLines: 1,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: state.mode == TimerMode.stopwatch ? null : progress,
              minHeight: 5,
              color: accent,
              backgroundColor: accent.withValues(alpha: .14),
            ),
          ),
          const SizedBox(height: 7),
          // Compact controls intentionally use icons so the panel can shrink to
          // a true mini timer instead of clipping large text buttons.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _miniAction(
                tooltip: _primaryLabel(engine),
                icon: _primaryIcon(engine),
                color: accent,
                filled: true,
                onPressed: () => _primaryAction(engine),
              ),
              _miniAction(
                tooltip: 'Reset',
                icon: Icons.restart_alt,
                color: accent,
                onPressed: engine.reset,
              ),
              _miniAction(
                tooltip: 'Log & stop',
                icon: Icons.stop_circle_outlined,
                color: accent,
                onPressed: () => engine.stop(saveSession: true),
              ),
              _miniAction(
                tooltip: 'Stopwatch',
                icon: Icons.hourglass_bottom,
                color: accent,
                onPressed: () => engine.start(
                  mode: TimerMode.stopwatch,
                  title: 'Study stopwatch',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniAction({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool filled = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          visualDensity: VisualDensity.compact,
          style: filled
              ? IconButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                )
              : null,
          onPressed: onPressed,
          icon: Icon(icon, size: 19),
        ),
      ),
    );
  }

  Widget _buildFullBody(
    BuildContext context, {
    required TimerEngine engine,
    required Color accent,
    required _TimerDensity density,
    required int displaySeconds,
    required double progress,
  }) {
    final state = engine.state;
    final availableDial = math.min(
      widget.size.width - (density == _TimerDensity.compact ? 40 : 76),
      widget.size.height - (density == _TimerDensity.spacious ? 210 : 180),
    );
    final dialMin = density == _TimerDensity.compact ? 84.0 : 112.0;
    final dialMax = density == _TimerDensity.spacious ? 300.0 : 205.0;
    final dialSize = availableDial.clamp(dialMin, dialMax).toDouble();

    return Column(
      children: [
        SizedBox(
          width: dialSize,
          height: dialSize,
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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      engine.formatSeconds(displaySeconds),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: density == _TimerDensity.spacious ? 46 : null,
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    state.mode == TimerMode.stopwatch
                        ? 'STOPWATCH'
                        : state.mode.name.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .8,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: density == _TimerDensity.compact ? 7 : 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: density == _TimerDensity.compact ? 5 : 8,
          runSpacing: density == _TimerDensity.compact ? 5 : 8,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                visualDensity: density == _TimerDensity.compact
                    ? VisualDensity.compact
                    : null,
              ),
              onPressed: () => _primaryAction(engine),
              icon: Icon(_primaryIcon(engine)),
              label: Text(_primaryLabel(engine)),
            ),
            OutlinedButton.icon(
              style: density == _TimerDensity.compact
                  ? OutlinedButton.styleFrom(visualDensity: VisualDensity.compact)
                  : null,
              onPressed: engine.reset,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset'),
            ),
            OutlinedButton.icon(
              style: density == _TimerDensity.compact
                  ? OutlinedButton.styleFrom(visualDensity: VisualDensity.compact)
                  : null,
              onPressed: () => engine.stop(saveSession: true),
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(density == _TimerDensity.compact ? 'Stop' : 'Log & stop'),
            ),
            if (density != _TimerDensity.compact)
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
    );
  }

  String _primaryLabel(TimerEngine engine) {
    if (!engine.isActive) return 'Start';
    return engine.state.paused ? 'Resume' : 'Pause';
  }

  IconData _primaryIcon(TimerEngine engine) {
    if (!engine.isActive || engine.state.paused) return Icons.play_arrow;
    return Icons.pause;
  }

  void _primaryAction(TimerEngine engine) {
    if (!engine.isActive) {
      engine.start(
        mode: TimerMode.general,
        title: 'General focus',
        durationMinutes: widget.controller.defaultSessionMinutes,
      );
    } else if (engine.state.paused) {
      engine.resume();
    } else {
      engine.pause();
    }
  }
}

class _ResizeGripPainter extends CustomPainter {
  const _ResizeGripPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .78)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final inset = 5.0 + i * 5;
      canvas.drawLine(
        Offset(size.width - inset, size.height - 3),
        Offset(size.width - 3, size.height - inset),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ResizeGripPainter oldDelegate) =>
      oldDelegate.color != color;
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
    final stroke = (size.shortestSide * .06).clamp(5.0, 11.0).toDouble();
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: .16);
    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
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
      final insetOuter = math.max(7.0, size.shortestSide * .06);
      final insetInner = math.max(13.0, size.shortestSide * .11);
      final start = Offset(
        center.dx + math.cos(angle) * (radius - insetInner),
        center.dy + math.sin(angle) * (radius - insetInner),
      );
      final end = Offset(
        center.dx + math.cos(angle) * (radius - insetOuter),
        center.dy + math.sin(angle) * (radius - insetOuter),
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
