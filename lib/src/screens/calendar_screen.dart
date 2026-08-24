import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/app_controller.dart';
import '../controllers/app_scope.dart';
import '../models/models.dart';
import '../utils/app_utils.dart';
import '../widgets/work_item_dialogs.dart';

DateTime _calendarDateForDue(DateTime dueDate) {
  // Older imports sometimes stored date-only values as UTC midnight. Treat
  // those as calendar dates instead of shifting them to the prior local day.
  if (dueDate.isUtc &&
      dueDate.hour == 0 &&
      dueDate.minute == 0 &&
      dueDate.second == 0) {
    return DateTime(dueDate.year, dueDate.month, dueDate.day);
  }
  final local = dueDate.toLocal();
  return DateTime(local.year, local.month, local.day);
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  String _view = 'year';
  DateTime _anchor = DateTime.now();
  String _status = 'all';
  String _weekSize = 'medium';

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final now = DateTime.now();
    final items = controller.workItems.where((item) {
      if (item.isDeleted || item.dueDate == null) return false;
      return switch (_status) {
        'overdue' => itemIsOverdue(item, now),
        'completed' => item.isCompleted,
        'active' => !item.isCompleted,
        _ => true,
      };
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Calendar • Week ${isoWeekNumber(now)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${(weeksInIsoYear(_anchor.year) - isoWeekNumber(now)).clamp(0, 53)} weeks left in ${_anchor.year}',
                  ),
                  if (MediaQuery.sizeOf(context).width < 700)
                    SizedBox(
                      width: 170,
                      child: DropdownButtonFormField<String>(
                        initialValue: _view,
                        decoration: const InputDecoration(
                          labelText: 'Calendar view',
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'year', child: Text('52 Weeks')),
                          DropdownMenuItem(value: 'quarter', child: Text('Quarter')),
                          DropdownMenuItem(value: 'month', child: Text('Month')),
                          DropdownMenuItem(value: 'week', child: Text('Week')),
                          DropdownMenuItem(value: 'day', child: Text('Day')),
                        ],
                        onChanged: (value) =>
                            setState(() => _view = value ?? _view),
                      ),
                    )
                  else
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'year', label: Text('52 Weeks')),
                        ButtonSegment(value: 'quarter', label: Text('Quarter')),
                        ButtonSegment(value: 'month', label: Text('Month')),
                        ButtonSegment(value: 'week', label: Text('Week')),
                        ButtonSegment(value: 'day', label: Text('Day')),
                      ],
                      selected: {_view},
                      onSelectionChanged: (value) {
                        setState(() => _view = value.first);
                      },
                    ),
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Items',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All dated'),
                        ),
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Active'),
                        ),
                        DropdownMenuItem(
                          value: 'overdue',
                          child: Text('Overdue'),
                        ),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('Completed'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _status = value ?? 'all');
                      },
                    ),
                  ),
                  if (_view == 'year')
                    SizedBox(
                      width: 145,
                      child: DropdownButtonFormField<String>(
                        initialValue: _weekSize,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Week size',
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'small',
                            child: Text('Small'),
                          ),
                          DropdownMenuItem(
                            value: 'medium',
                            child: Text('Medium'),
                          ),
                          DropdownMenuItem(
                            value: 'large',
                            child: Text('Large'),
                          ),
                          DropdownMenuItem(
                            value: 'xlarge',
                            child: Text('Extra large'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _weekSize = value ?? 'medium');
                        },
                      ),
                    ),
                  IconButton(
                    tooltip: 'Previous period',
                    onPressed: () => setState(() => _move(-1)),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: 'Today',
                    onPressed: () => setState(() => _anchor = DateTime.now()),
                    icon: const Icon(Icons.today),
                  ),
                  IconButton(
                    tooltip: 'Next period',
                    onPressed: () => setState(() => _move(1)),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: switch (_view) {
              'year' => _YearWeeks(
                year: _anchor.year,
                items: items,
                size: _weekSize,
                onTap: (start, end) =>
                    _openPeriodDialog(context, controller, start, end),
              ),
              'quarter' => _QuarterView(
                anchor: _anchor,
                items: items,
                onTap: (start, end) =>
                    _openPeriodDialog(context, controller, start, end),
              ),
              'month' => _MonthView(
                anchor: _anchor,
                items: items,
                onTap: (start, end) =>
                    _openPeriodDialog(context, controller, start, end),
              ),
              'week' => _WeekView(
                anchor: _anchor,
                items: items,
                onTap: (start, end) =>
                    _openPeriodDialog(context, controller, start, end),
              ),
              _ => _DayView(
                anchor: _anchor,
                items: items,
                onTap: (start, end) =>
                    _openPeriodDialog(context, controller, start, end),
              ),
            },
          ),
        ],
      ),
    );
  }

  void _move(int direction) {
    _anchor = switch (_view) {
      'year' => DateTime(_anchor.year + direction, 1, 1),
      'quarter' => DateTime(_anchor.year, _anchor.month + direction * 3, 1),
      'month' => DateTime(_anchor.year, _anchor.month + direction, 1),
      'week' => _anchor.add(Duration(days: direction * 7)),
      _ => _anchor.add(Duration(days: direction)),
    };
  }

  Future<void> _openPeriodDialog(
    BuildContext context,
    AppController controller,
    DateTime start,
    DateTime end,
  ) async {
    var selectedDate = sameDay(start, end) ? start : end;
    String? selectedItemId;
    WorkItemType? selectedLevel;
    var selectedParent = '__all__';
    final allAssignable =
        controller.workItems
            .where((item) => !item.isDeleted && !item.isCompleted)
            .toList()
          ..sort((a, b) => a.title.compareTo(b.title));
    final parentOptions =
        controller.workItems.where((item) => !item.isDeleted).toList()
          ..sort((a, b) => a.title.compareTo(b.title));
    final assignedInPeriod =
        controller.workItems.where((item) {
          final storedDue = item.dueDate;
          final due = storedDue == null ? null : _calendarDateForDue(storedDue);
          if (item.isDeleted || due == null) return false;
          final first = DateTime(start.year, start.month, start.day);
          final last = DateTime(end.year, end.month, end.day);
          return !due.isBefore(first) && !due.isAfter(last);
        }).toList()..sort((a, b) {
          final dateComparison = _calendarDateForDue(
            a.dueDate!,
          ).compareTo(_calendarDateForDue(b.dueDate!));
          return dateComparison != 0
              ? dateComparison
              : a.title.compareTo(b.title);
        });

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final assignable = allAssignable.where((item) {
            if (selectedLevel != null && item.type != selectedLevel) {
              return false;
            }
            if (selectedParent == '__root__') return item.parentId == null;
            if (selectedParent != '__all__') {
              return item.parentId == selectedParent;
            }
            return true;
          }).toList();
          if (selectedItemId != null &&
              !assignable.any((item) => item.id == selectedItemId)) {
            selectedItemId = null;
          }
          final periodLabel = start == end
              ? DateFormat('EEE, MMM d, yyyy').format(start)
              : '${DateFormat('EEE, MMM d').format(start)} – '
                    '${DateFormat('EEE, MMM d, yyyy').format(end)}';
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 24,
            ),
            title: Text('Plan $periodLabel'),
            content: SizedBox(
            width: (MediaQuery.sizeOf(context).width - 72)
                .clamp(240, 620)
                .toDouble(),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AssignedPeriodQuickView(
                      items: assignedInPeriod,
                      isSingleDay: sameDay(start, end),
                      periodLengthDays: end.difference(start).inDays.abs() + 1,
                      onDateSelected: (date) =>
                          setDialogState(() => selectedDate = date),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 240,
                          child: DropdownButtonFormField<WorkItemType?>(
                            initialValue: selectedLevel,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Level filter',
                            ),
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
                            onChanged: (value) => setDialogState(() {
                              selectedLevel = value;
                              selectedItemId = null;
                            }),
                          ),
                        ),
                        SizedBox(
                          width: 320,
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedParent,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Parent filter',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '__all__',
                                child: Text('All parents'),
                              ),
                              const DropdownMenuItem(
                                value: '__root__',
                                child: Text('Top-level items only'),
                              ),
                              ...parentOptions.map(
                                (parent) => DropdownMenuItem(
                                  value: parent.id,
                                  child: Text(
                                    '${parent.type.name}: ${parent.title}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) => setDialogState(() {
                              selectedParent = value ?? '__all__';
                              selectedItemId = null;
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedItemId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText:
                            'Assign an existing item (${assignable.length})',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Choose an item'),
                        ),
                        ...assignable.map(
                          (item) => DropdownMenuItem<String?>(
                            value: item.id,
                            child: Text(
                              '${item.type.name}: ${item.title}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => selectedItemId = value),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Due date'),
                      subtitle: Text(
                        DateFormat('EEE, MMM d, yyyy').format(selectedDate),
                      ),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: start,
                          lastDate: end,
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(dialogContext, 'new'),
                icon: const Icon(Icons.add),
                label: const Text('New item'),
              ),
              FilledButton.icon(
                onPressed: selectedItemId == null
                    ? null
                    : () => Navigator.pop(dialogContext, 'assign'),
                icon: const Icon(Icons.event_available),
                label: const Text('Assign date'),
              ),
            ],
          );
        },
      ),
    );
    if (!context.mounted) return;
    if (action == 'new') {
      await showWorkItemEditor(
        context,
        controller,
        initialDueDate: selectedDate,
      );
    } else if (action == 'assign') {
      final item = controller.itemById(selectedItemId);
      if (item != null) {
        await controller.updateWorkItem(
          item.copyWith(dueDate: selectedDate.toUtc()),
        );
      }
    }
  }
}

