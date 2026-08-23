import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/models.dart';
import '../utils/app_utils.dart';
import 'focus_dialogs.dart';
import 'work_item_dialogs.dart';

class WorkItemTreeList extends StatefulWidget {
  const WorkItemTreeList({
    super.key,
    required this.controller,
    required this.items,
    this.showRootsOnly = true,
    this.allowEditing = true,
  });

  final AppController controller;
  final List<WorkItem> items;
  final bool showRootsOnly;
  final bool allowEditing;

  @override
  State<WorkItemTreeList> createState() => _WorkItemTreeListState();
}

class _WorkItemTreeListState extends State<WorkItemTreeList> {
  final Set<String> _collapsed = <String>{};

  @override
  Widget build(BuildContext context) {
    final ids = widget.items.map((item) => item.id).toSet();
    final byParent = <String?, List<WorkItem>>{};
    for (final item in widget.items) {
      final parent = ids.contains(item.parentId) ? item.parentId : null;
      byParent.putIfAbsent(parent, () => <WorkItem>[]).add(item);
    }
    for (final list in byParent.values) {
      list.sort((a, b) {
        final urgency = _sortScore(a).compareTo(_sortScore(b));
        return urgency != 0 ? urgency : a.sortKey.compareTo(b.sortKey);
      });
    }
    final roots = widget.showRootsOnly
        ? (byParent[null] ?? const <WorkItem>[])
        : widget.items;
    if (roots.isEmpty) {
      return const Center(child: Text('No matching items.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: roots.length,
      itemBuilder: (context, index) =>
          _node(context, roots[index], byParent, 0),
    );
  }

  int _sortScore(WorkItem item) {
    final now = DateTime.now();
    if (itemIsOverdue(item, now)) return -1000000;
    if (item.urgent || item.priority == PriorityLevel.urgent) return -100000;
    if (item.priority == PriorityLevel.important) return -50000;
    return item.dueDate?.millisecondsSinceEpoch ?? 9999999999999;
  }

  Widget _node(
    BuildContext context,
    WorkItem item,
    Map<String?, List<WorkItem>> byParent,
    int depth,
  ) {
    final children = byParent[item.id] ?? const <WorkItem>[];
    final collapsed = _collapsed.contains(item.id);
    final completed = item.isCompleted;
    final due = item.dueDate?.toLocal();
    final overdue = itemIsOverdue(item, DateTime.now());
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Padding(
      padding: EdgeInsets.only(
        left: depth * (compact ? 8.0 : 22.0),
        bottom: 6,
      ),
      child: Column(
        children: [
          Card(
            color: completed ? Colors.grey.withValues(alpha: 0.15) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (children.isNotEmpty)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(
                        () => collapsed
                            ? _collapsed.remove(item.id)
                            : _collapsed.add(item.id),
                      ),
                      icon: Icon(
                        collapsed ? Icons.chevron_right : Icons.expand_more,
                      ),
                    )
                  else
                    SizedBox(width: compact ? 4 : 40),
                  Checkbox(
                    value: completed,
                    onChanged: (value) => widget.controller
                        .setWorkItemCompleted(item, value ?? false),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                item.type.name.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (item.urgent ||
                                item.priority != PriorityLevel.normal) ...[
                              Text(
                                item.urgent
                                    ? 'URGENT'
                                    : item.priority.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: item.urgent
                                      ? Colors.red
                                      : Colors.orange,
                                ),
                              ),
                            ],
                            if (due != null) ...[
                              Text(
                                dateKey(due),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: overdue ? Colors.red : null,
                                  fontWeight: overdue ? FontWeight.w800 : null,
                                ),
                              ),
                            ],
                            if (item.energyLevel != EnergyLevel.none) ...[
                              Icon(
                                item.energyLevel == EnergyLevel.high
                                    ? Icons.bolt
                                    : Icons.battery_saver,
                                size: 15,
                                color: item.energyLevel == EnergyLevel.high
                                    ? Colors.orange
                                    : Colors.lightBlue,
                              ),
                              Text(
                                item.energyLevel == EnergyLevel.high
                                    ? 'HIGH ENERGY'
                                    : 'LOW ENERGY',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: item.energyLevel == EnergyLevel.high
                                      ? Colors.orange
                                      : Colors.lightBlue,
                                ),
                              ),
                            ],
                            if (item.recurring) ...[
                              const Icon(Icons.repeat, size: 14),
                              Text(
                                item.recurrenceDays == 1
                                    ? 'DAILY'
                                    : '${item.recurrenceDays} DAYS',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                decoration: completed
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: completed ? Colors.grey : null,
                              ),
                        ),
                        if (item.notes.isNotEmpty)
                          Text(
                            item.notes,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (item.checklistTotal > 0) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: List.generate(
                              item.checklistTotal,
                              (index) => InkWell(
                                onTap: () => widget.controller.updateChecklist(
                                  item,
                                  index < item.checklistDone
                                      ? index
                                      : index + 1,
                                ),
                                borderRadius: BorderRadius.circular(5),
                                child: Container(
                                  width: 21,
                                  height: 21,
                                  decoration: BoxDecoration(
                                    color: index < item.checklistDone
                                        ? Colors.green
                                        : Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                    ),
                                  ),
                                  child: index < item.checklistDone
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 15,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${item.checklistDone}/${item.checklistTotal} completed • ${item.checklistLeft} left • ${(item.progress * 100).round()}%',
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (compact)
                    PopupMenuButton<String>(
                      tooltip: 'Task actions',
                      onSelected: (value) {
                        if (value == 'focus') {
                          showQuickFocusDialog(
                            context,
                            widget.controller,
                            item: item,
                          );
                        } else if (value == 'edit' && widget.allowEditing) {
                          showWorkItemEditor(
                            context,
                            widget.controller,
                            item: item,
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                          value: 'focus',
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.timer_outlined),
                            title: Text('Focus'),
                          ),
                        ),
                        if (widget.allowEditing)
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Edit'),
                            ),
                          ),
                      ],
                    )
                  else ...[
                    IconButton(
                      onPressed: () => showQuickFocusDialog(
                        context,
                        widget.controller,
                        item: item,
                      ),
                      icon: const Icon(Icons.timer_outlined),
                    ),
                    if (widget.allowEditing)
                      IconButton(
                        onPressed: () => showWorkItemEditor(
                          context,
                          widget.controller,
                          item: item,
                        ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (!collapsed)
            for (final child in children)
              _node(context, child, byParent, depth + 1),
        ],
      ),
    );
  }
}
