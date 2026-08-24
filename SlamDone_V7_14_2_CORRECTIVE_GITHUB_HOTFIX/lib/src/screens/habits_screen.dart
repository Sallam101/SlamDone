import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../controllers/app_scope.dart';
import '../models/models.dart';
import '../utils/app_utils.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  static const double _dayLabelHeight = 60.0;
  static const double _dayHeaderHeight = _dayLabelHeight + 16.0;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _mobileDate = DateTime.now();
  final ScrollController _horizontal = ScrollController();
  final ScrollController _vertical = ScrollController();
  double? _nameWidth;
  final Map<String, double> _liveRowHeights = <String, double>{};
  String? _lastTodayScrollMonthKey;
  bool _todayScrollQueued = false;

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  void _queueScrollToToday() {
    final now = DateTime.now();
    if (now.year != _month.year || now.month != _month.month) return;
    final monthKey = '${_month.year}-${_month.month}';
    if (_todayScrollQueued || _lastTodayScrollMonthKey == monthKey) return;
    _todayScrollQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _todayScrollQueued = false;
      if (!mounted || !_horizontal.hasClients) return;
      final viewport = _horizontal.position.viewportDimension;
      final todayCenter = (now.day - .5) * 58.0;
      final desired = (todayCenter - viewport * .45)
          .clamp(0.0, _horizontal.position.maxScrollExtent)
          .toDouble();
      _horizontal.jumpTo(desired);
      _lastTodayScrollMonthKey = monthKey;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final habits = controller.habits.where((habit) => !habit.isDeleted).toList()
      ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    final width = MediaQuery.sizeOf(context).width;
    if (width < 700) {
      return _buildMobileHabits(context, controller, habits);
    }
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    _queueScrollToToday();
    final prefix =
        '${_month.year.toString().padLeft(4, '0')}-${_month.month.toString().padLeft(2, '0')}';
    final entries = <String, double>{
      for (final entry in controller.habitEntries.where(
        (entry) => entry.entryDate.startsWith(prefix),
      ))
        '${entry.habitId}|${entry.entryDate}': entry.value,
    };
    final nameWidth = (_nameWidth ?? controller.habitNameWidth)
        .clamp(190, 520)
        .toDouble();
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final rowHeights = <String, double>{
      for (final habit in habits)
        habit.id:
            (_liveRowHeights[habit.id] ??
                    controller.habitRowHeights[habit.id] ??
                    _habitRowHeight(habit, nameWidth, textScale))
                .clamp(88, 520)
                .toDouble(),
    };
    final contentHeight =
        _dayHeaderHeight +
        rowHeights.values.fold<double>(0, (sum, value) => sum + value);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.track_changes),
                  Text(
                    'Habit Month',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    '${_monthName(_month.month)} ${_month.year}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: () => _changeMonth(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  FilledButton.icon(
                    onPressed: () => _addHabit(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Habit'),
                  ),
                  FilterChip(
                    label: const Text('Bold totals'),
                    selected: controller.habitTotalsBold,
                    onSelected: controller.setHabitTotalsBold,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Scrollbar(
                controller: _vertical,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _vertical,
                  child: SizedBox(
                    height: contentHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HabitNamesColumn(
                          width: nameWidth,
                          habits: habits,
                          rowHeights: rowHeights,
                          onReorder: controller.reorderHabits,
                          onEdit: (habit) => _editHabit(context, habit),
                          onHeightUpdate: (habit, delta) {
                            final current = rowHeights[habit.id] ?? 96;
                            setState(() {
                              _liveRowHeights[habit.id] = (current + delta)
                                  .clamp(88, 520)
                                  .toDouble();
                            });
                          },
                          onHeightEnd: (habit) {
                            final height =
                                (_liveRowHeights[habit.id] ??
                                        rowHeights[habit.id] ??
                                        96)
                                    .clamp(88, 520)
                                    .toDouble();
                            controller.setHabitRowHeight(habit.id, height);
                          },
                        ),
                        _HabitWidthHandle(
                          onUpdate: (delta) {
                            setState(() {
                              _nameWidth = (nameWidth + delta)
                                  .clamp(190, 520)
                                  .toDouble();
                            });
                          },
                          onEnd: () => controller.setHabitNameWidth(
                            (_nameWidth ?? nameWidth)
                                .clamp(190, 520)
                                .toDouble(),
                          ),
                        ),
                        Expanded(
                          child: ScrollbarTheme(
                            data: ScrollbarTheme.of(context).copyWith(
                              crossAxisMargin: _dayLabelHeight,
                            ),
                            child: Scrollbar(
                              controller: _horizontal,
                              thumbVisibility: true,
                              scrollbarOrientation:
                                  ScrollbarOrientation.top,
                              child: SingleChildScrollView(
                                controller: _horizontal,
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: days * 58.0,
                                  height: contentHeight,
                                  child: Column(
                                    children: [
                                      _DayHeader(month: _month, days: days),
                                      for (final habit in habits)
                                        _HabitDayRow(
                                          height: rowHeights[habit.id] ?? 74,
                                          habit: habit,
                                          month: _month,
                                          days: days,
                                          values: entries,
                                          onSet: controller.setHabitValue,
                                          onNumberInput: (key, value) =>
                                              _numberInput(
                                                context,
                                                habit,
                                                key,
                                                value,
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        _HabitTotalsColumn(
                          habits: habits,
                          month: _month,
                          days: days,
                          values: entries,
                          rowHeights: rowHeights,
                          bold: controller.habitTotalsBold,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHabits(
    BuildContext context,
    AppController controller,
    List<Habit> habits,
  ) {
    final selectedKey = dateKey(_mobileDate);
    final values = <String, double>{
      for (final entry in controller.habitEntries.where(
        (entry) => entry.entryDate == selectedKey,
      ))
        entry.habitId: entry.value,
    };
    final today = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous day',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() {
                          _mobileDate = _mobileDate.subtract(const Duration(days: 1));
                        }),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _mobileDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null && mounted) {
                              setState(() => _mobileDate = picked);
                            }
                          },
                          child: Text(
                            _mobileDayLabel(_mobileDate),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next day',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() {
                          _mobileDate = _mobileDate.add(const Duration(days: 1));
                        }),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: sameDay(_mobileDate, today)
                              ? null
                              : () => setState(() => _mobileDate = today),
                          icon: const Icon(Icons.today_outlined, size: 18),
                          label: const Text('Today'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _addHabit(context),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Habit'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: habits.isEmpty
                ? const Center(child: Text('No habits yet. Add one above.'))
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: habits.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 7),
                    itemBuilder: (context, index) {
                      final habit = habits[index];
                      final value = values[habit.id] ?? 0;
                      return Card(
                        color: parseHexColor(habit.colorHex),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          habit.title,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: parseHexColor(habit.textColorHex),
                                          ),
                                        ),
                                        if (habit.notes.isNotEmpty)
                                          Text(
                                            habit.notes,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Edit habit',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _editHabit(context, habit),
                                    icon: const Icon(Icons.more_horiz),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (habit.kind == HabitKind.checkbox)
                                SizedBox(
                                  height: 48,
                                  child: FilledButton.tonalIcon(
                                    onPressed: () => controller.setHabitValue(
                                      habit,
                                      selectedKey,
                                      value > 0 ? 0 : 1,
                                    ),
                                    icon: Icon(
                                      value > 0
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                    ),
                                    label: Text(value > 0 ? 'Logged ✓' : 'Log for this day'),
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    IconButton.filledTonal(
                                      tooltip: 'Decrease',
                                      onPressed: () => controller.setHabitValue(
                                        habit,
                                        selectedKey,
                                        (value - 1).clamp(0, double.infinity).toDouble(),
                                      ),
                                      icon: const Icon(Icons.remove_rounded),
                                    ),
                                    Expanded(
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () => _numberInput(
                                          context,
                                          habit,
                                          selectedKey,
                                          value,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          child: Column(
                                            children: [
                                              Text(
                                                _mobileNumber(value),
                                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              if (habit.unit.isNotEmpty) Text(habit.unit),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton.filled(
                                      tooltip: 'Increase',
                                      onPressed: () => controller.setHabitValue(
                                        habit,
                                        selectedKey,
                                        value + 1,
                                      ),
                                      icon: const Icon(Icons.add_rounded),
                                    ),
                                  ],
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

  String _mobileDayLabel(DateTime value) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${days[value.weekday - 1]} • ${months[value.month - 1]} ${value.day}, ${value.year}';
  }

  String _mobileNumber(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _lastTodayScrollMonthKey = null;
    });
  }

  Future<void> _addHabit(BuildContext context) async {
    final title = TextEditingController();
    final goal = TextEditingController(text: '31');
    final unit = TextEditingController();
    final notes = TextEditingController();
    var kind = HabitKind.checkbox;
    String? rowColorHex;
    String? textColorHex;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 24,
          ),
          title: const Text('Add habit'),
          content: SizedBox(
            width: (MediaQuery.sizeOf(context).width - 72)
                .clamp(240, 460)
                .toDouble(),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Habit'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<HabitKind>(
                    initialValue: kind,
                    items: const [
                      DropdownMenuItem(
                        value: HabitKind.checkbox,
                        child: Text('Checkbox'),
                      ),
                      DropdownMenuItem(
                        value: HabitKind.number,
                        child: Text('Number input'),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => kind = value ?? kind),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: goal,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Monthly goal',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: unit,
                          decoration: const InputDecoration(labelText: 'Unit'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notes,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Habit note (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _HabitColorButton(
                        label: 'Row color',
                        colorHex: rowColorHex,
                        onPressed: () async {
                          final selected = await _pickHabitColor(
                            dialogContext,
                            title: 'Habit row color',
                            current: rowColorHex,
                          );
                          if (selected != null) {
                            setDialogState(
                              () => rowColorHex = selected.isEmpty
                                  ? null
                                  : selected,
                            );
                          }
                        },
                      ),
                      _HabitColorButton(
                        label: 'Font color',
                        colorHex: textColorHex,
                        onPressed: () async {
                          final selected = await _pickHabitColor(
                            dialogContext,
                            title: 'Habit font color',
                            current: textColorHex,
                          );
                          if (selected != null) {
                            setDialogState(
                              () => textColorHex = selected.isEmpty
                                  ? null
                                  : selected,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && title.text.trim().isNotEmpty && context.mounted) {
      await AppScope.of(context).createHabit(
        title: title.text.trim(),
        kind: kind,
        monthGoal: double.tryParse(goal.text) ?? 0,
        unit: unit.text.trim(),
        notes: notes.text.trim(),
        colorHex: rowColorHex,
        textColorHex: textColorHex,
      );
    }
  }

  Future<void> _editHabit(BuildContext context, Habit habit) async {
    final title = TextEditingController(text: habit.title);
    final goal = TextEditingController(text: '${habit.monthGoal}');
    final notes = TextEditingController(text: habit.notes);
    String? rowColorHex = habit.colorHex;
    String? textColorHex = habit.textColorHex;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 24,
          ),
          title: const Text('Edit habit'),
          content: SizedBox(
            width: (MediaQuery.sizeOf(context).width - 72)
                .clamp(240, 460)
                .toDouble(),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: goal,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monthly goal',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notes,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Habit note (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _HabitColorButton(
                        label: 'Row color',
                        colorHex: rowColorHex,
                        onPressed: () async {
                          final selected = await _pickHabitColor(
                            dialogContext,
                            title: 'Habit row color',
                            current: rowColorHex,
                          );
                          if (selected != null) {
                            setDialogState(
                              () => rowColorHex = selected.isEmpty
                                  ? null
                                  : selected,
                            );
                          }
                        },
                      ),
                      _HabitColorButton(
                        label: 'Font color',
                        colorHex: textColorHex,
                        onPressed: () async {
                          final selected = await _pickHabitColor(
                            dialogContext,
                            title: 'Habit font color',
                            current: textColorHex,
                          );
                          if (selected != null) {
                            setDialogState(
                              () => textColorHex = selected.isEmpty
                                  ? null
                                  : selected,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await AppScope.of(context).deleteHabit(habit);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, false);
                }
              },
              child: const Text('Delete'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && context.mounted) {
      await AppScope.of(context).updateHabit(
        habit.copyWith(
          title: title.text.trim(),
          monthGoal: double.tryParse(goal.text) ?? habit.monthGoal,
          notes: notes.text.trim(),
          colorHex: rowColorHex,
          textColorHex: textColorHex,
        ),
      );
    }
  }

  Future<String?> _pickHabitColor(
    BuildContext context, {
    required String title,
    String? current,
  }) {
    const palette = <String>[
      '#1565C0',
      '#00897B',
      '#2E7D32',
      '#EF6C00',
      '#C62828',
      '#8E24AA',
      '#5E35B1',
      '#6D4C41',
      '#455A64',
      '#212121',
      '#FFFFFF',
    ];
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, ''),
              child: const Text('Automatic'),
            ),
            for (final hex in palette)
              InkWell(
                onTap: () => Navigator.pop(dialogContext, hex),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: parseHexColor(hex),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: current?.toUpperCase() == hex
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      width: current?.toUpperCase() == hex ? 4 : 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _numberInput(
    BuildContext context,
    Habit habit,
    String key,
    double current,
  ) async {
    final value = TextEditingController(text: '$current');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${habit.title} • $key'),
        content: TextField(
          controller: value,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: habit.unit.isEmpty ? 'Value' : habit.unit,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (accepted == true && context.mounted) {
      await AppScope.of(
        context,
      ).setHabitValue(habit, key, double.tryParse(value.text) ?? current);
    }
  }

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

double _habitRowHeight(Habit habit, double width, double textScale) {
  final scale = textScale.clamp(0.9, 1.8).toDouble();
  var height = 96.0 * scale;
  final charsPerLine = ((width - 82) / (8.5 * scale)).clamp(12, 52);
  final titleLines = (habit.title.trim().length / charsPerLine).ceil().clamp(
    1,
    5,
  );
  height += (titleLines - 1) * 20 * scale;
  if (habit.notes.trim().isNotEmpty) {
    final noteLines = (habit.notes.trim().length / charsPerLine).ceil().clamp(
      1,
      5,
    );
    height += (22 + noteLines * 15) * scale;
  }
  return height.clamp(96, 340).toDouble();
}

class _HabitWidthHandle extends StatelessWidget {
  const _HabitWidthHandle({required this.onUpdate, required this.onEnd});

  final ValueChanged<double> onUpdate;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onUpdate(details.delta.dx),
        onHorizontalDragEnd: (_) => onEnd(),
        child: Container(
          width: 10,
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Center(
            child: Container(
              width: 2,
              height: 52,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .5),
            ),
          ),
        ),
      ),
    );
  }
}

class _HabitNamesColumn extends StatelessWidget {
  const _HabitNamesColumn({
    required this.width,
    required this.habits,
    required this.rowHeights,
    required this.onReorder,
    required this.onEdit,
    required this.onHeightUpdate,
    required this.onHeightEnd,
  });

  final double width;
  final List<Habit> habits;
  final Map<String, double> rowHeights;
  final Future<void> Function(List<Habit>) onReorder;
  final ValueChanged<Habit> onEdit;
  final void Function(Habit habit, double delta) onHeightUpdate;
  final ValueChanged<Habit> onHeightEnd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        children: [
          Container(
            height: _HabitsScreenState._dayHeaderHeight,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                  width: 3,
                ),
              ),
            ),
            child: const Text(
              'Habit / monthly target',
              maxLines: 2,
              softWrap: true,
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: habits.length,
            onReorderItem: (oldIndex, newIndex) {
              final reordered = [...habits];
              final moved = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, moved);
              onReorder(reordered);
            },
            itemBuilder: (context, index) {
              final habit = habits[index];
              final textColor = parseHexColor(habit.textColorHex);
              return AnimatedContainer(
                key: ValueKey(habit.id),
                duration: const Duration(milliseconds: 70),
                curve: Curves.easeOut,
                height: rowHeights[habit.id] ?? 74,
                padding: const EdgeInsets.all(8),
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: parseHexColor(habit.colorHex)?.withValues(alpha: 0.10),
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      bottom: 10,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Icon(
                              Icons.drag_handle,
                              size: 18,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: ClipRect(
                              child: SingleChildScrollView(
                                physics: const NeverScrollableScrollPhysics(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      habit.title,
                                      softWrap: true,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: textColor,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Goal ${habit.monthGoal.toStringAsFixed(habit.monthGoal % 1 == 0 ? 0 : 1)} ${habit.unit}',
                                      softWrap: true,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: textColor),
                                    ),
                                    if (habit.notes.trim().isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        habit.notes.trim(),
                                        softWrap: true,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: textColor?.withValues(
                                                alpha: .78,
                                              ),
                                              height: 1.1,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit habit',
                            constraints: const BoxConstraints.tightFor(
                              width: 34,
                              height: 34,
                            ),
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: textColor,
                            ),
                            onPressed: () => onEdit(habit),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 30,
                      right: 30,
                      bottom: 0,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeUpDown,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: (details) =>
                              onHeightUpdate(habit, details.delta.dy),
                          onVerticalDragEnd: (_) => onHeightEnd(habit),
                          child: Tooltip(
                            message: 'Resize habit row',
                            child: SizedBox(
                              height: 12,
                              child: Center(
                                child: Container(
                                  width: 42,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.outline
                                        .withValues(alpha: .68),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HabitColorButton extends StatelessWidget {
  const _HabitColorButton({
    required this.label,
    required this.colorHex,
    required this.onPressed,
  });

  final String label;
  final String? colorHex;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = parseHexColor(colorHex);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      label: Text(label),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.month, required this.days});
  final DateTime month;
  final int days;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _HabitsScreenState._dayHeaderHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(days, (index) {
          final date = DateTime(month.year, month.month, index + 1);
          final current = sameDay(date, DateTime.now());
          return Container(
            width: 58,
            height: _HabitsScreenState._dayLabelHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: current ? Colors.green.withValues(alpha: 0.35) : null,
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                  width: 3,
                ),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1],
                  style: const TextStyle(fontSize: 9),
                ),
                Text(
                  '${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _HabitDayRow extends StatelessWidget {
  const _HabitDayRow({
    required this.height,
    required this.habit,
    required this.month,
    required this.days,
    required this.values,
    required this.onSet,
    required this.onNumberInput,
  });

  final double height;
  final Habit habit;
  final DateTime month;
  final int days;
  final Map<String, double> values;
  final Future<void> Function(Habit, String, double) onSet;
  final void Function(String, double) onNumberInput;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 70),
      curve: Curves.easeOut,
      height: height,
      child: Row(
        children: List.generate(days, (index) {
          final date = DateTime(month.year, month.month, index + 1);
          final key = dateKey(date);
          final value = values['${habit.id}|$key'] ?? 0;
          final current = sameDay(date, DateTime.now());
          final missed =
              date.isBefore(startOfDay(DateTime.now())) && value <= 0;
          final habitColor = parseHexColor(habit.colorHex);
          final habitTextColor = parseHexColor(habit.textColorHex);
          return Container(
            width: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: current
                  ? Colors.green.withValues(alpha: 0.18)
                  : missed
                  ? Colors.red.withValues(alpha: 0.12)
                  : null,
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: habit.kind == HabitKind.checkbox
                ? Checkbox(
                    value: value > 0,
                    activeColor: habitColor,
                    checkColor: habitColor == null
                        ? null
                        : readableTextColor(habitColor),
                    onChanged: (checked) =>
                        onSet(habit, key, checked == true ? 1 : 0),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(5),
                        onTap: () => onSet(habit, key, value + 1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            Icons.keyboard_arrow_up,
                            size: 18,
                            color: habitTextColor,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        height: 28,
                        child: TextButton(
                          onPressed: () => onNumberInput(key, value),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                          ),
                          child: Text(
                            value.toStringAsFixed(value % 1 == 0 ? 0 : 1),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: habitTextColor),
                          ),
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(5),
                        onTap: () => onSet(
                          habit,
                          key,
                          (value - 1).clamp(0, 999999).toDouble(),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: habitTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
          );
        }),
      ),
    );
  }
}

class _HabitTotalsColumn extends StatelessWidget {
  const _HabitTotalsColumn({
    required this.habits,
    required this.month,
    required this.days,
    required this.values,
    required this.rowHeights,
    required this.bold,
  });

  final List<Habit> habits;
  final DateTime month;
  final int days;
  final Map<String, double> values;
  final Map<String, double> rowHeights;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Column(
        children: [
          Container(
            height: _HabitsScreenState._dayHeaderHeight,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                  width: 3,
                ),
              ),
            ),
            child: const Text(
              'Total / progress',
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          for (final habit in habits)
            _HabitTotalCell(
              height: rowHeights[habit.id] ?? 74,
              habit: habit,
              month: month,
              days: days,
              values: values,
              bold: bold,
            ),
        ],
      ),
    );
  }
}

class _HabitTotalCell extends StatelessWidget {
  const _HabitTotalCell({
    required this.height,
    required this.habit,
    required this.month,
    required this.days,
    required this.values,
    required this.bold,
  });

  final double height;
  final Habit habit;
  final DateTime month;
  final int days;
  final Map<String, double> values;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final total = List.generate(
      days,
      (index) =>
          values['${habit.id}|${dateKey(DateTime(month.year, month.month, index + 1))}'] ??
          0,
    ).fold<double>(0, (sum, value) => sum + value);
    final progress = habit.monthGoal <= 0
        ? 0.0
        : (total / habit.monthGoal).clamp(0.0, 1.0).toDouble();
    final textColor = parseHexColor(habit.textColorHex);
    final weight = bold ? FontWeight.w800 : FontWeight.w400;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 70),
      curve: Curves.easeOut,
      height: height,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: parseHexColor(habit.colorHex)?.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${total.toStringAsFixed(total % 1 == 0 ? 0 : 1)} ${habit.unit}',
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor, fontWeight: weight),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: progress,
              color: parseHexColor(habit.colorHex),
            ),
            const SizedBox(height: 3),
            Text(
              '${(progress * 100).round()}% • ${(habit.monthGoal - total).clamp(0, 999999).toStringAsFixed(0)} left',
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: textColor,
                fontWeight: weight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