class _AssignedPeriodQuickView extends StatelessWidget {
  const _AssignedPeriodQuickView({
    required this.items,
    required this.isSingleDay,
    required this.periodLengthDays,
    required this.onDateSelected,
  });

  final List<WorkItem> items;
  final bool isSingleDay;
  final int periodLengthDays;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = isSingleDay
        ? 'this day'
        : periodLengthDays == 7
        ? 'this week'
        : 'this period';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.view_agenda_outlined, size: 19),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Items due in $label (${items.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (items.isEmpty)
            Text(
              'No items are due in this selected $label.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 210),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final due = _calendarDateForDue(item.dueDate!);
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () =>
                        onDateSelected(DateTime(due.year, due.month, due.day)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 78,
                            child: Text(
                              isSingleDay
                                  ? item.type.name
                                  : DateFormat('EEE, MMM d').format(due),
                              maxLines: 2,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  softWrap: true,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    decoration: item.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                Text(
                                  '${item.type.name} • ${item.status.name}',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            item.isCompleted
                                ? Icons.check_circle
                                : Icons.event_available_outlined,
                            size: 18,
                            color: item.isCompleted
                                ? Colors.green
                                : scheme.primary,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _YearWeeks extends StatefulWidget {
  const _YearWeeks({
    required this.year,
    required this.items,
    required this.size,
    required this.onTap,
  });

  final int year;
  final List<WorkItem> items;
  final String size;
  final void Function(DateTime start, DateTime end) onTap;

  @override
  State<_YearWeeks> createState() => _YearWeeksState();
}

class _YearWeeksState extends State<_YearWeeks> {
  int? _hoveredWeek;
  final ScrollController _scrollController = ScrollController();
  String? _lastAutoScrollKey;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _YearWeeks oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year || oldWidget.size != widget.size) {
      _lastAutoScrollKey = null;
    }
  }

  void _scheduleCurrentWeekScroll({
    required int crossAxisCount,
    required double cardHeight,
  }) {
    final now = DateTime.now();
    if (widget.year != isoWeekYear(now)) return;
    final scrollKey = '${widget.year}|${widget.size}|$crossAxisCount';
    if (_lastAutoScrollKey == scrollKey) return;
    _lastAutoScrollKey = scrollKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        _lastAutoScrollKey = null;
        return;
      }
      final currentWeekIndex = isoWeekNumber(now) - 1;
      final currentWeekRow = currentWeekIndex ~/ crossAxisCount;
      final target = (currentWeekRow * (cardHeight + 8.0))
          .clamp(0.0, _scrollController.position.maxScrollExtent)
          .toDouble();
      _scrollController.jumpTo(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentWeek = isoWeekNumber(now);
    final selectedWeek =
        _hoveredWeek ?? (widget.year == isoWeekYear(now) ? currentWeek : 1);
    final selectedStart = isoWeekStart(widget.year, selectedWeek);
    final selectedEnd = selectedStart.add(const Duration(days: 6));
    final selectedItems = _itemsBetween(
      widget.items,
      selectedStart,
      selectedEnd,
    );
    final extent = switch (widget.size) {
      'small' => 155.0,
      'large' => 260.0,
      'xlarge' => 340.0,
      _ => 205.0,
    };
    final baseHeight = switch (widget.size) {
      'small' => 118.0,
      'large' => 190.0,
      'xlarge' => 245.0,
      _ => 152.0,
    };
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final cardHeight = baseHeight * textScale.clamp(1.0, 1.45);

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            (constraints.maxWidth / (extent + 8.0)).ceil().clamp(1, 12).toInt();
        _scheduleCurrentWeekScroll(
          crossAxisCount: crossAxisCount,
          cardHeight: cardHeight,
        );
        return CustomScrollView(
          controller: _scrollController,
          slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Week $selectedWeek',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(_weekRangeLabel(selectedStart, selectedEnd)),
                Text(
                  selectedItems.isEmpty
                      ? 'Nothing due'
                      : selectedItems.take(5).map((e) => e.title).join(' • '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('${selectedItems.length} due'),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 40),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((context, index) {
              final week = index + 1;
              final start = isoWeekStart(widget.year, week);
              final end = start.add(const Duration(days: 6));
              final due = _itemsBetween(widget.items, start, end);
              final current =
                  widget.year == isoWeekYear(now) && week == currentWeek;
              final past = end.isBefore(startOfDay(now));
              final hovered = week == _hoveredWeek;
              return MouseRegion(
                onEnter: (_) => setState(() => _hoveredWeek = week),
                onExit: (_) {
                  if (_hoveredWeek == week) {
                    setState(() => _hoveredWeek = null);
                  }
                },
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => widget.onTap(start, end),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    decoration: BoxDecoration(
                      color: current
                          ? Colors.green.withValues(alpha: .32)
                          : past
                          ? Colors.grey.withValues(alpha: .18)
                          : Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: hovered
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: hovered ? 2 : 1,
                      ),
                    ),
                    padding: EdgeInsets.all(widget.size == 'small' ? 8 : 11),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final showPreview = constraints.maxHeight >= 145;
                        final dateLines = widget.size == 'small' ? 2 : 2;
                        return ClipRect(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Week $week',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  if (current)
                                    const Icon(
                                      Icons.location_on,
                                      color: Colors.green,
                                      size: 17,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _weekRangeLabel(start, end),
                                maxLines: dateLines,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${due.length} due',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color:
                                              due.any(
                                                (item) =>
                                                    itemIsOverdue(item, now),
                                              )
                                              ? Colors.red
                                              : null,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (showPreview && due.isNotEmpty)
                                        Text(
                                          due
                                              .take(
                                                widget.size == 'xlarge'
                                                    ? 4
                                                    : widget.size == 'large'
                                                    ? 3
                                                    : 2,
                                              )
                                              .map((item) => item.title)
                                              .join(' • '),
                                          maxLines: widget.size == 'xlarge'
                                              ? 4
                                              : widget.size == 'large'
                                              ? 3
                                              : 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
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
                  ),
                ),
              );
            }, childCount: weeksInIsoYear(widget.year)),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: extent,
              mainAxisExtent: cardHeight,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
          ),
        ),
          ],
        );
      },
    );
  }
}

