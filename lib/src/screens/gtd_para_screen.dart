import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../controllers/app_scope.dart';
import '../models/models.dart';

class GtdParaScreen extends StatefulWidget {
  const GtdParaScreen({super.key});

  @override
  State<GtdParaScreen> createState() => _GtdParaScreenState();
}

class _GtdParaScreenState extends State<GtdParaScreen> {
  bool _para = false;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 620;
                  final title = Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.view_kanban_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GTD + PARA',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Text(
                              'Drag any item between workflow or PARA columns. The change appears everywhere.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  final selector = SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('GTD')),
                      ButtonSegment(value: true, label: Text('PARA')),
                    ],
                    selected: {_para},
                    onSelectionChanged: (value) =>
                        setState(() => _para = value.first),
                  );
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [title, const SizedBox(height: 10), selector],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: 12),
                      selector,
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _para
                ? _ParaBoard(controller: controller)
                : _GtdBoard(controller: controller),
          ),
        ],
      ),
    );
  }
}

class _GtdBoard extends StatelessWidget {
  const _GtdBoard({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return _HorizontalBoard(
      controller: controller,
      columns: GtdStatus.values.map((status) {
        return _BoardColumnData(
          title: _gtdName(status),
          items: controller.workItems
              .where((item) => !item.isDeleted && item.gtdStatus == status)
              .toList(),
          onDrop: (id) async {
            final item = controller.itemById(id);
            if (item == null) return;
            final statusValue = status == GtdStatus.completed
                ? WorkStatus.completed
                : status == GtdStatus.archived
                    ? WorkStatus.archived
                    : WorkStatus.active;
            await controller.updateWorkItem(
              item.copyWith(gtdStatus: status, status: statusValue),
            );
          },
        );
      }).toList(),
    );
  }

  String _gtdName(GtdStatus value) => switch (value) {
        GtdStatus.inbox => 'Inbox',
        GtdStatus.toDo => 'To Be Done',
        GtdStatus.inProgress => 'In Progress',
        GtdStatus.completed => 'Completed',
        GtdStatus.archived => 'Archive',
      };
}

class _ParaBoard extends StatelessWidget {
  const _ParaBoard({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    const categories = ['Projects', 'Areas', 'Resources', 'Archives'];
    return _HorizontalBoard(
      controller: controller,
      columns: categories.map((category) {
        return _BoardColumnData(
          title: category,
          items: controller.workItems
              .where(
                (item) => !item.isDeleted && item.paraCategory == category,
              )
              .toList(),
          onDrop: (id) async {
            final item = controller.itemById(id);
            if (item != null) {
              await controller.updateWorkItem(
                item.copyWith(paraCategory: category),
              );
            }
          },
        );
      }).toList(),
    );
  }
}

class _BoardColumnData {
  const _BoardColumnData({
    required this.title,
    required this.items,
    required this.onDrop,
  });

  final String title;
  final List<WorkItem> items;
  final Future<void> Function(String) onDrop;
}

class _HorizontalBoard extends StatelessWidget {
  const _HorizontalBoard({required this.controller, required this.columns});
  final AppController controller;
  final List<_BoardColumnData> columns;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: columns.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final column = columns[index];
          return SizedBox(
            width: 300,
            child: DragTarget<String>(
              onAcceptWithDetails: (details) => column.onDrop(details.data),
              builder: (context, candidates, rejected) {
                return Card(
                  color: candidates.isNotEmpty
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                column.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            Chip(label: Text('${column.items.length}')),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(8),
                          children: column.items.map((item) {
                            return Draggable<String>(
                              data: item.id,
                              feedback: Material(
                                child: SizedBox(
                                  width: 270,
                                  child: Card(
                                    child: ListTile(title: Text(item.title)),
                                  ),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.35,
                                child: _item(context, item),
                              ),
                              child: _item(context, item),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _item(BuildContext context, WorkItem item) {
    final canRestore = item.status == WorkStatus.completed || item.isArchived;
    return Card(
      child: ListTile(
        dense: true,
        leading: Icon(
          item.isCompleted ? Icons.check_circle : Icons.drag_indicator,
        ),
        title: Text(
          item.title,
          style: TextStyle(
            decoration: item.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text('${item.type.name} • ${item.priority.name}'),
        trailing: canRestore
            ? PopupMenuButton<String>(
                tooltip: 'Restore item',
                onSelected: (value) async {
                  if (value == 'unarchive') {
                    await controller.unarchiveWorkItem(item);
                  } else if (value == 'active') {
                    await controller.updateWorkItem(
                      item.copyWith(
                        status: WorkStatus.active,
                        gtdStatus: GtdStatus.toDo,
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  if (item.isArchived)
                    const PopupMenuItem(
                      value: 'unarchive',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.unarchive_outlined),
                        title: Text('Unarchive'),
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'active',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.replay_outlined),
                      title: Text('Restore to active'),
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}
