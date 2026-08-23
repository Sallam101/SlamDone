import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../controllers/app_scope.dart';
import '../models/models.dart';
import '../repositories/app_repository.dart';
import '../widgets/canvas_workspace.dart';
import '../widgets/focus_dialogs.dart';
import '../widgets/hierarchy_layout.dart';
import '../widgets/structured_hierarchy_view.dart';
import '../widgets/work_item_dialogs.dart';

class BigPictureScreen extends StatefulWidget {
  const BigPictureScreen({super.key});

  @override
  State<BigPictureScreen> createState() => _BigPictureScreenState();
}

class _BigPictureScreenState extends State<BigPictureScreen> {
  bool _controlsExpanded = false;
  bool _advancedFiltersVisible = false;
  bool _controlPreferenceLoaded = false;
  bool _freeCanvas = false;
  WorkItemType? _levelFilter;
  PriorityLevel? _priorityFilter;
  String _search = '';
  bool _showDescendants = false;
  Set<WorkStatus> _visibleStatuses = <WorkStatus>{
    WorkStatus.active,
    WorkStatus.completed,
  };


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controlPreferenceLoaded) return;
    _controlPreferenceLoaded = true;
    final controller = AppScope.of(context);
    controller.readUiSetting('big_picture_controls_expanded').then((saved) {
      if (!mounted || saved == null) return;
      setState(() => _controlsExpanded = saved == 'true');
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final allItems = controller.workItems
        .where(
          (item) => !item.isDeleted && _visibleStatuses.contains(item.status),
        )
        .toList();
    final query = _search.trim().toLowerCase();
    final filtered = allItems.where((item) {
      if (_levelFilter != null && item.type != _levelFilter) return false;
      if (_priorityFilter != null && item.priority != _priorityFilter) {
        return false;
      }
      if (query.isNotEmpty &&
          !item.title.toLowerCase().contains(query) &&
          !item.notes.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();

    final filteringActive =
        _levelFilter != null || _priorityFilter != null || query.isNotEmpty;
    final includedIds = filteringActive
        ? <String>{...filtered.map((item) => item.id)}
        : <String>{...allItems.map((item) => item.id)};
    if (filteringActive && _showDescendants) {
      var changed = true;
      while (changed) {
        changed = false;
        for (final item in allItems) {
          if (item.parentId != null &&
              includedIds.contains(item.parentId) &&
              includedIds.add(item.id)) {
            changed = true;
          }
        }
      }
    }
    final visible = allItems
        .where((item) => includedIds.contains(item.id))
        .toList();
    var layouts = <String, CanvasLayout>{
      for (var index = 0; index < allItems.length; index++)
        allItems[index].id: controller.layoutFor(
          allItems[index],
          CanvasViewKind.bigPicture,
          x: 120 + (index % 4) * 360,
          y: 100 + (index ~/ 4) * 220,
        ),
    };
    if (allItems.any(
      (item) => !controller.bigPictureLayouts.containsKey(item.id),
    )) {
      layouts = buildAutomaticHierarchyLayout(
        items: allItems,
        existing: layouts,
        viewKind: CanvasViewKind.bigPicture,
        deviceClass: controller.deviceClass,
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Tooltip(
                        message: _controlsExpanded
                            ? 'Tuck Big Picture controls'
                            : 'Show Big Picture controls',
                        child: TextButton.icon(
                          onPressed: () => _setControlsExpanded(
                            controller,
                            !_controlsExpanded,
                          ),
                          icon: Icon(
                            _controlsExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                          label: Text(
                            'Big Picture',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),
                      _statusChip(
                        label: const Text('Active'),
                        icon: Icons.play_circle_outline,
                        status: WorkStatus.active,
                        count: controller.workItems
                            .where((item) => !item.isDeleted && item.status == WorkStatus.active)
                            .length,
                      ),
                      _statusChip(
                        label: const Text('Completed'),
                        icon: Icons.check_circle_outline,
                        status: WorkStatus.completed,
                        count: controller.workItems
                            .where((item) => !item.isDeleted && item.status == WorkStatus.completed)
                            .length,
                      ),
                      _statusChip(
                        label: const Text('Archived'),
                        icon: Icons.archive_outlined,
                        status: WorkStatus.archived,
                        count: controller.workItems
                            .where((item) => !item.isDeleted && item.status == WorkStatus.archived)
                            .length,
                      ),
                      FilledButton.icon(
                        onPressed: () =>
                            showWorkItemEditor(context, controller),
                        icon: const Icon(Icons.add),
                        label: const Text('Goal'),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: !_controlsExpanded
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SegmentedButton<bool>(
                                  segments: const [
                                    ButtonSegment(
                                      value: false,
                                      label: Text('Structured'),
                                      icon: Icon(Icons.account_tree),
                                    ),
                                    ButtonSegment(
                                      value: true,
                                      label: Text('Free Canvas'),
                                      icon: Icon(Icons.open_with),
                                    ),
                                  ],
                                  selected: {_freeCanvas},
                                  onSelectionChanged: (value) =>
                                      setState(() => _freeCanvas = value.first),
                                ),
                                ActionChip(
                                  avatar: const Icon(Icons.select_all, size: 17),
                                  label: const Text('All'),
                                  onPressed: _showAllStatuses,
                                ),
                                FilterChip(
                                  avatar: const Icon(Icons.tune, size: 17),
                                  label: const Text('More filters'),
                                  selected: _advancedFiltersVisible,
                                  onSelected: (value) => setState(
                                    () => _advancedFiltersVisible = value,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: !_controlsExpanded || !_advancedFiltersVisible
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(
                                  width: 250,
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.search),
                                      labelText: 'Search title or note',
                                    ),
                                    onChanged: (value) =>
                                        setState(() => _search = value),
                                  ),
                                ),
                                SizedBox(
                                  width: 190,
                                  child: DropdownButtonFormField<WorkItemType?>(
                                    initialValue: _levelFilter,
                                    decoration: const InputDecoration(
                                      labelText: 'Level',
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
                                    onChanged: (value) =>
                                        setState(() => _levelFilter = value),
                                  ),
                                ),
                                FilterChip(
                                  label: const Text('Show descendants'),
                                  selected: _showDescendants,
                                  onSelected: filteringActive
                                      ? (value) => setState(
                                          () => _showDescendants = value,
                                        )
                                      : null,
                                ),
                                SizedBox(
                                  width: 190,
                                  child: DropdownButtonFormField<PriorityLevel?>(
                                    initialValue: _priorityFilter,
                                    decoration: const InputDecoration(
                                      labelText: 'Priority',
                                    ),
                                    items: [
                                      const DropdownMenuItem<PriorityLevel?>(
                                        value: null,
                                        child: Text('All priorities'),
                                      ),
                                      ...PriorityLevel.values.map(
                                        (value) => DropdownMenuItem<PriorityLevel?>(
                                          value: value,
                                          child: Text(value.name),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) =>
                                        setState(() => _priorityFilter = value),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => setState(() {
                                    _levelFilter = null;
                                    _priorityFilter = null;
                                    _search = '';
                                    _showDescendants = false;
                                  }),
                                  icon: const Icon(Icons.filter_alt_off),
                                  label: const Text('Clear'),
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
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: _freeCanvas
                  ? CanvasWorkspace(
                      items: visibleHierarchyItems(
                        items: visible,
                        layouts: layouts,
                      ),
                      layouts: layouts,
                      viewKind: CanvasViewKind.bigPicture,
                      freeMove: true,
                      showConnections: true,
                      onLayoutChanged: controller.saveLayout,
                      onDropRequested: (sourceId, targetId) => _directParent(
                        context,
                        controller,
                        sourceId,
                        targetId,
                      ),
                      onMakeRoot: (sourceId) => controller.applyDrop(
                        sourceId: sourceId,
                        intent: DropIntent.makeRoot,
                      ),
                      onEdit: (item) =>
                          showWorkItemEditor(context, controller, item: item),
                      onDelete: (item) =>
                          showDeleteWorkItemDialog(context, controller, item),
                      onAddChild: (parent) => showWorkItemEditor(
                        context,
                        controller,
                        parent: parent,
                      ),
                      onChecklistChanged: controller.updateChecklist,
                      onFocus: (item) =>
                          showQuickFocusDialog(context, controller, item: item),
                      onItemChanged: controller.updateWorkItem,
                    )
                  : StructuredHierarchyView(
                      controller: controller,
                      items: visible,
                      layouts: layouts,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setControlsExpanded(
    AppController controller,
    bool value,
  ) async {
    setState(() {
      _controlsExpanded = value;
      if (!value) _advancedFiltersVisible = false;
    });
    await controller.writeUiSetting(
      'big_picture_controls_expanded',
      value.toString(),
    );
  }

  void _showAllStatuses() {
    setState(() {
      _visibleStatuses = WorkStatus.values.toSet();
    });
  }

  Widget _statusChip({
    required Widget label,
    required IconData icon,
    required WorkStatus status,
    required int count,
  }) {
    return FilterChip(
      avatar: Icon(icon, size: 17),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          label,
          const SizedBox(width: 5),
          Text('$count', style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
      selected: _visibleStatuses.contains(status),
      onSelected: (_) => _toggleStatus(status),
    );
  }

  void _toggleStatus(WorkStatus status) {
    setState(() {
      final next = <WorkStatus>{..._visibleStatuses};
      if (!next.add(status)) next.remove(status);
      _visibleStatuses = next;
    });
  }

  Future<void> _directParent(
    BuildContext context,
    AppController controller,
    String sourceId,
    String targetId,
  ) async {
    final source = controller.itemById(sourceId);
    final target = controller.itemById(targetId);
    if (source == null || target == null) return;
    if (target.type.index >= source.type.index) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A parent must be a higher hierarchy level.'),
        ),
      );
      return;
    }
    await controller.applyDrop(
      sourceId: sourceId,
      targetId: targetId,
      intent: DropIntent.makeChild,
    );
  }

  Future<void> _autoArrange(
    AppController controller,
    List<WorkItem> items,
    Map<String, CanvasLayout> current,
  ) async {
    final arranged = buildAutomaticHierarchyLayout(
      items: items,
      existing: current,
      viewKind: CanvasViewKind.bigPicture,
      deviceClass: controller.deviceClass,
    );
    for (final layout in arranged.values) {
      await controller.saveLayout(layout);
    }
  }
}
