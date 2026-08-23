import 'dart:async';
import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../controllers/app_scope.dart';
import '../models/models.dart';
import '../services/focus_history_export_service.dart';
import '../services/timer_engine.dart';
import '../utils/app_utils.dart';
import '../widgets/focus_dialogs.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  WorkItemType? _level;
  String _dueFilter = 'all';
  String? _selectedItemId;
  bool? _timerHidden;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final engine = controller.timerEngine;
    _timerHidden ??= controller.focusPanelHidden;
    final now = DateTime.now();
    final candidates =
        controller.workItems.where((item) {
          if (item.isDeleted) return false;
          if (_level != null && item.type != _level) return false;
          if (_dueFilter == 'completed') return item.isCompleted;
          if (item.isCompleted) return false;
          if (_dueFilter == 'overdue') return itemIsOverdue(item, now);
          if (_dueFilter == 'due') {
            return item.dueDate != null && !itemIsOverdue(item, now);
          }
          if (_dueFilter == 'thisWeek') return itemDueThisWeek(item, now);
          return true;
        }).toList()..sort(
          (a, b) => dueSortScore(a, now).compareTo(dueSortScore(b, now)),
        );
    if (_selectedItemId != null &&
        !candidates.any((item) => item.id == _selectedItemId)) {
      _selectedItemId = null;
    }

    final weekStart = startOfIsoWeek(now);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.timer_outlined),
                SizedBox(
                  width: (MediaQuery.sizeOf(context).width - 74)
                      .clamp(220, 620)
                      .toDouble(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Focus To Win',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Text(
                        'General focus, linked focus, and study stopwatch. Completed sessions update today, this week, and this month.',
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    final next = !(_timerHidden ?? false);
                    setState(() => _timerHidden = next);
                    unawaited(controller.setFocusPanelHidden(next));
                  },
                  icon: Icon(
                    (_timerHidden ?? false)
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  label: Text(
                    (_timerHidden ?? false) ? 'Show timer' : 'Hide timer',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Offstage(
          offstage: _timerHidden ?? false,
          child: TickerMode(
            enabled: !(_timerHidden ?? false),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final timerCard = _LiveTimerCard(
                  engine: engine,
                  onGeneral: () => showQuickFocusDialog(context, controller),
                  onStopwatch: () => engine.start(
                    mode: TimerMode.stopwatch,
                    title: 'Study stopwatch',
                  ),
                );
                final chooser = _FocusChooser(
                  level: _level,
                  dueFilter: _dueFilter,
                  selectedItemId: _selectedItemId,
                  items: candidates,
                  onLevel: (value) => setState(() => _level = value),
                  onDue: (value) => setState(() => _dueFilter = value),
                  onItem: (value) => setState(() => _selectedItemId = value),
                  onStart: () {
                    final item = controller.itemById(_selectedItemId);
                    showQuickFocusDialog(context, controller, item: item);
                  },
                );
                if (constraints.maxWidth < 900) {
                  return Column(
                    children: [timerCard, const SizedBox(height: 12), chooser],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: timerCard),
                    const SizedBox(width: 12),
                    Expanded(child: chooser),
                  ],
                );
              },
            ),
          ),
        ),
        if (!(_timerHidden ?? false)) const SizedBox(height: 12),
        _DailyGoalPanel(controller: controller),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final weekly = _PeriodGoalPanel(
              title: 'This week’s focus goal',
              rangeLabel:
                  '${dateKey(weekStart)}–${dateKey(weekEnd.subtract(const Duration(days: 1)))}',
              sessionGoal: controller.weeklySessionGoal,
              dayGoal: controller.weeklyFocusDaysGoal,
              completedSessions: controller.completedSessionCountBetween(
                weekStart,
                weekEnd,
              ),
              completedMinutes: controller.focusMinutesBetween(
                weekStart,
                weekEnd,
              ),
              completedDays: controller.focusDaysBetween(weekStart, weekEnd),
              minutesPerSession: controller.weeklySessionMinutes,
              maxDays: 7,
              onGoalsChanged: (sessions, days, minutes) =>
                  controller.setWeeklyFocusGoals(
                    sessions: sessions,
                    days: days,
                    minutesPerSession: minutes,
                  ),
            );
            final monthly = _PeriodGoalPanel(
              title: 'This month’s focus goal',
              rangeLabel: '${_monthName(now.month)} ${now.year}',
              sessionGoal: controller.monthlySessionGoal,
              dayGoal: controller.monthlyFocusDaysGoal,
              completedSessions: controller.completedSessionCountBetween(
                monthStart,
                monthEnd,
              ),
              completedMinutes: controller.focusMinutesBetween(
                monthStart,
                monthEnd,
              ),
              completedDays: controller.focusDaysBetween(monthStart, monthEnd),
              minutesPerSession: controller.monthlySessionMinutes,
              maxDays: DateTime(now.year, now.month + 1, 0).day,
              onGoalsChanged: (sessions, days, minutes) =>
                  controller.setMonthlyFocusGoals(
                    sessions: sessions,
                    days: days,
                    minutesPerSession: minutes,
                  ),
            );
            if (constraints.maxWidth < 900) {
              return Column(
                children: [weekly, const SizedBox(height: 12), monthly],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: weekly),
                const SizedBox(width: 12),
                Expanded(child: monthly),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _FocusHistoryPanel(controller: controller),
      ],
    );
  }

  String _weekday(int day) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1];

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

