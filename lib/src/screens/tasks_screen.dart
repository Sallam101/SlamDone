import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../controllers/app_scope.dart';
import '../models/models.dart';
import '../utils/app_utils.dart';
import '../widgets/work_item_dialogs.dart';
import '../widgets/work_item_tree_list.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _filter = 'default';
  WorkItemType? _level;
  String _search = '';
  bool _includeDescendants = false;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    unawaited(_loadPreferences(AppScope.of(context)));
  }

  Future<void> _loadPreferences(AppController controller) async {
    final filter = await controller.readUiSetting('tasks_filter');
    final levelName = await controller.readUiSetting('tasks_level');
    final descendants =
        await controller.readUiSetting('tasks_descendants') == 'true';
    if (!mounted) return;
    setState(() {
      _filter = filter ?? 'default';
      _level = WorkItemType.values
          .where((value) => value.name == levelName)
          .firstOrNull;
      _includeDescendants = descendants;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final now = DateTime.now();
    final eligible = controller.workItems.where((item) {
      if (item.isDeleted || item.status == WorkStatus.archived) return false;
      if (_search.isNotEmpty &&
          !item.title.toLowerCase().contains(_search.toLowerCase()) &&
          !item.notes.toLowerCase().contains(_search.toLowerCase())) {
        return false;
      }
      return switch (_filter) {
        'overdue' => itemIsOverdue(item, now),
        'today' =>
          item.dueDate != null &&
              sameDay(item.dueDate!.toLocal(), now) &&
              !item.isCompleted,
        'week' => itemDueThisWeek(item, now) && !item.isCompleted,
        'month' =>
          item.dueDate != null &&
              item.dueDate!.toLocal().year == now.year &&
              item.dueDate!.toLocal().month == now.month &&
              !item.isCompleted,
        'completed' => item.isCompleted,
        'undated' => item.dueDate == null && !item.isCompleted,
        'all' => true,
        _ => true,
      };
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
          for (final child in controller.descendantsOf(root.id)) {
            if (eligibleIds.contains(child.id) && added.add(child.id)) {
              items.add(child);
            }
          }
        }
      }
    }

    items.sort((a, b) {
      if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
      if (a.dueDate == null && b.dueDate != null) return 1;
      if (a.dueDate != null && b.dueDate == null) return -1;
      return dueSortScore(a, now).compareTo(dueSortScore(b, now));
    });

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 250,
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          labelText: 'Search',
                          isDense: true,
                        ),
                        onChanged: (value) => setState(() => _search = value),
                      ),
                    ),
                    const SizedBox(width: 10),
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
                            controller.writeUiSetting(
                              'tasks_level',
                              value?.name ?? '',
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _includeDescendants,
                      label: const Text('Show descendants'),
                      avatar: const Icon(Icons.account_tree_outlined, size: 18),
                      onSelected: _level == null
                          ? null
                          : (value) {
                              setState(() => _includeDescendants = value);
                              unawaited(
                                controller.writeUiSetting(
                                  'tasks_descendants',
                                  value.toString(),
                                ),
                              );
                            },
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 230,
                      child: DropdownButtonFormField<String>(
                        initialValue: _filter,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Due / status sort',
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'default',
                            child: Text('Due, overdue, then undated'),
                          ),
                          DropdownMenuItem(
                            value: 'overdue',
                            child: Text('Overdue'),
                          ),
                          DropdownMenuItem(
                            value: 'today',
                            child: Text('Due today'),
                          ),
                          DropdownMenuItem(
                            value: 'week',
                            child: Text('Due this week'),
                          ),
                          DropdownMenuItem(
                            value: 'month',
                            child: Text('Due this month'),
                          ),
                          DropdownMenuItem(
                            value: 'completed',
                            child: Text('Completed'),
                          ),
                          DropdownMenuItem(
                            value: 'undated',
                            child: Text('Not dated'),
                          ),
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('Show all'),
                          ),
                        ],
                        onChanged: (value) {
                          final next = value ?? 'default';
                          setState(() => _filter = next);
                          unawaited(
                            controller.writeUiSetting('tasks_filter', next),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () => showWorkItemEditor(
                        context,
                        controller,
                        initialType: WorkItemType.task,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Task'),
                    ),
                  ],
                ),
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
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
