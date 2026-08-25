import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/models.dart';
import '../services/timer_engine.dart';
import 'slamdone_brand.dart';

enum _TimerDensity { mini, compact, regular, spacious }
enum _TimerResizeAxis { horizontal, vertical, both }

class SlamDoneFloatingTimerOverlay extends StatefulWidget {
  const SlamDoneFloatingTimerOverlay({
    super.key,
    required this.controller,
    required this.onClose,
    required this.onDragDelta,
    required this.onResizeDelta,
    required this.size,
    required this.pinned,
    required this.onPinnedChanged,
    required this.opacity,
    required this.onOpacityChanged,
    required this.colorIndex,
    required this.onColorChanged,
    this.compact = false,
  });

  final AppController controller;
  final VoidCallback onClose;
  final ValueChanged<Offset> onDragDelta;
  final ValueChanged<Offset> onResizeDelta;
  final Size size;
  final bool pinned;
  final ValueChanged<bool> onPinnedChanged;
  final double opacity;
  final ValueChanged<double> onOpacityChanged;
  final int colorIndex;
  final ValueChanged<int> onColorChanged;
  final bool compact;

  @override
  State<SlamDoneFloatingTimerOverlay> createState() =>
      _SlamDoneFloatingTimerOverlayState();
}

class _SlamDoneFloatingTimerOverlayState
    extends State<SlamDoneFloatingTimerOverlay> {
  bool _showOpacity = false;

  static const _timerColors = <Color>[
    SlamDoneBrand.brandGreen,
    Color(0xFF2457D6),
    Color(0xFF00897B),
    Color(0xFF7B1FA2),
    Color(0xFFC62828),
    Color(0xFFEF6C00),
    Color(0xFF455A64),
    Color(0xFFAD1457),
    Color(0xFF2E7D32),
    Color(0xFF455A64),
    Color(0xFF8D6E00),
    Color(0xFF2E7D32),
    Color(0xFF1565C0),
    Color(0xFF6A1B9A),
    Color(0xFFAD1457),
    Color(0xFF7A6100),
  ];

  static const _timerBackgrounds = <Color?>[
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    Color(0xFFFFFDFC),
    Color(0xFFF2F4F7),
    Color(0xFFFFF4D6),
    Color(0xFFE8F7EE),
    Color(0xFFE9F4FF),
    Color(0xFFF2ECFF),
    Color(0xFFFFECEF),
    Color(0xFFFFF8CC),
  ];

  static const _timerColorNames = <String>[
    'SlamDone green',
    'Blue',
    'Teal',
    'Purple',
    'Red',
    'Orange',
    'Slate',
    'Berry',
    'White',
    'Soft gray',
    'Cream',
    'Mint',
    'Ice blue',
    'Lavender',
    'Blush',
    'Pale yellow',
  ];

  _TimerDensity get _density {
    final w = widget.size.width;
    final h = widget.size.height;
    if (w < 205 || h < 190) return _TimerDensity.mini;
    if (w < 285 || h < 285) return _TimerDensity.compact;
    if (w > 500 && h > 500) return _TimerDensity.spacious;
    return _TimerDensity.regular;
  }

  @override
  Widget build(BuildContext context) {
    final engine = widget.controller.timerEngine;
    final safeColorIndex = widget.colorIndex.clamp(0, _timerColors.length - 1).toInt();
    final accent = _timerColors[safeColorIndex];
    final baseTheme = Theme.of(context);
    final background =
        _timerBackgrounds[safeColorIndex] ?? baseTheme.colorScheme.surface;
    final foreground = background.computeLuminance() > .55
        ? const Color(0xFF182019)
        : baseTheme.colorScheme.onSurface;
    final onAccent = accent.computeLuminance() > .55
        ? const Color(0xFF182019)
        : Colors.white;
    final timerTheme = baseTheme.copyWith(
      colorScheme: baseTheme.colorScheme.copyWith(
        surface: background,
        onSurface: foreground,
        primary: accent,
        onPrimary: onAccent,
      ),
      textTheme: baseTheme.textTheme.apply(
        bodyColor: foreground,
        displayColor: foreground,
      ),
      iconTheme: baseTheme.iconTheme.copyWith(color: foreground),
    );
    final density = _density;
    final radius = density == _TimerDensity.mini ? 10.0 : 16.0;

    return Theme(
      data: timerTheme,
      child: AnimatedOpacity(
        opacity: widget.opacity.clamp(.25, 1).toDouble(),
        duration: const Duration(milliseconds: 120),
        child: Material(
          elevation: 18,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          color: background,
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
                if (_showOpacity)
                  Positioned(
                    left: 8,
                    right: 8,
                    top: density == _TimerDensity.mini ? 31 : 35,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(10),
                      color: background.withValues(alpha: .96),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.opacity, size: 15, color: accent),
                            Expanded(
                              child: Slider(
                                min: .25,
                                max: 1,
                                divisions: 15,
                                value: widget.opacity.clamp(.25, 1).toDouble(),
                                onChanged: widget.onOpacityChanged,
                              ),
                            ),
                            Text(
                              '${(widget.opacity.clamp(.25, 1) * 100).round()}%',
                              style: timerTheme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Edge handles avoid forcing the pointer into one tiny corner and
                // feel much smoother on mouse/trackpad than a single drag target.
                Positioned(
                  right: 0,
                  top: density == _TimerDensity.mini ? 28 : 32,
                  bottom: 22,
                  width: 10,
                  child: _resizeHandle(
                    axis: _TimerResizeAxis.horizontal,
                    accent: accent,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 22,
                  bottom: 0,
                  height: 10,
                  child: _resizeHandle(
                    axis: _TimerResizeAxis.vertical,
                    accent: accent,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  width: 30,
                  height: 30,
                  child: _resizeHandle(
                    axis: _TimerResizeAxis.both,
                    accent: accent,
                    showGrip: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resizeHandle({
    required _TimerResizeAxis axis,
    required Color accent,
    bool showGrip = false,
  }) {
    final cursor = switch (axis) {
      _TimerResizeAxis.horizontal => SystemMouseCursors.resizeLeftRight,
      _TimerResizeAxis.vertical => SystemMouseCursors.resizeUpDown,
      _TimerResizeAxis.both => SystemMouseCursors.resizeDownRight,
    };
    return MouseRegion(
      cursor: cursor,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerMove: (event) {
          final delta = switch (axis) {
            _TimerResizeAxis.horizontal => Offset(event.delta.dx, 0),
            _TimerResizeAxis.vertical => Offset(0, event.delta.dy),
            _TimerResizeAxis.both => event.delta,
          };
          widget.onResizeDelta(delta);
        },
        child: showGrip
            ? Tooltip(
                message: 'Resize timer',
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: CustomPaint(
                    size: const Size.square(28),
                    painter: _ResizeGripPainter(accent),
                  ),
                ),
              )
            : const SizedBox.expand(),
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
    final title = state.title.trim().isEmpty ? 'General focus' : state.title.trim();

    return Column(
      children: [
        _buildHeader(
          context,
          accent: accent,
          density: density,
          title: title,
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              density == _TimerDensity.mini ? 5 : 8,
              density == _TimerDensity.mini ? 3 : 6,
              density == _TimerDensity.mini ? 5 : 8,
              density == _TimerDensity.mini ? 7 : 10,
            ),
            child: _buildClockFirstBody(
              context,
              engine: engine,
              accent: accent,
              density: density,
              displaySeconds: displaySeconds,
              progress: progress,
              title: title,
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
    final utilitySize = mini ? 24.0 : 26.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) => widget.onDragDelta(details.delta),
      child: MouseRegion(
        cursor: SystemMouseCursors.move,
        child: Container(
          height: mini ? 28 : 32,
          padding: EdgeInsets.fromLTRB(mini ? 7 : 9, 2, 2, 2),
          color: accent.withValues(alpha: .10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                ),
              ),
              IconButton(
                tooltip: widget.pinned ? 'Unpin timer' : 'Pin timer',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: BoxConstraints.tightFor(
                  width: utilitySize,
                  height: utilitySize,
                ),
                onPressed: () => widget.onPinnedChanged(!widget.pinned),
                icon: Icon(
                  widget.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: mini ? 15 : 16,
                ),
              ),
              IconButton(
                tooltip: _showOpacity ? 'Hide transparency control' : 'Timer transparency',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: BoxConstraints.tightFor(
                  width: utilitySize,
                  height: utilitySize,
                ),
                onPressed: () => setState(() => _showOpacity = !_showOpacity),
                icon: Icon(Icons.opacity, size: mini ? 15 : 16),
              ),
              SizedBox(
                width: utilitySize,
                height: utilitySize,
                child: PopupMenuButton<int>(
                  tooltip: 'Timer color',
                  iconSize: mini ? 15 : 16,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.palette_outlined),
                  onSelected: widget.onColorChanged,
                  itemBuilder: (context) => List.generate(
                    _timerColors.length,
                    (index) => PopupMenuItem<int>(
                      value: index,
                      child: Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: _timerBackgrounds[index] ?? _timerColors[index],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _timerColors[index],
                                width: 2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(_timerColorNames[index]),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close floating timer',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: BoxConstraints.tightFor(
                  width: utilitySize,
                  height: utilitySize,
                ),
                onPressed: widget.onClose,
                icon: Icon(Icons.close, size: mini ? 16 : 17),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClockFirstBody(
    BuildContext context, {
    required TimerEngine engine,
    required Color accent,
    required _TimerDensity density,
    required int displaySeconds,
    required double progress,
    required String title,
  }) {
    final state = engine.state;
    return LayoutBuilder(
      builder: (context, constraints) {
        final mini = density == _TimerDensity.mini;
        final compactControls =
            density == _TimerDensity.mini ||
            density == _TimerDensity.compact ||
            constraints.maxWidth < 285;
        const controlHeight = 30.0;
        final dialMax = switch (density) {
          _TimerDensity.mini => 92.0,
          _TimerDensity.compact => 150.0,
          _TimerDensity.regular => 270.0,
          _TimerDensity.spacious => 480.0,
        };
        final available = math.min(
          constraints.maxWidth - (mini ? 4 : 10),
          constraints.maxHeight - controlHeight - (mini ? 4 : 8),
        );
        final dialSize = available.clamp(50.0, dialMax).toDouble();
        final timeSize = (dialSize * .28).clamp(19.0, 54.0).toDouble();

        return Column(
          children: [
            Expanded(
              child: Center(
                child: SizedBox.square(
                  dimension: dialSize,
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
                                    fontSize: timeSize,
                                    fontWeight: FontWeight.w900,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                    height: .95,
                                  ),
                            ),
                          ),
                          if (dialSize >= 50)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5),
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      fontSize: (dialSize * .07).clamp(7.0, 11.0),
                                      fontWeight: FontWeight.w800,
                                      height: 1,
                                    ),
                              ),
                            ),
                          if (dialSize >= 105)
                            Text(
                              state.mode == TimerMode.stopwatch
                                  ? 'STOPWATCH'
                                  : state.mode.name.toUpperCase(),
                              maxLines: 1,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: accent,
                                    fontSize: (dialSize * .075).clamp(8.0, 12.0),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .7,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: mini ? 2 : 4),
            ConstrainedBox(
              constraints: const BoxConstraints.tightFor(height: 30),
              child: compactControls
                  ? _buildIconControls(engine, accent)
                  : _buildSmallLabelControls(engine, accent),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIconControls(TimerEngine engine, Color accent) {
    return Row(
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
          tooltip: 'Stop & log',
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
      padding: const EdgeInsets.symmetric(horizontal: 1.5),
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          style: filled
              ? IconButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                )
              : null,
          onPressed: onPressed,
          icon: Icon(icon, size: 17),
        ),
      ),
    );
  }

  Widget _buildSmallLabelControls(TimerEngine engine, Color accent) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _smallAction(
            label: _primaryLabel(engine),
            icon: _primaryIcon(engine),
            accent: accent,
            filled: true,
            onPressed: () => _primaryAction(engine),
          ),
          _smallAction(
            label: 'Reset',
            icon: Icons.restart_alt,
            accent: accent,
            onPressed: engine.reset,
          ),
          _smallAction(
            label: 'Stop',
            icon: Icons.stop_circle_outlined,
            accent: accent,
            onPressed: () => engine.stop(saveSession: true),
          ),
          _smallAction(
            label: 'Stopwatch',
            icon: Icons.hourglass_bottom,
            accent: accent,
            onPressed: () => engine.start(
              mode: TimerMode.stopwatch,
              title: 'Study stopwatch',
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallAction({
    required String label,
    required IconData icon,
    required Color accent,
    required VoidCallback onPressed,
    bool filled = false,
  }) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 28)),
      maximumSize: const WidgetStatePropertyAll(Size(double.infinity, 28)),
      visualDensity: VisualDensity.compact,
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 7, vertical: 0),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: filled ? WidgetStatePropertyAll(accent) : null,
      foregroundColor: filled ? const WidgetStatePropertyAll(Colors.white) : null,
    );
    final button = filled
        ? FilledButton.icon(
            style: style,
            onPressed: onPressed,
            icon: Icon(icon, size: 14),
            label: Text(label, style: const TextStyle(fontSize: 11)),
          )
        : TextButton.icon(
            style: style,
            onPressed: onPressed,
            icon: Icon(icon, size: 14),
            label: Text(label, style: const TextStyle(fontSize: 11)),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: button,
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