class _LiveTimerCard extends StatelessWidget {
  const _LiveTimerCard({
    required this.engine,
    required this.onGeneral,
    required this.onStopwatch,
  });

  final TimerEngine engine;
  final VoidCallback onGeneral;
  final VoidCallback onStopwatch;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: engine,
      builder: (context, _) => _TimerCard(
        state: engine.state,
        engine: engine,
        onGeneral: onGeneral,
        onStopwatch: onStopwatch,
      ),
    );
  }
}

class _DailyGoalPanel extends StatelessWidget {
  const _DailyGoalPanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final completed = controller.todaySessionCount;
    final total = controller.dailySessionGoal;
    final left = (total - completed).clamp(0, total).toInt();
    final goalMinutes = total * controller.defaultSessionMinutes;
    final completedMinutes = controller.todayMinutes;
    final leftMinutes = (goalMinutes - completedMinutes)
        .clamp(0, goalMinutes)
        .toInt();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: (MediaQuery.sizeOf(context).width - 74)
                      .clamp(220, 600)
                      .toDouble(),
                  child: Text(
                    'Today’s focus goal',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                SizedBox(
                  width: 95,
                  child: TextFormField(
                    key: ValueKey('daily-sessions-$total'),
                    initialValue: '$total',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sessions'),
                    onFieldSubmitted: (value) => controller.setDailySessionGoal(
                      int.tryParse(value) ?? total,
                    ),
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    key: ValueKey(
                      'daily-minutes-${controller.defaultSessionMinutes}',
                    ),
                    initialValue: '${controller.defaultSessionMinutes}',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Min/session'),
                    onFieldSubmitted: (value) =>
                        controller.setDefaultSessionMinutes(
                          int.tryParse(value) ??
                              controller.defaultSessionMinutes,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: List.generate(
                total,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    color: index < completed
                        ? Colors.green
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: index < completed
                          ? Colors.green.shade700
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: index < completed
                      ? const Icon(Icons.check, size: 17, color: Colors.white)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _FocusMetric(
                  label: 'Total',
                  value: '$total sessions',
                  detail:
                      '$goalMinutes min • ${formatHoursFromMinutes(goalMinutes)} h',
                ),
                _FocusMetric(
                  label: 'Completed',
                  value: '$completed sessions',
                  detail:
                      '$completedMinutes min • ${formatHoursFromMinutes(completedMinutes)} h',
                ),
                _FocusMetric(
                  label: 'Left',
                  value: '$left sessions',
                  detail:
                      '$leftMinutes min • ${formatHoursFromMinutes(leftMinutes)} h',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodGoalPanel extends StatelessWidget {
  const _PeriodGoalPanel({
    required this.title,
    required this.rangeLabel,
    required this.sessionGoal,
    required this.dayGoal,
    required this.completedSessions,
    required this.completedMinutes,
    required this.completedDays,
    required this.minutesPerSession,
    required this.maxDays,
    required this.onGoalsChanged,
  });

  final String title;
  final String rangeLabel;
  final int sessionGoal;
  final int dayGoal;
  final int completedSessions;
  final int completedMinutes;
  final int completedDays;
  final int minutesPerSession;
  final int maxDays;
  final Future<void> Function(int sessions, int days, int minutesPerSession)
  onGoalsChanged;

  @override
  Widget build(BuildContext context) {
    final leftSessions = (sessionGoal - completedSessions)
        .clamp(0, sessionGoal)
        .toInt();
    final targetMinutes = sessionGoal * minutesPerSession;
    final leftMinutes = (targetMinutes - completedMinutes)
        .clamp(0, targetMinutes)
        .toInt();
    final leftDays = (dayGoal - completedDays).clamp(0, dayGoal).toInt();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            Text(rangeLabel, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 105,
                  child: TextFormField(
                    key: ValueKey('$title-$sessionGoal'),
                    initialValue: '$sessionGoal',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sessions'),
                    onFieldSubmitted: (value) => onGoalsChanged(
                      int.tryParse(value) ?? sessionGoal,
                      dayGoal,
                      minutesPerSession,
                    ),
                  ),
                ),
                SizedBox(
                  width: 95,
                  child: TextFormField(
                    key: ValueKey('$title-days-$dayGoal'),
                    initialValue: '$dayGoal',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Days'),
                    onFieldSubmitted: (value) => onGoalsChanged(
                      sessionGoal,
                      (int.tryParse(value) ?? dayGoal).clamp(1, maxDays),
                      minutesPerSession,
                    ),
                  ),
                ),
                SizedBox(
                  width: 115,
                  child: TextFormField(
                    key: ValueKey('$title-minutes-$minutesPerSession'),
                    initialValue: '$minutesPerSession',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Min/session'),
                    onFieldSubmitted: (value) => onGoalsChanged(
                      sessionGoal,
                      dayGoal,
                      (int.tryParse(value) ?? minutesPerSession).clamp(1, 720),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _CompactPeriodMetric(
              label: 'Total goal',
              sessions: sessionGoal,
              minutes: targetMinutes,
              days: dayGoal,
            ),
            _CompactPeriodMetric(
              label: 'Completed',
              sessions: completedSessions,
              minutes: completedMinutes,
              days: completedDays,
            ),
            _CompactPeriodMetric(
              label: 'Left',
              sessions: leftSessions,
              minutes: leftMinutes,
              days: leftDays,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactPeriodMetric extends StatelessWidget {
  const _CompactPeriodMetric({
    required this.label,
    required this.sessions,
    required this.minutes,
    required this.days,
  });

  final String label;
  final int sessions;
  final int minutes;
  final int days;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Wrap(
        spacing: 10,
        runSpacing: 3,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(width: 90, child: Text(label)),
          Text(
            '$sessions sessions • $minutes min '
            '(${formatHoursFromMinutes(minutes)} h) • $days days',
            softWrap: true,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({
    required this.state,
    required this.engine,
    required this.onGeneral,
    required this.onStopwatch,
  });

  final TimerStateRecord state;
  final TimerEngine engine;
  final VoidCallback onGeneral;
  final VoidCallback onStopwatch;

  @override
  Widget build(BuildContext context) {
    final seconds = state.mode == TimerMode.stopwatch
        ? state.elapsedSeconds
        : state.remainingSeconds;
    final progress =
        state.mode == TimerMode.stopwatch || state.durationSeconds <= 0
        ? null
        : (1 - state.remainingSeconds / state.durationSeconds)
              .clamp(0.0, 1.0)
              .toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final diameter = constraints.maxWidth
                    .clamp(180.0, 300.0)
                    .toDouble();
                return SizedBox(
                  width: diameter,
                  height: diameter,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 14,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                state.mode == TimerMode.stopwatch
                                    ? 'STUDY'
                                    : 'FOCUS',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              Text(
                                _format(seconds),
                                style: Theme.of(context).textTheme.displayMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              SizedBox(
                                width: 210,
                                child: Text(
                                  state.title,
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              alignment: WrapAlignment.center,
              children: [
                if (!state.running && !state.paused)
                  FilledButton.icon(
                    onPressed: onGeneral,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('General Focus'),
                  ),
                if (!state.running && !state.paused)
                  OutlinedButton.icon(
                    onPressed: onStopwatch,
                    icon: const Icon(Icons.timer_outlined),
                    label: const Text('Stopwatch'),
                  ),
                if (state.running)
                  FilledButton.tonalIcon(
                    onPressed: engine.pause,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  ),
                if (state.paused)
                  FilledButton.icon(
                    onPressed: engine.resume,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume'),
                  ),
                OutlinedButton(
                  onPressed: engine.reset,
                  child: const Text('Reset'),
                ),
                OutlinedButton(
                  onPressed: engine.isActive
                      ? () => engine.stop(saveSession: true)
                      : null,
                  child: const Text('Stop & Log'),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: state.autoRepeat,
              onChanged: engine.setAutoRepeat,
              title: const Text('Auto repeat'),
            ),
          ],
        ),
      ),
    );
  }

  String _format(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class _FocusChooser extends StatelessWidget {
  const _FocusChooser({
    required this.level,
    required this.dueFilter,
    required this.selectedItemId,
    required this.items,
    required this.onLevel,
    required this.onDue,
    required this.onItem,
    required this.onStart,
  });

  final WorkItemType? level;
  final String dueFilter;
  final String? selectedItemId;
  final List<WorkItem> items;
  final ValueChanged<WorkItemType?> onLevel;
  final ValueChanged<String> onDue;
  final ValueChanged<String?> onItem;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Linked focus', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            DropdownButtonFormField<WorkItemType?>(
              initialValue: level,
              decoration: const InputDecoration(labelText: 'Level'),
              items: [
                const DropdownMenuItem<WorkItemType?>(
                  value: null,
                  child: Text('All levels'),
                ),
                ...WorkItemType.values.map(
                  (value) => DropdownMenuItem<WorkItemType?>(
                    value: value,
                    child: Text(value.name),
                  ),
                ),
              ],
              onChanged: onLevel,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: dueFilter,
              decoration: const InputDecoration(labelText: 'Status / due'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All active')),
                DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                DropdownMenuItem(value: 'due', child: Text('Dated')),
                DropdownMenuItem(
                  value: 'thisWeek',
                  child: Text('Due this week'),
                ),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
              ],
              onChanged: (value) => onDue(value ?? 'all'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              initialValue: selectedItemId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Goal, project, module, or task',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Choose an item'),
                ),
                ...items.map(
                  (item) => DropdownMenuItem<String?>(
                    value: item.id,
                    child: Text(
                      '${item.type.name.toUpperCase()} • ${item.title}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: onItem,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: selectedItemId == null ? null : onStart,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Set up focus session'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusMetric extends StatelessWidget {
  const _FocusMetric({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(detail),
        ],
      ),
    );
  }
}

class _FocusHistoryPanel extends StatefulWidget {
  const _FocusHistoryPanel({required this.controller});

  final AppController controller;

  @override
  State<_FocusHistoryPanel> createState() => _FocusHistoryPanelState();
}

class _FocusHistoryPanelState extends State<_FocusHistoryPanel> {
  late int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final years = <int>{DateTime.now().year};
    for (final session in widget.controller.sessions) {
      years.add(session.startedAt.toLocal().year);
    }
    final orderedYears = years.toList()..sort((a, b) => b.compareTo(a));
    if (!years.contains(_year)) _year = orderedYears.first;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.history),
                SizedBox(
                  width: (MediaQuery.sizeOf(context).width - 74)
                      .clamp(220, 560)
                      .toDouble(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Permanent focus history',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Text(
                        'Hover for a total. Click any week or month for its daily breakdown. Sessions remain available across years.',
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 125,
                  child: DropdownButtonFormField<int>(
                    initialValue: _year,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      isDense: true,
                    ),
                    items: orderedYears
                        .map(
                          (year) => DropdownMenuItem(
                            value: year,
                            child: Text('$year'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _year = value ?? _year),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _exportCombined(context),
                  icon: const Icon(Icons.table_view_outlined),
                  label: const Text('Export all tiers'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: ExpansionTile(
            initiallyExpanded: true,
            leading: const Icon(Icons.calendar_view_week),
            title: Text('Weekly focus • $_year'),
            subtitle: const Text('Weeks 1–53 • click for hours by day'),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                child: _YearWeekStrip(
                  controller: widget.controller,
                  year: _year,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: ExpansionTile(
            initiallyExpanded: true,
            leading: const Icon(Icons.calendar_month_outlined),
            title: Text('Monthly focus • $_year'),
            subtitle: const Text('January–December • click for hours by day'),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                child: _YearMonthStrip(
                  controller: widget.controller,
                  year: _year,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: ExpansionTile(
            initiallyExpanded: true,
            leading: const Icon(Icons.insights_outlined),
            title: Text('Year focus summary • $_year'),
            subtitle: const Text('Monthly totals for the whole selected year'),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                child: _YearFocusSummary(
                  controller: widget.controller,
                  year: _year,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _exportCombined(BuildContext context) async {
    final path = await FocusHistoryExportService.exportCombined(
      year: _year,
      sessions: widget.controller.sessions,
    );
    if (context.mounted && path != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Focus history saved to $path')));
    }
  }
}

class _YearWeekStrip extends StatefulWidget {
  const _YearWeekStrip({required this.controller, required this.year});

  final AppController controller;
  final int year;

  @override
  State<_YearWeekStrip> createState() => _YearWeekStripState();
}

class _YearWeekStripState extends State<_YearWeekStrip> {
  int? _hoveredWeek;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weeks = weeksInIsoYear(widget.year);
    final selectedWeek =
        _hoveredWeek ??
        (widget.year == isoWeekYear(now) ? isoWeekNumber(now) : 1);
    final selectedStart = isoWeekStart(widget.year, selectedWeek);
    final selectedEnd = selectedStart.add(const Duration(days: 7));
    final selectedSeconds = _focusSecondsBetween(
      widget.controller.sessions,
      selectedStart,
      selectedEnd,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: List.generate(weeks, (index) {
            final week = index + 1;
            final start = isoWeekStart(widget.year, week);
            final end = start.add(const Duration(days: 7));
            final seconds = _focusSecondsBetween(
              widget.controller.sessions,
              start,
              end,
            );
            final isCurrent =
                week == isoWeekNumber(now) && widget.year == isoWeekYear(now);
            final isHovered = week == _hoveredWeek;
            return Tooltip(
              message:
                  'Week $week • ${dateKey(start)}–${dateKey(end.subtract(const Duration(days: 1)))} • ${_focusDuration(seconds)}',
              child: MouseRegion(
                onEnter: (_) => setState(() => _hoveredWeek = week),
                onExit: (_) {
                  if (_hoveredWeek == week) {
                    setState(() => _hoveredWeek = null);
                  }
                },
                child: InkWell(
                  onTap: () => _showFocusBreakdown(
                    context,
                    title: 'Week $week • ${widget.year}',
                    start: start,
                    endExclusive: end,
                    sessions: widget.controller.sessions,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? Colors.green
                          : seconds > 0
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isHovered
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: isHovered ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      '$week',
                      style: TextStyle(
                        color: isCurrent ? Colors.white : null,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        _FocusGlance(
          text:
              'Week $selectedWeek • ${dateKey(selectedStart)}–${dateKey(selectedEnd.subtract(const Duration(days: 1)))} • ${_focusDuration(selectedSeconds)} completed focus',
        ),
      ],
    );
  }
}

class _YearMonthStrip extends StatefulWidget {
  const _YearMonthStrip({required this.controller, required this.year});

  final AppController controller;
  final int year;

  @override
  State<_YearMonthStrip> createState() => _YearMonthStripState();
}

class _YearMonthStripState extends State<_YearMonthStrip> {
  int? _hoveredMonth;

  @override
  Widget build(BuildContext context) {
    final selected = _hoveredMonth ?? DateTime.now().month;
    final selectedStart = DateTime(widget.year, selected, 1);
    final selectedEnd = DateTime(widget.year, selected + 1, 1);
    final selectedSeconds = _focusSecondsBetween(
      widget.controller.sessions,
      selectedStart,
      selectedEnd,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(12, (index) {
            final month = index + 1;
            final start = DateTime(widget.year, month, 1);
            final end = DateTime(widget.year, month + 1, 1);
            final seconds = _focusSecondsBetween(
              widget.controller.sessions,
              start,
              end,
            );
            final hovered = month == _hoveredMonth;
            return Tooltip(
              message:
                  'Month $month • ${_monthName(month)} ${widget.year} • ${_focusDuration(seconds)}',
              child: MouseRegion(
                onEnter: (_) => setState(() => _hoveredMonth = month),
                onExit: (_) {
                  if (_hoveredMonth == month) {
                    setState(() => _hoveredMonth = null);
                  }
                },
                child: InkWell(
                  onTap: () => _showFocusBreakdown(
                    context,
                    title: '${_monthName(month)} ${widget.year}',
                    start: start,
                    endExclusive: end,
                    sessions: widget.controller.sessions,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 126,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: seconds > 0
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hovered
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: hovered ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$month • ${_monthShort(month)}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(_focusDuration(seconds)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        _FocusGlance(
          text:
              'Month $selected • ${_monthName(selected)} ${widget.year} • ${_focusDuration(selectedSeconds)} completed focus',
        ),
      ],
    );
  }
}

class _YearFocusSummary extends StatelessWidget {
  const _YearFocusSummary({required this.controller, required this.year});

  final AppController controller;
  final int year;

  @override
  Widget build(BuildContext context) {
    final secondsByMonth = List.generate(12, (index) {
      final month = index + 1;
      return _focusSecondsBetween(
        controller.sessions,
        DateTime(year, month, 1),
        DateTime(year, month + 1, 1),
      );
    });
    final maxSeconds = secondsByMonth.fold<int>(1, (a, b) => a > b ? a : b);
    final total = secondsByMonth.fold<int>(0, (sum, value) => sum + value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$year total • ${_focusDuration(total)} completed focus',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(12, (index) {
            final month = index + 1;
            final seconds = secondsByMonth[index];
            return InkWell(
              onTap: () => _showFocusBreakdown(
                context,
                title: '${_monthName(month)} $year',
                start: DateTime(year, month, 1),
                endExclusive: DateTime(year, month + 1, 1),
                sessions: controller.sessions,
              ),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 150,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_monthShort(month)} • ${_focusDuration(seconds)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 7),
                    LinearProgressIndicator(
                      value: seconds / maxSeconds,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _FocusGlance extends StatelessWidget {
  const _FocusGlance({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Text(text),
  );
}

Future<void> _showFocusBreakdown(
  BuildContext context, {
  required String title,
  required DateTime start,
  required DateTime endExclusive,
  required List<TimeSession> sessions,
}) async {
  final days = <({DateTime day, int seconds})>[];
  for (
    var day = DateTime(start.year, start.month, start.day);
    day.isBefore(endExclusive);
    day = day.add(const Duration(days: 1))
  ) {
    days.add((
      day: day,
      seconds: _focusSecondsBetween(
        sessions,
        day,
        day.add(const Duration(days: 1)),
      ),
    ));
  }
  final total = days.fold<int>(0, (sum, value) => sum + value.seconds);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      title: Text('$title • ${_focusDuration(total)}'),
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width - 48)
            .clamp(240, 520)
            .toDouble(),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: days.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final value = days[index];
            return ListTile(
              dense: true,
              leading: CircleAvatar(child: Text('${value.day.day}')),
              title: Text(
                '${_weekdayName(value.day.weekday)}, ${dateKey(value.day)}',
              ),
              trailing: Text(
                _focusDuration(value.seconds),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            );
          },
        ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: () async {
            final path = await FocusHistoryExportService.exportRange(
              title: 'SupeSlam_Focus_$title',
              start: start,
              endExclusive: endExclusive,
              sessions: sessions,
            );
            if (dialogContext.mounted && path != null) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(content: Text('Focus details saved to $path')),
              );
            }
          },
          icon: const Icon(Icons.table_view_outlined),
          label: const Text('Export'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

int _focusSecondsBetween(
  List<TimeSession> sessions,
  DateTime start,
  DateTime endExclusive,
) => sessions
    .where((session) {
      final local = session.startedAt.toLocal();
      return session.completed &&
          session.mode != TimerMode.stopwatch &&
          !local.isBefore(start) &&
          local.isBefore(endExclusive);
    })
    .fold<int>(0, (sum, session) => sum + session.elapsedSeconds);

String _focusDuration(int seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes min';
  return '${(minutes / 60).toStringAsFixed(1)} h';
}

String _weekdayName(int day) => const [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
][day - 1];

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

String _monthShort(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];
