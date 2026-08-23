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
  WorkItemType? _level;
  String _search = '';
  bool _includeDescendants = false;
  bool _mobileFiltersVisible = false;
  bool _loaded = false;

  bool _showActive = true;
  bool _showUncategorized = false;
  bool _showCompleted = false;
  bool _showArchived = false;
  bool _urgent = false;
  bool _overdue = false;
  bool _dueToday = false;
  bool _thisWeek = false;
  bool _undated = false;

  final TextEditingController _quickTaskController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _quickTaskSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    unawaited(_loadPreferences(AppScope.of(context)));
  }

  bool _savedBool(String? value, bool fallback) {
    if (value == null) return fallback;
    return value == 'true';
  }

  Future<void> _loadPreferences(AppController controller) async {
    final values = await Future.wait([
      controller.readUiSetting('tasks_show_active'),
      controller.readUiSetting('tasks_show_uncategorized'),
      controller.readUiSetting('tasks_show_completed'),
      controller.readUiSetting('tasks_show_archived'),
      controller.readUiSetting('tasks_filter_urgent'),
      controller.readUiSetting('tasks_filter_overdue'),
      controller.readUiSetting('tasks_filter_due_today'),
      controller.readUiSetting('tasks_filter_this_week'),
      controller.readUiSetting('tasks_filter_undated'),
      controller.readUiSetting('tasks_level'),
      controller.readUiSetting('tasks_descendants'),
    ]);
    if (!mounted) return;
    setState(() {
      _showActive = _savedBool(values[0], true);
      _showUncategorized = _savedBool(values[1], false);
      _showCompleted = _savedBool(values[2], false);
      _showArchived = _savedBool(values[3], false);
      _urgent = _savedBool(values[4], false);
      _overdue = _savedBool(values[5], false);
      _dueToday = _savedBool(values[6], false);
      _thisWeek = _savedBool(values[7], false);
      _undated = _savedBool(values[8], false);
      _level = WorkItemType.values
          .where((value) => value.name == values[9])
          .firstOrNull;
      _includeDescendants = values[10] == 'true';
    });
  }

  @override
  void dispose() {
    _quickTaskController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _saveBool(
    AppController controller,
    String key,
    bool value,
  ) => controller.writeLocalUiSetting(key, value.toString());

  Future<void> _addQuickTask(AppController controller) async {
    final title = _quickTaskController.text.trim();
    if (title.isEmpty || _quickTaskSaving) return;
    setState(() => _quickTaskSaving = true);
    try {
      await controller.createQuickTask(title);
      _quickTaskController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quick task added to Uncategorized.'),
          duration: Duration(milliseconds: 1200),
        ),
      );
    } finally {
      if (mounted) setState(() => _quickTaskSaving = false);
    }
  }

  Widget _quickCaptureRow(AppController controller, {required bool mobile}) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _quickTaskController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.flash_on_outlined, size: 20),
              hintText: 'Quick task…',
              helperText: mobile ? null : 'Enter adds it to Uncategorized',
              isDense: true,
            ),
            onSubmitted: (_) => _addQuickTask(controller),
          ),
        ),
        const SizedBox(width: 6),
        IconButton.filled(
          tooltip: 'Add quick task',
          onPressed: _quickTaskSaving ? null : () => _addQuickTask(controller),
          icon: _quickTaskSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_task),
        ),
      ],
    );
  }

  bool _isUncategorized(WorkItem item) =>
      item.parentId == null &&
      (item.folder.trim().isEmpty || item.folder == 'Uncategorized') &&
      item.type == WorkItemType.task;

  bool _smartFilterMatches(WorkItem item, DateTime now) {
    final anySmart = _urgent || _overdue || _dueToday || _thisWeek || _undated;
    if (!anySmart) return true;
    final due = item.dueDate?.toLocal();
    return (_urgent && (item.urgent || item.priority == PriorityLevel.urgent)) ||
        (_overdue && itemIsOverdue(item, now)) ||
        (_dueToday && due != null && sameDay(due, now)) ||
        (_thisWeek && itemDueThisWeek(item, now)) ||
        (_undated && due == null);
  }

  bool _statusVisible(WorkItem item) => switch (item.status) {
        WorkStatus.active => _showActive,
        WorkStatus.completed => _showCompleted,
        WorkStatus.archived => _showArchived,
      };

  List<WorkItem> _filteredItems(AppController controller, DateTime now) {
    final eligible = controller.workItems.where((item) {
      if (item.isDeleted || !_statusVisible(item)) return false;
      if (_showUncategorized && !_isUncategorized(item)) return false;
      if (!_smartFilterMatches(item, now)) return false;
      if (_search.isNotEmpty) {
        final query = _search.toLowerCase();
        if (!item.title.toLowerCase().contains(query) &&
            !item.notes.toLowerCase().contains(query)) {
          return false;
        }
      }
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
          for (final child in controller.descendantsOf(root.id)) {
            if (eligibleIds.contains(child.id) && added.add(child.id)) {
              items.add(child);
            }
          }
        }
      }
    }

    items.sort((a, b) {
      if (a.status != b.status) {
        const order = {
          WorkStatus.active: 0,
          WorkStatus.completed: 1,
          WorkStatus.archived: 2,
        };
        return (order[a.status] ?? 9).compareTo(order[b.status] ?? 9);
      }
      if (a.dueDate == null && b.dueDate != null) return 1;
      if (a.dueDate != null && b.dueDate == null) return -1;
      return dueSortScore(a, now).compareTo(dueSortScore(b, now));
    });
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final now = DateTime.now();
    final mobile = MediaQuery.sizeOf(context).width < 700;
    final items = _filteredItems(controller, now);

    return Padding(
      padding: EdgeInsets.all(mobile ? 8 : 14),
      child: Column(
        children: [
          mobile
              ? _buildMobileToolbar(context, controller)
              : _buildDesktopToolbar(context, controller),
          const SizedBox(height: 8),
          Expanded(
            child: WorkItemTreeList(controller: controller, items: items),
          ),
        ],
      ),
    );
  }

  Widget _searchAndAddRow(
    BuildContext context,
    AppController controller, {
    required bool mobile,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: 'Search tasks',
              isDense: true,
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
        ),
        if (mobile) ...[
          const SizedBox(width: 6),
          IconButton.filledTonal(
            tooltip: 'Advanced task filters',
            onPressed: () => setState(
              () => _mobileFiltersVisible = !_mobileFiltersVisible,
            ),
            icon: const Icon(Icons.filter_alt_outlined),
          ),
        ],
        const SizedBox(width: 6),
        mobile
            ? IconButton.filled(
                tooltip: 'Add detailed task',
                onPressed: () => showWorkItemEditor(
                  context,
                  controller,
                  initialType: WorkItemType.task,
                ),
                icon: const Icon(Icons.add),
              )
            : FilledButton.icon(
                onPressed: () => showWorkItemEditor(
                  context,
                  controller,
                  initialType: WorkItemType.task,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Task'),
              ),
      ],
    );
  }

  Widget _filterStrip(AppController controller) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          FilterChip(
            selected: _showActive,
            label: const Text('Active'),
            avatar: const Icon(Icons.radio_button_checked, size: 16),
            onSelected: (value) {
              setState(() => _showActive = value);
              unawaited(_saveBool(controller, 'tasks_show_active', value));
            },
          ),
          const SizedBox(width: 6),
          FilterChip(
            selected: _showUncategorized,
            label: const Text('Uncategorized'),
            avatar: const Icon(Icons.inbox_outlined, size: 16),
            onSelected: (value) {
              setState(() => _showUncategorized = value);
              unawaited(
                _saveBool(controller, 'tasks_show_uncategorized', value),
              );
            },
          ),
          const SizedBox(width: 6),
          FilterChip(
            selected: _showCompleted,
            label: const Text('Completed'),
            avatar: const Icon(Icons.task_alt, size: 16),
            onSelected: (value) {
              setState(() => _showCompleted = value);
              unawaited(_saveBool(controller, 'tasks_show_completed', value));
            },
          ),
          const SizedBox(width: 6),
          FilterChip(
            selected: _showArchived,
            label: const Text('Archived'),
            avatar: const Icon(Icons.archive_outlined, size: 16),
            onSelected: (value) {
              setState(() => _showArchived = value);
              unawaited(_saveBool(controller, 'tasks_show_archived', value));
            },
          ),
          const SizedBox(width: 10),
          _smartChip(controller, 'Urgent', Icons.priority_high, _urgent,
              'tasks_filter_urgent', (value) => _urgent = value),
          const SizedBox(width: 6),
          _smartChip(controller, 'Overdue', Icons.warning_amber, _overdue,
              'tasks_filter_overdue', (value) => _overdue = value),
          const SizedBox(width: 6),
          _smartChip(controller, 'Due Today', Icons.today, _dueToday,
              'tasks_filter_due_today', (value) => _dueToday = value),
          const SizedBox(width: 6),
          _smartChip(controller, 'This Week', Icons.date_range, _thisWeek,
              'tasks_filter_this_week', (value) => _thisWeek = value),
          const SizedBox(width: 6),
          _smartChip(controller, 'Undated', Icons.event_busy, _undated,
              'tasks_filter_undated', (value) => _undated = value),
          const SizedBox(width: 10),
          ActionChip(
            avatar: const Icon(Icons.refresh, size: 16),
            label: const Text('All active'),
            onPressed: () => _resetAllActive(controller),
          ),
          const SizedBox(width: 6),
          ActionChip(
            avatar: const Icon(Icons.filter_alt_off, size: 16),
            label: const Text('Clear filters'),
            onPressed: () => _clearFilters(controller),
          ),
        ],
      ),
    );
  }

  Widget _smartChip(
    AppController controller,
    String label,
    IconData icon,
    bool selected,
    String settingKey,
    void Function(bool value) assign,
  ) {
    return FilterChip(
      selected: selected,
      label: Text(label),
      avatar: Icon(icon, size: 16),
      onSelected: (value) {
        setState(() => assign(value));
        unawaited(_saveBool(controller, settingKey, value));
      },
    );
  }

  Future<void> _resetAllActive(AppController controller) async {
    setState(() {
      _showActive = true;
      _showUncategorized = false;
      _showCompleted = false;
      _showArchived = false;
      _urgent = false;
      _overdue = false;
      _dueToday = false;
      _thisWeek = false;
      _undated = false;
    });
    await Future.wait([
      _saveBool(controller, 'tasks_show_active', true),
      _saveBool(controller, 'tasks_show_uncategorized', false),
      _saveBool(controller, 'tasks_show_completed', false),
      _saveBool(controller, 'tasks_show_archived', false),
      _saveBool(controller, 'tasks_filter_urgent', false),
      _saveBool(controller, 'tasks_filter_overdue', false),
      _saveBool(controller, 'tasks_filter_due_today', false),
      _saveBool(controller, 'tasks_filter_this_week', false),
      _saveBool(controller, 'tasks_filter_undated', false),
    ]);
  }

  Future<void> _clearFilters(AppController controller) async {
    setState(() {
      _showUncategorized = false;
      _urgent = false;
      _overdue = false;
      _dueToday = false;
      _thisWeek = false;
      _undated = false;
      _level = null;
      _includeDescendants = false;
      _search = '';
      _searchController.clear();
    });
    await Future.wait([
      _saveBool(controller, 'tasks_show_uncategorized', false),
      _saveBool(controller, 'tasks_filter_urgent', false),
      _saveBool(controller, 'tasks_filter_overdue', false),
      _saveBool(controller, 'tasks_filter_due_today', false),
      _saveBool(controller, 'tasks_filter_this_week', false),
      _saveBool(controller, 'tasks_filter_undated', false),
      controller.writeLocalUiSetting('tasks_level', ''),
      controller.writeLocalUiSetting('tasks_descendants', 'false'),
    ]);
  }

  Widget _buildMobileToolbar(
    BuildContext context,
    AppController controller,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            _quickCaptureRow(controller, mobile: true),
            const SizedBox(height: 8),
            _searchAndAddRow(context, controller, mobile: true),
            _filterStrip(controller),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              child: !_mobileFiltersVisible
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        children: [
                          _levelDropdown(controller, fullWidth: true),
                          if (_level != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FilterChip(
                                selected: _includeDescendants,
                                label: const Text('Show descendants'),
                                avatar: const Icon(
                                  Icons.account_tree_outlined,
                                  size: 18,
                                ),
                                onSelected: (value) =>
                                    _setDescendants(controller, value),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopToolbar(
    BuildContext context,
    AppController controller,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _quickCaptureRow(controller, mobile: false),
            const SizedBox(height: 10),
            _searchAndAddRow(context, controller, mobile: false),
            _filterStrip(controller),
            const SizedBox(height: 8),
            Row(
              children: [
                _levelDropdown(controller),
                const SizedBox(width: 8),
                FilterChip(
                  selected: _includeDescendants,
                  label: const Text('Show descendants'),
                  avatar: const Icon(Icons.account_tree_outlined, size: 18),
                  onSelected: _level == null
                      ? null
                      : (value) => _setDescendants(controller, value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _levelDropdown(AppController controller, {bool fullWidth = false}) {
    return SizedBox(
      width: fullWidth ? double.infinity : 190,
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
            controller.writeLocalUiSetting('tasks_level', value?.name ?? ''),
          );
        },
      ),
    );
  }

  void _setDescendants(AppController controller, bool value) {
    setState(() => _includeDescendants = value);
    unawaited(
      controller.writeLocalUiSetting('tasks_descendants', value.toString()),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