class _QuarterView extends StatelessWidget {
  const _QuarterView({
    required this.anchor,
    required this.items,
    required this.onTap,
  });

  final DateTime anchor;
  final List<WorkItem> items;
  final void Function(DateTime start, DateTime end) onTap;

  @override
  Widget build(BuildContext context) {
    final firstMonth = ((anchor.month - 1) ~/ 3) * 3 + 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final months = List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.all(4),
            child: _MonthView(
              anchor: DateTime(anchor.year, firstMonth + index),
              items: items,
              onTap: onTap,
            ),
          ),
        );
        if (constraints.maxWidth < 900) {
          return ListView(
            children: months
                .map((month) => SizedBox(height: 520, child: month))
                .toList(),
          );
        }
        return Row(
          children: months.map((month) => Expanded(child: month)).toList(),
        );
      },
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.anchor,
    required this.items,
    required this.onTap,
  });

  final DateTime anchor;
  final List<WorkItem> items;
  final void Function(DateTime start, DateTime end) onTap;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(anchor.year, anchor.month, 1);
    final days = DateTime(anchor.year, anchor.month + 1, 0).day;
    final leading = first.weekday - 1;
    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                onTap(first, DateTime(anchor.year, anchor.month + 1, 0)),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                '${_month(anchor.month)} ${anchor.year}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          const Row(
            children: [
              Expanded(child: Center(child: Text('M'))),
              Expanded(child: Center(child: Text('T'))),
              Expanded(child: Center(child: Text('W'))),
              Expanded(child: Center(child: Text('T'))),
              Expanded(child: Center(child: Text('F'))),
              Expanded(child: Center(child: Text('S'))),
              Expanded(child: Center(child: Text('S'))),
            ],
          ),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
              ),
              itemCount: leading + days,
              itemBuilder: (context, index) {
                if (index < leading) return const SizedBox.shrink();
                final date = DateTime(
                  anchor.year,
                  anchor.month,
                  index - leading + 1,
                );
                final due = items
                    .where((item) => sameDay(item.dueDate!.toLocal(), date))
                    .toList();
                return InkWell(
                  onTap: () => onTap(date, date),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: sameDay(date, DateTime.now())
                          ? Colors.green.withValues(alpha: .35)
                          : null,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${date.day}'),
                        if (due.isNotEmpty)
                          Expanded(
                            child: Text(
                              due.take(2).map((item) => item.title).join('\n'),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 9),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView({
    required this.anchor,
    required this.items,
    required this.onTap,
  });

  final DateTime anchor;
  final List<WorkItem> items;
  final void Function(DateTime start, DateTime end) onTap;

  @override
  Widget build(BuildContext context) {
    final start = startOfIsoWeek(anchor);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 980 ? 980.0 : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Row(
              children: List.generate(7, (index) {
                final date = start.add(Duration(days: index));
                final due = items
                    .where((item) => sameDay(item.dueDate!.toLocal(), date))
                    .toList();
                return Expanded(
                  child: InkWell(
                    onTap: () => onTap(date, date),
                    child: Card(
                      color: sameDay(date, DateTime.now())
                          ? Colors.green.withValues(alpha: .25)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_weekday(date.weekday)} ${date.day}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Divider(),
                            ...due.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  item.title,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

class _DayView extends StatelessWidget {
  const _DayView({
    required this.anchor,
    required this.items,
    required this.onTap,
  });

  final DateTime anchor;
  final List<WorkItem> items;
  final void Function(DateTime start, DateTime end) onTap;

  @override
  Widget build(BuildContext context) {
    final due = items
        .where((item) => sameDay(item.dueDate!.toLocal(), anchor))
        .toList();
    return Card(
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${_weekday(anchor.weekday)} • ${dateKey(anchor)}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            trailing: FilledButton.icon(
              onPressed: () => onTap(anchor, anchor),
              icon: const Icon(Icons.add),
              label: const Text('Plan this day'),
            ),
          ),
          const Divider(),
          if (due.isEmpty)
            const Text('Nothing due.')
          else
            ...due.map(
              (item) => ListTile(
                leading: Icon(
                  item.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                ),
                title: Text(item.title),
                subtitle: Text('${item.type.name} • ${item.priority.name}'),
              ),
            ),
        ],
      ),
    );
  }
}

List<WorkItem> _itemsBetween(
  List<WorkItem> items,
  DateTime start,
  DateTime end,
) {
  return items.where((item) {
    final date = item.dueDate!.toLocal();
    return !date.isBefore(start) &&
        date.isBefore(end.add(const Duration(days: 1)));
  }).toList();
}

String _weekRangeLabel(DateTime start, DateTime end) =>
    '${DateFormat('EEE, MMM d').format(start)} – ${DateFormat('EEE, MMM d').format(end)}';

String _month(int value) => const [
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
][value - 1];

String _weekday(int value) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][value - 1];
