import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../controllers/app_scope.dart';
import '../models/models.dart';
import '../utils/app_utils.dart';
import '../utils/work_item_filters.dart';
import '../widgets/work_item_tree_list.dart';

class DoFirstScreen extends StatefulWidget {
  const DoFirstScreen({super.key});

  @override
  State<DoFirstScreen> createState() => _DoFirstScreenState();
}

class _DoFirstScreenState extends State<DoFirstScreen> {
  WorkItemType? _level;
  String _period = 'all';
  String _status = 'active';
  String _importance = 'all';
  String _category = 'all';
  String _energy = 'all';
  String _recurrence = 'all';
  bool _includeDescendants = false;
  bool _filtersVisible = false;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    unawaited(_loadFilters(AppScope.of(context)));
  }

  Future<void> _loadFilters(AppController controller) async {
    final values = await Future.wait([
      controller.readUiSetting('do_first_period'),
      controller.readUiSetting('do_first_status'),
      controller.readUiSetting('do_first_importance'),
      controller.readUiSetting('do_first_level'),
      controller.readUiSetting('do_first_descendants'),
      controller.readUiSetting('do_first_category'),
      controller.readUiSetting('do_first_energy'),
      controller.readUiSetting('do_first_recurrence'),
    ]);
    if (!mounted) return;
    setState(() {
      _period = values[0] ?? 'all';
      _status = values[1] ?? 'active';
      _importance = values[2] ?? 'all';
      _level = WorkItemType.values
          .where((value) => value.name == values[3])
          .firstOrNull;
      _includeDescendants = values[4] == 'true';
      _category = values[5] ?? 'all';
      _energy = values[6] ?? 'all';
      _recurrence = values[7] ?? 'all';
    });
  }

  Future<void> _save(AppController controller, String key, String value) async {
    await controller.writeUiSetting(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final mobile = MediaQuery.sizeOf(context).width < 700;
    final now = DateTime.now();
    final eligible = controller.workItems.where((item) {
      if (item.isDeleted || item.status == WorkStatus.archived) return false;
      if (!_matchesStatus(item)) return false;
      if (!_matchesPeriod(item, now)) return false;
      if (!_matchesImportance(item)) return false;
      if (!_matchesCategory(item)) return false;
      if (!_matchesEnergy(item)) return false;
      if (!_matchesRecurrence(item)) return false;
      return true;
    }).toList();

    final items = <WorkItem>[];
    if (_level == null) {
      items.addAll(eligible);
    } else {
      final eligibleIds = eligible.map((item) => item.id).toSet();
      final roots = eligible.where((item) => item.type == _level).toList();
      items.addAll(roots);
      if (_includeDescendants) {
        final added = items.map((item) => item.id).toSet();
        for (final root in roots) {
          for (final descendant in controller.descendantsOf(root.id)) {
            if (eligibleIds.contains(descendant.id) &&
                added.add(descendant.id)) {
              items.add(descendant);
            }
          }
        }
      }
    }
    items.sort((a, b) {
      final bucketCompare =
          _priorityBucket(a, now).compareTo(_priorityBucket(b, now));
      if (bucketCompare != 0) return bucketCompare;
      final dueCompare = dueSortScore(a, now).compareTo(dueSortScore(b, now));
      if (dueCompare != 0) return dueCompare;
      final sortCompare = a.sortKey.compareTo(b.sortKey);
      if (sortCompare != 0) return sortCompare;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    return Padding(
      padding: EdgeInsets.all(mobile ? 8 : 14),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(mobile ? 10 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt, color: Colors.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Do First',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _filtersVisible = !_filtersVisible),
                        icon: Icon(
                          _filtersVisible
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.tune_rounded,
                        ),
                        label: Text(
                          _filtersVisible ? 'Hide filters' : 'Show filters',
                        ),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.topCenter,
                    child: !_filtersVisible
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (!mobile)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 10),
                                    child: Text(
                                      'Filter the queue when you need to; the default queue keeps the highest-action items first.',
                                    ),
                                  ),
                                LayoutBuilder(
                                  builder: (context, constraints) => Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      _levelDropdown(
                                        controller,
                                        _fieldWidth(constraints.maxWidth, 190),
                                      ),
                                      _stringDropdown(
                                        width: _fieldWidth(
                                          constraints.maxWidth,
                                          205,
                                        ),
                                        label: 'Period / scope',
                                        value: _period,
                                        items: const {
                                          'today': 'Today',
                                          'week': 'This week + overdue',
                                          'month': 'This month + overdue',
                                          'overdue': 'Overdue only',
                                          'undated': 'No due date',
                                          'all': 'Any period',
                                        },
                                        onChanged: (value) {
                                          setState(() => _period = value);
                                          unawaited(
                                            _save(
                                              controller,
                                              'do_first_period',
                                              value,
                                            ),
                                          );
                                        },
                                      ),
                                      _stringDropdown(
                                        width: _fieldWidth(
                                          constraints.maxWidth,
                                          180,
                                        ),
                                        label: 'Status',
                                        value: _status,
                                        items: const {
                                          'active': 'Active only',
                                          'completed': 'Completed only',
                                          'all': 'Active + completed',
                                        },
                                        onChanged: (value) {
                                          setState(() => _status = value);
                                          unawaited(
                                            _save(
                                              controller,
                                              'do_first_status',
                                              value,
                                            ),
                                          );
                                        },
                                      ),
                                      _stringDropdown(
                                        width: _fieldWidth(
                                          constraints.maxWidth,
                                          180,
                                        ),
                                        label: 'Importance',
                                        value: _importance,
                                        items: const {
                                          'all': 'All importance',
                                          'urgent': 'Urgent',
                                          'important': 'Important',
                                          'normal': 'Normal',
                                        },
                                        onChanged: (value) {
                                          setState(() => _importance = value);
                                          unawaited(
                                            _save(
                                              controller,
                                              'do_first_importance',
                                              value,
                                            ),
                                          );
                                        },
                                      ),
                                      _stringDropdown(
                                        width: _fieldWidth(
                                          constraints.maxWidth,
                                          190,
                                        ),
                                        label: 'Category',
                                        value: _category,
                                        items: const {
                                          'all': 'All categories',
                                          'uncategorized':
                                              'Uncategorized only',
                                          'categorized': 'Categorized only',
                                        },
                                        onChanged: (value) {
                                          setState(() => _category = value);
                                          unawaited(
                                            _save(
                                              controller,
                                              'do_first_category',
                                              value,
                                            ),
                                          );
                                        },
                                      ),
                                      _stringDropdown(
                                        width: _fieldWidth(
                                          constraints.maxWidth,
                                          170,
                                        ),
                                        label: 'Energy',
                                        value: _energy,
                                        items: const {
                                          'all': 'Any energy',
                                          'high': 'High energy',
                                          'low': 'Low energy',
                                          'none': 'No energy tag',
                                        },
                                        onChanged: (value) {
                                          setState(() => _energy = value);
                                          unawaited(
                                            _save(
                                              controller,
                                              'do_first_energy',
                                              value,
                                            ),
                                          );
                                        },
                                      ),
                                      _stringDropdown(
                                        width: _fieldWidth(
                                          constraints.maxWidth,
                                          180,
                                        ),
                                        label: 'Recurrence',
                                        value: _recurrence,
                                        items: const {
                                          'all': 'Any recurrence',
                                          'recurring': 'Recurring only',
                                          'oneoff': 'One-time only',
                                        },
                                        onChanged: (value) {
                                          setState(() => _recurrence = value);
                                          unawaited(
                                            _save(
                                              controller,
                                              'do_first_recurrence',
                                              value,
                                            ),
                                          );
                                        },
                                      ),
                                      FilterChip(
                                        selected: _includeDescendants,
                                        label: const Text('Show descendants'),
                                        avatar: const Icon(
                                          Icons.account_tree_outlined,
                                          size: 18,
                                        ),
                                        onSelected: _level == null
                                            ? null
                                            : (value) {
                                                setState(
                                                  () => _includeDescendants =
                                                      value,
                                                );
                                                unawaited(
                                                  _save(
                                                    controller,
                                                    'do_first_descendants',
                                                    value.toString(),
                                                  ),
                                                );
                                              },
                                      ),
                                      ActionChip(
                                        avatar: const Icon(
                                          Icons.restart_alt,
                                          size: 17,
                                        ),
                                        label: const Text('Reset filters'),
                                        onPressed: () =>
                                            _resetFilters(controller),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: WorkItemTreeList(controller: controller, items: items),
          ),
        ],
      ),
    );
  }

  double _fieldWidth(double available, double preferred) {
    if (!available.isFinite) return preferred;
    if (available < 420) return available.clamp(150.0, preferred).toDouble();
    return preferred;
  }

  Widget _levelDropdown(AppController controller, double width) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<WorkItemType?>(
        initialValue: _level,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Level', isDense: true),
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
        onChanged: (value) {
          setState(() => _level = value);
          unawaited(
            _save(controller, 'do_first_level', value?.name ?? ''),
          );
        },
      ),
    );
  }

  Widget _stringDropdown({
    required double width,
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String> onChanged,
  }) {
    final safeValue = items.containsKey(value) ? value : items.keys.first;
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: safeValue,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: items.entries
            .map(
              (entry) => DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.value),
              ),
            )
            .toList(growable: false),
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }

  Future<void> _resetFilters(AppController controller) async {
    setState(() {
      _level = null;
      _period = 'all';
      _status = 'active';
      _importance = 'all';
      _category = 'all';
      _energy = 'all';
      _recurrence = 'all';
      _includeDescendants = false;
    });
    await Future.wait([
      _save(controller, 'do_first_level', ''),
      _save(controller, 'do_first_period', 'all'),
      _save(controller, 'do_first_status', 'active'),
      _save(controller, 'do_first_importance', 'all'),
      _save(controller, 'do_first_category', 'all'),
      _save(controller, 'do_first_energy', 'all'),
      _save(controller, 'do_first_recurrence', 'all'),
      _save(controller, 'do_first_descendants', 'false'),
    ]);
  }

  int _priorityBucket(WorkItem item, DateTime now) {
    final overdue = itemIsOverdue(item, now);
    final urgent = item.urgent || item.priority == PriorityLevel.urgent;
    final due = item.dueDate != null && !overdue;
    if (overdue && urgent) return 0;
    if (overdue) return 1;
    if (due && urgent) return 2;
    if (due) return 3;
    if (urgent) return 4;
    if (isUncategorizedTask(item)) return 5;
    return 6;
  }

  bool _matchesStatus(WorkItem item) => switch (_status) {
    'completed' => item.isCompleted,
    'all' => true,
    _ => !item.isCompleted,
  };

  bool _matchesImportance(WorkItem item) => switch (_importance) {
    'urgent' => item.urgent || item.priority == PriorityLevel.urgent,
    'important' => item.priority == PriorityLevel.important,
    'normal' => !item.urgent && item.priority == PriorityLevel.normal,
    _ => true,
  };

  bool _matchesCategory(WorkItem item) => switch (_category) {
    'uncategorized' => isUncategorizedTask(item),
    'categorized' => !isUncategorizedTask(item),
    _ => true,
  };

  bool _matchesEnergy(WorkItem item) => switch (_energy) {
    'high' => item.energyLevel == EnergyLevel.high,
    'low' => item.energyLevel == EnergyLevel.low,
    'none' => item.energyLevel == EnergyLevel.none,
    _ => true,
  };

  bool _matchesRecurrence(WorkItem item) => switch (_recurrence) {
    'recurring' => item.recurring,
    'oneoff' => !item.recurring,
    _ => true,
  };

  bool _matchesPeriod(WorkItem item, DateTime now) {
    if (item.recurring &&
        item.recurrenceDays == 1 &&
        !item.isCompleted &&
        const ['today', 'week', 'month', 'all'].contains(_period)) {
      return true;
    }
    return switch (_period) {
      'today' => item.dueDate != null && sameDay(item.dueDate!.toLocal(), now),
      'week' => itemIsOverdue(item, now) || itemDueThisWeek(item, now),
      'month' =>
        itemIsOverdue(item, now) ||
            (item.dueDate != null &&
                item.dueDate!.toLocal().year == now.year &&
                item.dueDate!.toLocal().month == now.month),
      'overdue' => itemIsOverdue(item, now),
      'undated' => item.dueDate == null,
      _ => true,
    };
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
