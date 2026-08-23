import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/app_scope.dart';
import '../models/models.dart';
import '../utils/app_utils.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  DateTime _anchor = DateTime.now();
  bool _monthly = false;

  static const _palettes = <List<Color>>[
    [
      Color(0xFF6750A4),
      Color(0xFF00897B),
      Color(0xFFFF8F00),
      Color(0xFF5E35B1),
      Color(0xFF43A047),
      Color(0xFFE53935),
    ],
    [
      Color(0xFF1565C0),
      Color(0xFF00ACC1),
      Color(0xFF7CB342),
      Color(0xFFF9A825),
      Color(0xFF8E24AA),
      Color(0xFFEF5350),
    ],
    [
      Color(0xFF00695C),
      Color(0xFF2E7D32),
      Color(0xFF558B2F),
      Color(0xFFF57F17),
      Color(0xFFE65100),
      Color(0xFF6A1B9A),
    ],
    [
      Color(0xFF283593),
      Color(0xFF00838F),
      Color(0xFFAD1457),
      Color(0xFFEF6C00),
      Color(0xFF4527A0),
      Color(0xFF2E7D32),
    ],
    [
      Color(0xFF455A64),
      Color(0xFF546E7A),
      Color(0xFF5D4037),
      Color(0xFF6D4C41),
      Color(0xFF37474F),
      Color(0xFF7E57C2),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final currentRange = _periodRange(_anchor, monthly: _monthly);
    final previousAnchor = _monthly
        ? DateTime(_anchor.year, _anchor.month - 1, 1)
        : _anchor.subtract(const Duration(days: 7));
    final previousRange = _periodRange(previousAnchor, monthly: _monthly);
    final sessionTarget = _monthly
        ? controller.monthlySessionGoal
        : controller.weeklySessionGoal;
    final sessionMinutes = _monthly
        ? controller.monthlySessionMinutes
        : controller.weeklySessionMinutes;
    final current = _buildStats(
      controller.workItems,
      controller.sessions,
      controller.habits,
      controller.habitEntries,
      currentRange,
      sessionTarget: sessionTarget,
      sessionMinutes: sessionMinutes,
    );
    final previous = _buildStats(
      controller.workItems,
      controller.sessions,
      controller.habits,
      controller.habitEntries,
      previousRange,
      sessionTarget: sessionTarget,
      sessionMinutes: sessionMinutes,
    );
    final palette =
        _palettes[controller.dashboardPaletteIndex
            .clamp(0, _palettes.length - 1)
            .toInt()];

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: (MediaQuery.sizeOf(context).width - 54)
                  .clamp(220, 500)
                  .toDouble(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overview Dashboard',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(_periodLabel(currentRange, monthly: _monthly)),
                ],
              ),
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Week')),
                ButtonSegment(value: true, label: Text('Month')),
              ],
              selected: {_monthly},
              onSelectionChanged: (value) =>
                  setState(() => _monthly = value.first),
            ),
            PopupMenuButton<int>(
              tooltip: 'Dashboard colors',
              initialValue: controller.dashboardPaletteIndex,
              onSelected: controller.setDashboardPalette,
              itemBuilder: (context) => List.generate(
                _palettes.length,
                (index) => PopupMenuItem(
                  value: index,
                  child: Row(
                    children: [
                      for (final color in _palettes[index])
                        Container(
                          width: 18,
                          height: 18,
                          margin: const EdgeInsets.only(right: 3),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text('Palette ${index + 1}'),
                    ],
                  ),
                ),
              ),
              child: const Chip(
                avatar: Icon(Icons.palette_outlined, size: 18),
                label: Text('Colors'),
              ),
            ),
            IconButton(
              tooltip: 'Previous',
              onPressed: () => setState(
                () => _anchor = _monthly
                    ? DateTime(_anchor.year, _anchor.month - 1)
                    : _anchor.subtract(const Duration(days: 7)),
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Today',
              onPressed: () => setState(() => _anchor = DateTime.now()),
              icon: const Icon(Icons.today),
            ),
            IconButton(
              tooltip: 'Next',
              onPressed: () => setState(
                () => _anchor = _monthly
                    ? DateTime(_anchor.year, _anchor.month + 1)
                    : _anchor.add(const Duration(days: 7)),
              ),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(
              color: palette[0],
              icon: Icons.task_alt,
              title: 'Items completed',
              value: '${current.completedItems}',
              detail:
                  '${(current.itemCompletion * 100).round()}% of dated work',
            ),
            _MetricCard(
              color: palette[1],
              icon: Icons.timer,
              title: 'Deep focus',
              value: '${current.focusMinutes} min',
              detail: '${formatHoursFromMinutes(current.focusMinutes)} hours',
            ),
            _MetricCard(
              color: palette[2],
              icon: Icons.local_fire_department,
              title: 'Focus streak',
              value: '${controller.focusDayStreak} days',
              detail: '${controller.todaySessionCount} sessions today',
            ),
            _MetricCard(
              color: palette[3],
              icon: Icons.flag,
              title: 'Goals hit',
              value: '${current.goalsHit}',
              detail: '${current.goalTarget} goal/milestone targets',
            ),
            _MetricCard(
              color: palette[4],
              icon: Icons.track_changes,
              title: 'Habit progress',
              value: '${(current.habitProgress * 100).round()}%',
              detail: '${current.habitCheckIns} positive check-ins',
            ),
            _MetricCard(
              color: palette[5],
              icon: Icons.military_tech,
              title: 'Reward points',
              value: '${controller.totalRewardPoints}',
              detail:
                  controller.currentRewardRank?.name ?? 'Build your first rank',
            ),
          ],
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Completion',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: current.itemCompletion,
                  minHeight: 14,
                  color: palette[0],
                  borderRadius: BorderRadius.circular(10),
                ),
                const SizedBox(height: 8),
                Text(
                  '${current.completedDueItems} dated items finished • '
                  '${current.openDueItems} still due • '
                  '${current.completedItems} total items completed in this period',
                  softWrap: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _PerformanceCharts(
          current: current,
          colors: palette,
          periodLabel: _monthly ? 'month' : 'week',
        ),
        const SizedBox(height: 18),
        _GoalComparisonBars(
          current: current,
          colors: palette,
          periodLabel: _monthly ? 'month' : 'week',
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _monthly
                      ? 'Current month vs previous month'
                      : 'Current week vs previous week',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Horizontal paired bars compare the selected ${_monthly ? 'month' : 'week'} with the previous period for every metric.',
                  softWrap: true,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                _ComparisonRow(
                  color: palette[0],
                  title: 'Dated work completed',
                  currentLabel: _ratioLabel(
                    current.completedDueItems,
                    current.itemTarget,
                    suffix: 'items',
                  ),
                  currentProgress: current.itemCompletion,
                  previousLabel: _ratioLabel(
                    previous.completedDueItems,
                    previous.itemTarget,
                    suffix: 'items',
                  ),
                  previousProgress: previous.itemCompletion,
                ),
                _ComparisonRow(
                  color: palette[1],
                  title: 'Focus minutes',
                  currentLabel: _ratioLabel(
                    current.focusMinutes,
                    current.focusMinuteTarget,
                    suffix: 'min',
                  ),
                  currentProgress: current.focusMinuteProgress,
                  previousLabel: _ratioLabel(
                    previous.focusMinutes,
                    previous.focusMinuteTarget,
                    suffix: 'min',
                  ),
                  previousProgress: previous.focusMinuteProgress,
                ),
                _ComparisonRow(
                  color: palette[2],
                  title: 'Completed focus sessions',
                  currentLabel: _ratioLabel(
                    current.completedSessions,
                    current.sessionTarget,
                    suffix: 'sessions',
                  ),
                  currentProgress: current.sessionProgress,
                  previousLabel: _ratioLabel(
                    previous.completedSessions,
                    previous.sessionTarget,
                    suffix: 'sessions',
                  ),
                  previousProgress: previous.sessionProgress,
                ),
                _ComparisonRow(
                  color: palette[3],
                  title: 'Goals and milestones hit',
                  currentLabel: _ratioLabel(
                    current.goalsHit,
                    current.goalTarget,
                    suffix: 'targets',
                  ),
                  currentProgress: current.goalProgress,
                  previousLabel: _ratioLabel(
                    previous.goalsHit,
                    previous.goalTarget,
                    suffix: 'targets',
                  ),
                  previousProgress: previous.goalProgress,
                ),
                _ComparisonRow(
                  color: palette[4],
                  title: 'Habits versus period goals',
                  currentLabel: _habitRatioLabel(current),
                  currentProgress: current.habitProgress,
                  previousLabel: _habitRatioLabel(previous),
                  previousProgress: previous.habitProgress,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  _PeriodRange _periodRange(DateTime anchor, {required bool monthly}) {
    final start = monthly
        ? DateTime(anchor.year, anchor.month)
        : startOfIsoWeek(anchor);
    final end = monthly
        ? DateTime(anchor.year, anchor.month + 1)
        : start.add(const Duration(days: 7));
    return _PeriodRange(start, end);
  }

  String _periodLabel(_PeriodRange range, {required bool monthly}) {
    if (monthly) return '${_monthName(range.start.month)} ${range.start.year}';
    return 'Week ${isoWeekNumber(range.start)} • '
        '${dateKey(range.start)} to '
        '${dateKey(range.end.subtract(const Duration(days: 1)))}';
  }

  String _ratioLabel(int actual, int target, {required String suffix}) {
    final percentage = target <= 0 ? 0 : ((actual / target) * 100).round();
    return '$actual / $target $suffix • $percentage%';
  }

  String _habitRatioLabel(_PeriodStats value) =>
      '${value.habitGoalEquivalent.toStringAsFixed(1)} / '
      '${value.habitTarget.toStringAsFixed(0)} goal-equivalents • '
      '${(value.habitProgress * 100).round()}% • '
      '${value.habitCheckIns} check-ins';

  String _monthName(int month) => const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][month - 1];
}

_PeriodStats _buildStats(
  List<WorkItem> items,
  List<TimeSession> sessions,
  List<Habit> habits,
  List<HabitEntry> habitEntries,
  _PeriodRange range, {
  required int sessionTarget,
  required int sessionMinutes,
}) {
  bool inRange(DateTime value) {
    final local = value.toLocal();
    return !local.isBefore(range.start) && local.isBefore(range.end);
  }

  final liveItems = items
      .where((item) => !item.isDeleted && item.status != WorkStatus.archived)
      .toList();
  final completedItems = liveItems
      .where((item) => item.isCompleted && inRange(item.updatedAt))
      .length;
  final dueItems = liveItems.where((item) {
    final due = item.dueDate?.toLocal();
    return due != null && !due.isBefore(range.start) && due.isBefore(range.end);
  }).toList();
  final completedDueItems = dueItems.where((item) => item.isCompleted).length;
  final openDueItems = dueItems.where((item) => !item.isCompleted).length;
  final periodSessions = sessions
      .where(
        (session) =>
            session.deletedAt == null &&
            session.completed &&
            session.mode != TimerMode.stopwatch &&
            inRange(session.startedAt),
      )
      .toList();
  final focusMinutes = periodSessions.fold<int>(
    0,
    (sum, session) => sum + (session.elapsedSeconds / 60).round(),
  );
  final completedSessions = periodSessions.length;
  final goalItems = dueItems
      .where(
        (item) =>
            item.type == WorkItemType.goal ||
            item.type == WorkItemType.milestone,
      )
      .toList();
  final goalsHit = goalItems.where((item) => item.isCompleted).length;
  final activeHabits = habits.where((habit) => !habit.isDeleted).toList();
  var habitGoalEquivalent = 0.0;
  var habitCheckIns = 0;
  for (final habit in activeHabits) {
    var actual = 0.0;
    for (final entry in habitEntries.where(
      (entry) => entry.deletedAt == null && entry.habitId == habit.id,
    )) {
      final day = DateTime.tryParse(entry.entryDate)?.toLocal();
      if (day != null &&
          !day.isBefore(range.start) &&
          day.isBefore(range.end)) {
        actual += entry.value;
        if (entry.value > 0) habitCheckIns++;
      }
    }
    var target = 0.0;
    for (
      var day = range.start;
      day.isBefore(range.end);
      day = day.add(const Duration(days: 1))
    ) {
      final daysInMonth = DateTime(day.year, day.month + 1, 0).day;
      target += habit.monthGoal / math.max(1, daysInMonth);
    }
    if (target > 0) {
      habitGoalEquivalent += (actual / target).clamp(0.0, 1.0);
    }
  }

  return _PeriodStats(
    completedItems: completedItems,
    completedDueItems: completedDueItems,
    openDueItems: openDueItems,
    itemTarget: dueItems.length,
    focusMinutes: focusMinutes,
    focusMinuteTarget: sessionTarget * sessionMinutes,
    completedSessions: completedSessions,
    sessionTarget: sessionTarget,
    goalsHit: goalsHit,
    goalTarget: goalItems.length,
    habitGoalEquivalent: habitGoalEquivalent,
    habitTarget: activeHabits.length.toDouble(),
    habitCheckIns: habitCheckIns,
  );
}

class _PeriodRange {
  const _PeriodRange(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

class _PeriodStats {
  const _PeriodStats({
    required this.completedItems,
    required this.completedDueItems,
    required this.openDueItems,
    required this.itemTarget,
    required this.focusMinutes,
    required this.focusMinuteTarget,
    required this.completedSessions,
    required this.sessionTarget,
    required this.goalsHit,
    required this.goalTarget,
    required this.habitGoalEquivalent,
    required this.habitTarget,
    required this.habitCheckIns,
  });

  final int completedItems;
  final int completedDueItems;
  final int openDueItems;
  final int itemTarget;
  final int focusMinutes;
  final int focusMinuteTarget;
  final int completedSessions;
  final int sessionTarget;
  final int goalsHit;
  final int goalTarget;
  final double habitGoalEquivalent;
  final double habitTarget;
  final int habitCheckIns;

  double _progress(num actual, num target) =>
      target <= 0 ? 0 : (actual / target).clamp(0.0, 1.0).toDouble();

  double get itemCompletion => _progress(completedDueItems, itemTarget);
  double get focusMinuteProgress => _progress(focusMinutes, focusMinuteTarget);
  double get sessionProgress => _progress(completedSessions, sessionTarget);
  double get goalProgress => _progress(goalsHit, goalTarget);
  double get habitProgress => _progress(habitGoalEquivalent, habitTarget);
}

class _PerformanceCharts extends StatelessWidget {
  const _PerformanceCharts({
    required this.current,
    required this.colors,
    required this.periodLabel,
  });

  final _PeriodStats current;
  final List<Color> colors;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final values = _overviewMetricValues(current, colors);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance at a glance',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'Each metric has its own circular chart for the selected $periodLabel. The colored arc is current progress and the pale arc is the amount remaining to reach the goal.',
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1320
                    ? 5
                    : constraints.maxWidth >= 780
                    ? 3
                    : constraints.maxWidth >= 500
                    ? 2
                    : 1;
                final cardWidth =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final value in values)
                      SizedBox(
                        width: cardWidth,
                        child: _MetricGoalCard(value: value),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricGoalCard extends StatelessWidget {
  const _MetricGoalCard({required this.value});
  final ({String label, double current, String detail, Color color}) value;

  @override
  Widget build(BuildContext context) {
    final progress = value.current.clamp(0.0, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: value.color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: value.color.withValues(alpha: .32)),
      ),
      child: Column(
        children: [
          Text(
            value.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _DonutProgressChart(
            progress: progress,
            color: value.color,
            semanticsLabel:
                '${value.label}: ${(progress * 100).round()} percent',
          ),
          const SizedBox(height: 10),
          Text(
            value.detail,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              _ChartLegend(color: value.color, label: 'Current'),
              _ChartLegend(
                color: value.color.withValues(alpha: .16),
                label: 'Remaining',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutProgressChart extends StatelessWidget {
  const _DonutProgressChart({
    required this.progress,
    required this.color,
    required this.semanticsLabel,
  });

  final double progress;
  final Color color;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel,
    child: SizedBox.square(
      dimension: 126,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(126),
            painter: _DonutProgressPainter(
              progress: progress,
              color: color,
              trackColor: color.withValues(alpha: .16),
              goalColor: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            '${(progress * 100).round()}%',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}

class _DonutProgressPainter extends CustomPainter {
  const _DonutProgressPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.goalColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final Color goalColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 15.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math
        .max(0.0, math.min(size.width, size.height) / 2 - 10)
        .toDouble();
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final current = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, track);
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress.clamp(0.0, 1.0).toDouble(),
        false,
        current,
      );
    }
    final marker = Paint()
      ..color = goalColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, center.dy - radius - 7),
      Offset(center.dx, center.dy - radius + 7),
      marker,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutProgressPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.goalColor != goalColor;
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}

class _GoalComparisonBars extends StatelessWidget {
  const _GoalComparisonBars({
    required this.current,
    required this.colors,
    required this.periodLabel,
  });

  final _PeriodStats current;
  final List<Color> colors;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final values = _overviewMetricValues(current, colors);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current $periodLabel vs goal',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'Vertical bars use the full outlined column as the 100% goal and the colored fill as current progress.',
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1050
                    ? 5
                    : constraints.maxWidth >= 650
                    ? 3
                    : constraints.maxWidth >= 420
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final value in values)
                      SizedBox(
                        width: width,
                        child: _VerticalGoalBar(value: value),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalGoalBar extends StatelessWidget {
  const _VerticalGoalBar({required this.value});

  final ({String label, double current, String detail, Color color}) value;

  @override
  Widget build(BuildContext context) {
    final progress = value.current.clamp(0.0, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: value.color.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: value.color.withValues(alpha: .24)),
      ),
      child: Column(
        children: [
          Text(
            value.label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 160,
            width: 76,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fillHeight = constraints.maxHeight * progress;
                return Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      width: 58,
                      decoration: BoxDecoration(
                        color: value.color.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: value.color.withValues(alpha: .68),
                          width: 2,
                        ),
                      ),
                    ),
                    Container(
                      width: 58,
                      height: fillHeight,
                      decoration: BoxDecoration(
                        color: value.color,
                        borderRadius: BorderRadius.vertical(
                          bottom: const Radius.circular(8),
                          top: Radius.circular(progress >= .98 ? 8.0 : 3.0),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 5,
                      child: Text(
                        'GOAL',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).round()}%',
            style: TextStyle(
              color: value.color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            value.detail,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

List<({String label, double current, String detail, Color color})>
_overviewMetricValues(_PeriodStats current, List<Color> colors) => [
  (
    label: 'Dated work',
    current: current.itemCompletion,
    detail: '${current.completedDueItems} of ${current.itemTarget} items',
    color: colors[0],
  ),
  (
    label: 'Focus minutes',
    current: current.focusMinuteProgress,
    detail: '${current.focusMinutes} of ${current.focusMinuteTarget} min',
    color: colors[1],
  ),
  (
    label: 'Sessions',
    current: current.sessionProgress,
    detail: '${current.completedSessions} of ${current.sessionTarget} sessions',
    color: colors[2],
  ),
  (
    label: 'Goals',
    current: current.goalProgress,
    detail: '${current.goalsHit} of ${current.goalTarget} targets',
    color: colors[3],
  ),
  (
    label: 'Habits',
    current: current.habitProgress,
    detail:
        '${current.habitGoalEquivalent.toStringAsFixed(1)} of ${current.habitTarget.toStringAsFixed(0)} goals',
    color: colors[4],
  ),
];

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.color,
    required this.title,
    required this.currentLabel,
    required this.currentProgress,
    required this.previousLabel,
    required this.previousProgress,
  });

  final Color color;
  final String title;
  final String currentLabel;
  final double currentProgress;
  final String previousLabel;
  final double previousProgress;

  @override
  Widget build(BuildContext context) {
    final delta = ((currentProgress - previousProgress) * 100).round();
    final deltaLabel = delta == 0
        ? 'No change'
        : delta > 0
        ? '+$delta points'
        : '$delta points';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .035),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    deltaLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            _ComparisonLine(
              label: 'Current • $currentLabel',
              progress: currentProgress,
              color: color,
              strong: true,
            ),
            const SizedBox(height: 8),
            _ComparisonLine(
              label: 'Previous period • $previousLabel',
              progress: previousProgress,
              color: color.withValues(alpha: .5),
              strong: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonLine extends StatelessWidget {
  const _ComparisonLine({
    required this.label,
    required this.progress,
    required this.color,
    required this.strong,
  });

  final String label;
  final double progress;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          softWrap: true,
          style: TextStyle(fontWeight: strong ? FontWeight.w700 : null),
        ),
        const SizedBox(height: 4),
        _ColoredProgress(
          value: progress,
          color: color,
          height: strong ? 14 : 10,
        ),
      ],
    );
  }
}

class _ColoredProgress extends StatelessWidget {
  const _ColoredProgress({
    required this.value,
    required this.color,
    required this.height,
  });
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: LinearProgressIndicator(
      value: value.clamp(0.0, 1.0),
      minHeight: height,
      color: color,
      backgroundColor: color.withValues(alpha: .12),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });
  final Color color;
  final IconData icon;
  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final foreground =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return SizedBox(
      width: 250,
      child: Card(
        color: color.withValues(alpha: .88),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: foreground),
              const SizedBox(height: 12),
              Text(title, softWrap: true, style: TextStyle(color: foreground)),
              Text(
                value,
                softWrap: true,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: foreground,
                ),
              ),
              Text(
                detail,
                softWrap: true,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: foreground.withValues(alpha: .9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
