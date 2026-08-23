import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../controllers/app_scope.dart';
import '../models/models.dart';
import '../repositories/app_repository.dart';
import '../widgets/canvas_workspace.dart';
import '../widgets/focus_dialogs.dart';
import '../widgets/hierarchy_layout.dart';
import '../widgets/work_item_dialogs.dart';

class MindMapScreen extends StatefulWidget {
  const MindMapScreen({super.key});

  @override
  State<MindMapScreen> createState() => _MindMapScreenState();
}

class _MindMapScreenState extends State<MindMapScreen> {
  bool _toolbarVisible = true;
  WorkItemType? _levelFilter;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final allItems = controller.workItems
        .where((item) => !item.isDeleted)
        .toList();
    var layouts = <String, CanvasLayout>{
      for (var index = 0; index < allItems.length; index++)
        allItems[index].id: controller.layoutFor(
          allItems[index],
          CanvasViewKind.mindMap,
          x: 280 + (index % 5) * 300,
          y: 140 + (index ~/ 5) * 170,
        ),
    };
    final missingAny = allItems.any(
      (item) => !controller.mindMapLayouts.containsKey(item.id),
    );
    if (missingAny) {
      layouts = buildAutomaticHierarchyLayout(
        items: allItems,
        existing: layouts,
        viewKind: CanvasViewKind.mindMap,
        deviceClass: controller.deviceClass,
      );
    }
    var visible = visibleHierarchyItems(items: allItems, layouts: layouts);
    if (_levelFilter != null) {
      visible = visible
          .where((item) => item.parentId == null || item.type == _levelFilter)
          .toList();
    }
    final visibleIds = visible.map((item) => item.id).toSet();
    layouts = Map.fromEntries(
      layouts.entries.where((entry) => visibleIds.contains(entry.key)),
    );

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.hub_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mind Map',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Text(
                              'Move and resize every node anywhere. Nerve lines follow the hierarchy.',
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Hide or show toolbar',
                        onPressed: () =>
                            setState(() => _toolbarVisible = !_toolbarVisible),
                        icon: Icon(
                          _toolbarVisible
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                        ),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    child: _toolbarVisible
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(
                                  width: (MediaQuery.sizeOf(context).width - 70)
                                      .clamp(220, 520)
                                      .toDouble(),
                                  child: DropdownButtonFormField<WorkItemType?>(
                                    initialValue: _levelFilter,
                                    decoration: const InputDecoration(
                                      labelText: 'Level filter',
                                    ),
                                    items: [
                                      const DropdownMenuItem<WorkItemType?>(
                                        value: null,
                                        child: Text('All levels'),
                                      ),
                                      ...WorkItemType.values.map(
                                        (value) =>
                                            DropdownMenuItem<WorkItemType?>(
                                              value: value,
                                              child: Text(value.name),
                                            ),
                                      ),
                                    ],
                                    onChanged: (value) =>
                                        setState(() => _levelFilter = value),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _autoArrange(controller, allItems),
                                  icon: const Icon(Icons.auto_fix_high),
                                  label: const Text('Auto arrange'),
                                ),
                                FilledButton.icon(
                                  onPressed: () =>
                                      showWorkItemEditor(context, controller),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Goal'),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: CanvasWorkspace(
              items: visible,
              layouts: layouts,
              viewKind: CanvasViewKind.mindMap,
              freeMove: true,
              showConnections: true,
              onLayoutChanged: controller.saveLayout,
              onDropRequested: (sourceId, targetId) => showDropIntentDialog(
                context,
                controller,
                sourceId: sourceId,
                targetId: targetId,
              ),
              onMakeRoot: (sourceId) => controller.applyDrop(
                sourceId: sourceId,
                intent: DropIntent.makeRoot,
              ),
              onEdit: (item) =>
                  showWorkItemEditor(context, controller, item: item),
              onDelete: (item) =>
                  showDeleteWorkItemDialog(context, controller, item),
              onAddChild: (parent) =>
                  showWorkItemEditor(context, controller, parent: parent),
              onChecklistChanged: controller.updateChecklist,
              onFocus: (item) =>
                  showQuickFocusDialog(context, controller, item: item),
              onItemChanged: controller.updateWorkItem,
              textColorOverrides: controller.mindMapTextColors,
              onTextColorChanged: controller.setMindMapTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _autoArrange(
    AppController controller,
    List<WorkItem> items,
  ) async {
    var layouts = <String, CanvasLayout>{
      for (final item in items)
        item.id: controller.layoutFor(item, CanvasViewKind.mindMap),
    };
    layouts = buildAutomaticHierarchyLayout(
      items: items,
      existing: layouts,
      viewKind: CanvasViewKind.mindMap,
      deviceClass: controller.deviceClass,
    );
    for (final layout in layouts.values) {
      await controller.saveLayout(layout);
    }
  }
}
