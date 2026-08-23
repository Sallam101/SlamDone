import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../controllers/app_scope.dart';
import '../models/models.dart';
import '../utils/app_utils.dart';
import '../widgets/work_item_tree_list.dart';

class DoFirstScreen extends StatefulWidget {
  const DoFirstScreen({super.key});

  @override
  State<DoFirstScreen> createState() => _DoFirstScreenState();
}

class _DoFirstScreenState extends State<DoFirstScreen> {
  WorkItemType? _level;
  String _period = 'week';
  String _status = 'active';
  String _importance = 'all';
  bool _includeDescendants = false;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    unawaited(_loadFilters(AppScope.of(context)));
  }

  Future<void> _loadFilters(AppController controller) async {
    final period = await controller.readUiSetting('do_first_period');
    final status = await controller.readUiSetting('do_first_status');
    final importance = await controller.readUiSetting('do_first_importance');
    final levelName = await controller.readUiSetting('do_first_level');
    final descendants =
        await controller.readUiSetting('do_first_descendants') == 'true';
    if (!mounted) return;
    setState(() {
      _period = period ?? 'week';
      _status = status ?? 'active';
      _importance = importance ?? 'all';
      _level = WorkItemType.values
          .where((value) => value.name == levelName)
          .firstOrNull;
      _includeDescendants = descendants;
    });
  }

  Future<void> _save(AppController controller, String key, String value) async {
    await controller.writeUiSetting(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final now = DateTime.now();
    final eligible = controller.workItems.where((item) {
      if (item.isDeleted || item.status == WorkStatus.archived) return false;
      if (!_matchesStatus(item)) return false;
      if (!_matchesPeriod(item, now)) return false;
      if (!_matchesImportance(item)) return false;
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
    items.sort((a, b) => dueSortScore(a, now).compareTo(dueSortScore(b, now)));

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt, color: Colors.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Do First',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Text(
                              'Choose exactly which due, overdue, completed, important, or hierarchy items should appear.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 190,
                        child: DropdownButtonFormField<WorkItemType?>(
                          initialValue: _level,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Level',
                            isDense: true,
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
                          onChanged: (value) {
                            setState(() => _level = value);
                            unawaited(
                              _save(
                                controller,
                                'do_first_level',
                                value?.name ?? '',
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(
                        width: 205,
                        child: DropdownButtonFormField<String>(
                          initialValue: _period,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Period / scope',
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'today',
                              child: Text('Today'),
                            ),
                            DropdownMenuItem(
                              value: 'week',
                              child: Text('This week + overdue'),
                            ),
                            DropdownMenuItem(
                              value: 'month',
                              child: Text('This month + overdue'),
                            ),
                            DropdownMenuItem(
                              value: 'overdue',
                              child: Text('Overdue only'),
                            ),
                            DropdownMenuItem(
                              value: 'undated',
                              child: Text('No due date'),
                            ),
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('Any period'),
                            ),
                          ],
                          onChanged: (value) {
                            final next = value ?? 'week';
                            setState(() => _period = next);
                            unawaited(
                              _save(controller, 'do_first_period', next),
                            );
                          },
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          initialValue: _status,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'active',
                              child: Text('Active only'),
                            ),
                            DropdownMenuItem(
                              value: 'completed',
                              child: Text('Completed only'),
                            ),
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('Active + completed'),
                            ),
                          ],
                          onChanged: (value) {
                            final next = value ?? 'active';
                            setState(() => _status = next);
                            unawaited(
                              _save(controller, 'do_first_status', next),
                            );
                          },
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          initialValue: _importance,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Importance',
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('All importance'),
                            ),
                            DropdownMenuItem(
                              value: 'urgent',
                              child: Text('Urgent'),
                            ),
                            DropdownMenuItem(
                              value: 'important',
                              child: Text('Important'),
                            ),
                            DropdownMenuItem(
                              value: 'normal',
                              child: Text('Normal'),
                            ),
                          ],
                          onChanged: (value) {
                            final next = value ?? 'all';
                            setState(() => _importance = next);
                            unawaited(
                              _save(controller, 'do_first_importance', next),
                            );
                          },
                        ),
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
                                setState(() => _includeDescendants = value);
                                unawaited(
                                  _save(
                                    controller,
                                    'do_first_descendants',
                                    value.toString(),
                                  ),
                                );
                              },
                      ),
                    ],
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
