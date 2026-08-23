import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/models.dart';
import '../repositories/app_repository.dart';
import '../utils/app_utils.dart';

Future<void> showWorkItemEditor(
  BuildContext context,
  AppController controller, {
  WorkItem? item,
  WorkItem? parent,
  WorkItemType? initialType,
  DateTime? initialDueDate,
}) async {
  final titleController = TextEditingController(text: item?.title ?? '');
  final notesController = TextEditingController(text: item?.notes ?? '');
  final folderController = TextEditingController(text: item?.folder ?? '');
  var type = item?.type ?? initialType ?? _nextChildType(parent?.type);
  String? parentId = item?.parentId ?? parent?.id;
  var priority = item?.priority == PriorityLevel.urgent
      ? PriorityLevel.important
      : item?.priority ?? PriorityLevel.normal;
  var urgent = item?.urgent ?? item?.priority == PriorityLevel.urgent;
  var status = item?.status ?? WorkStatus.active;
  var gtdStatus = item?.gtdStatus ?? GtdStatus.inbox;
  var paraCategory = item?.paraCategory ?? 'Projects';
  DateTime? dueDate = item?.dueDate ?? initialDueDate?.toUtc();
  var checklistTotal = item?.checklistTotal ?? 0;
  var checklistDone = item?.checklistDone ?? 0;
  var timerMinutes = item?.timerMinutes ?? controller.defaultSessionMinutes;
  var sessionGoal = item?.sessionGoal ?? 1;
  var recurring = item?.recurring ?? false;
  var recurrenceDays = item?.recurrenceDays ?? 1;
  var energyLevel = item?.energyLevel ?? EnergyLevel.none;
  var childColumns = item?.childColumns ?? 4;
  var titleScale = item?.titleScale ?? 1.0;
  var titleBold = item?.titleBold ?? true;
  String? textColorHex = item?.textColorHex;
  String? bigColorHex = item == null
      ? null
      : controller.layoutFor(item, CanvasViewKind.bigPicture).colorHex;
  String? mindColorHex = item == null
      ? null
      : controller.layoutFor(item, CanvasViewKind.mindMap).colorHex;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final disallowedIds = item == null
            ? <String>{}
            : {
                item.id,
                ...controller.descendantsOf(item.id).map((value) => value.id),
              };
        final parentOptions =
            controller.workItems
                .where(
                  (candidate) =>
                      !candidate.isDeleted &&
                      !disallowedIds.contains(candidate.id) &&
                      candidate.type.index < type.index,
                )
                .toList()
              ..sort((a, b) {
                final level = a.type.index.compareTo(b.type.index);
                return level != 0 ? level : a.title.compareTo(b.title);
              });
        if (parentId != null &&
            !parentOptions.any((candidate) => candidate.id == parentId)) {
          parentId = null;
        }

        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          title: Text(
            item == null ? 'Add hierarchy item' : 'Edit hierarchy item',
          ),
          content: SizedBox(
            width: (MediaQuery.sizeOf(context).width - 48)
                .clamp(240, 820)
                .toDouble(),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleController,
                    autofocus: item == null,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<EnergyLevel>(
                          initialValue: energyLevel,
                          decoration: const InputDecoration(
                            labelText: 'Energy needed',
                            helperText: 'Shown as a colored card tag',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: EnergyLevel.none,
                              child: Text('Not specified'),
                            ),
                            DropdownMenuItem(
                              value: EnergyLevel.low,
                              child: Text('🔵 Low energy'),
                            ),
                            DropdownMenuItem(
                              value: EnergyLevel.high,
                              child: Text('🟠 High energy'),
                            ),
                          ],
                          onChanged: (value) => setState(
                            () => energyLevel = value ?? energyLevel,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NumberField(
                          label: 'Child columns in Big Picture',
                          value: childColumns,
                          minimum: 1,
                          maximum: 12,
                          onChanged: (value) => childColumns = value,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<WorkItemType>(
                          isExpanded: true,
                          initialValue: type,
                          decoration: const InputDecoration(labelText: 'Level'),
                          items: WorkItemType.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(() {
                            type = value ?? type;
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          isExpanded: true,
                          initialValue: parentId,
                          decoration: const InputDecoration(
                            labelText: 'Parent',
                            helperText: 'Only higher levels can be parents',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('No parent / top-level Goal'),
                            ),
                            ...parentOptions.map(
                              (candidate) => DropdownMenuItem<String?>(
                                value: candidate.id,
                                child: Text(
                                  '${candidate.type.name}: ${candidate.title}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => parentId = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<PriorityLevel>(
                          isExpanded: true,
                          initialValue: priority,
                          decoration: const InputDecoration(
                            labelText: 'Importance',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: PriorityLevel.normal,
                              child: Text('Normal'),
                            ),
                            DropdownMenuItem(
                              value: PriorityLevel.important,
                              child: Text('Important'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => priority = value ?? priority),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SwitchListTile(
                          value: urgent,
                          onChanged: (value) => setState(() => urgent = value),
                          title: const Text('Urgent'),
                          subtitle: const Text('Shown as a separate red tag'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<WorkStatus>(
                          isExpanded: true,
                          initialValue: status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                          ),
                          items: WorkStatus.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => status = value ?? status),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<GtdStatus>(
                          isExpanded: true,
                          initialValue: gtdStatus,
                          decoration: const InputDecoration(
                            labelText: 'GTD workflow',
                          ),
                          items: GtdStatus.values
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(_gtdLabel(value)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => gtdStatus = value ?? gtdStatus),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: paraCategory,
                          decoration: const InputDecoration(
                            labelText: 'PARA category',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Projects',
                              child: Text('Projects'),
                            ),
                            DropdownMenuItem(
                              value: 'Areas',
                              child: Text('Areas'),
                            ),
                            DropdownMenuItem(
                              value: 'Resources',
                              child: Text('Resources'),
                            ),
                            DropdownMenuItem(
                              value: 'Archive',
                              child: Text('Archive'),
                            ),
                          ],
                          onChanged: (value) => setState(
                            () => paraCategory = value ?? paraCategory,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: folderController,
                          decoration: const InputDecoration(
                            labelText: 'Folder / area label',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDate: dueDate?.toLocal() ?? DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => dueDate = picked.toUtc());
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Due date'),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              dueDate == null
                                  ? 'No due date'
                                  : MaterialLocalizations.of(
                                      context,
                                    ).formatMediumDate(dueDate!.toLocal()),
                            ),
                          ),
                          if (dueDate != null)
                            IconButton(
                              tooltip: 'Clear date',
                              onPressed: () => setState(() => dueDate = null),
                              icon: const Icon(Icons.clear),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _NumberField(
                          label: 'Checklist boxes (0–200)',
                          value: checklistTotal,
                          minimum: 0,
                          maximum: 200,
                          onChanged: (value) {
                            checklistTotal = value;
                            checklistDone = checklistDone
                                .clamp(0, value)
                                .toInt();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NumberField(
                          label: 'Completed boxes',
                          value: checklistDone,
                          minimum: 0,
                          maximum: checklistTotal,
                          onChanged: (value) => checklistDone = value,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NumberField(
                          label: 'Default timer minutes',
                          value: timerMinutes,
                          minimum: 1,
                          maximum: 720,
                          onChanged: (value) => timerMinutes = value,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NumberField(
                          label: 'Sessions needed',
                          value: sessionGoal,
                          minimum: 1,
                          maximum: 200,
                          onChanged: (value) => sessionGoal = value,
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: recurring,
                    onChanged: (value) => setState(() {
                      recurring = value;
                      if (value && dueDate == null) {
                        final now = DateTime.now();
                        dueDate = DateTime(
                          now.year,
                          now.month,
                          now.day,
                        ).toUtc();
                      }
                    }),
                    title: const Text('Recurring item'),
                    subtitle: const Text(
                      'Completing it keeps the completed copy and creates the next active copy.',
                    ),
                  ),
                  if (recurring)
                    _NumberField(
                      label: 'Repeat every how many days?',
                      value: recurrenceDays,
                      minimum: 1,
                      maximum: 3650,
                      onChanged: (value) => recurrenceDays = value,
                    ),
                  const Divider(height: 28),
                  Text(
                    'Text and color preferences',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Title size: ${titleScale.toStringAsFixed(2)}×',
                            ),
                            Slider(
                              value: titleScale,
                              min: 0.75,
                              max: 2.0,
                              divisions: 25,
                              onChanged: (value) =>
                                  setState(() => titleScale = value),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SwitchListTile(
                          value: titleBold,
                          onChanged: (value) =>
                              setState(() => titleBold = value),
                          title: const Text('Bold title'),
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _ColorField(
                        label: 'Text',
                        colorHex: textColorHex,
                        onChanged: (value) =>
                            setState(() => textColorHex = value),
                      ),
                      _ColorField(
                        label: 'Big Picture card',
                        colorHex: bigColorHex,
                        onChanged: (value) =>
                            setState(() => bigColorHex = value),
                      ),
                      _ColorField(
                        label: 'Mind Map card',
                        colorHex: mindColorHex,
                        onChanged: (value) =>
                            setState(() => mindColorHex = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    minLines: 4,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Notes / definition of done',
                      alignLabelWithHint: true,
                    ),
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
              child: const Text('Save'),
            ),
          ],
        );
      },
    ),
  );

  if (result != true || titleController.text.trim().isEmpty) {
    _disposeWorkItemEditorControllersLater(
      titleController,
      notesController,
      folderController,
    );
    return;
  }

  // Let the dialog route finish its reverse transition before notifying the
  // app and rebuilding the hierarchy below it.
  await Future<void>.delayed(const Duration(milliseconds: 250));

  WorkItem saved;
  if (recurring && dueDate == null) {
    final now = DateTime.now();
    dueDate = DateTime(now.year, now.month, now.day).toUtc();
  }
  if (item == null) {
    final created = await controller.createWorkItem(
      title: titleController.text,
      type: type,
      parentId: parentId,
    );
    saved = created.copyWith(
      notes: notesController.text,
      dueDate: dueDate,
      priority: priority,
      urgent: urgent,
      status: status,
      gtdStatus: gtdStatus,
      paraCategory: paraCategory,
      checklistTotal: checklistTotal,
      checklistDone: checklistDone,
      timerMinutes: timerMinutes,
      sessionGoal: sessionGoal,
      recurring: recurring,
      recurrenceDays: recurrenceDays,
      energyLevel: energyLevel,
      childColumns: childColumns,
      titleScale: titleScale,
      titleBold: titleBold,
      textColorHex: textColorHex,
      folder: folderController.text.trim(),
    );
  } else {
    saved = item.copyWith(
      title: titleController.text.trim(),
      type: type,
      parentId: parentId,
      notes: notesController.text,
      dueDate: dueDate,
      priority: priority,
      urgent: urgent,
      status: status,
      gtdStatus: gtdStatus,
      paraCategory: paraCategory,
      checklistTotal: checklistTotal,
      checklistDone: checklistDone,
      timerMinutes: timerMinutes,
      sessionGoal: sessionGoal,
      recurring: recurring,
      recurrenceDays: recurrenceDays,
      energyLevel: energyLevel,
      childColumns: childColumns,
      titleScale: titleScale,
      titleBold: titleBold,
      textColorHex: textColorHex,
      folder: folderController.text.trim(),
    );
  }
  await controller.updateWorkItem(saved);
  final current = controller.itemById(saved.id) ?? saved;
  final bigLayout = controller
      .layoutFor(current, CanvasViewKind.bigPicture)
      .copyWith(colorHex: bigColorHex);
  final mindLayout = controller
      .layoutFor(current, CanvasViewKind.mindMap)
      .copyWith(colorHex: mindColorHex);
  await controller.saveLayout(bigLayout);
  await controller.saveLayout(mindLayout);

  _disposeWorkItemEditorControllersLater(
    titleController,
    notesController,
    folderController,
  );
}

void _disposeWorkItemEditorControllersLater(
  TextEditingController titleController,
  TextEditingController notesController,
  TextEditingController folderController,
) {
  // showDialog completes before its reverse transition has necessarily
  // removed every TextField from the overlay. Disposing immediately can
  // therefore leave the outgoing fields holding already-disposed
  // controllers. Give the route time to unmount, then release them.
  Future<void>.delayed(const Duration(milliseconds: 650), () {
    titleController.dispose();
    notesController.dispose();
    folderController.dispose();
  });
}

Future<void> showDeleteWorkItemDialog(
  BuildContext context,
  AppController controller,
  WorkItem item,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete item?'),
      content: Text(
        'Delete “${item.title}”? Its children will be promoted to the deleted item’s parent.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) await controller.deleteWorkItem(item);
}

Future<void> showDropIntentDialog(
  BuildContext context,
  AppController controller, {
  required String sourceId,
  required String targetId,
}) async {
  final source = controller.itemById(sourceId);
  final target = controller.itemById(targetId);
  if (source == null || target == null) return;
  final canMakeChild = target.type.index < source.type.index;
  final intent = await showModalBottomSheet<DropIntent>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Move “${source.title}”',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.vertical_align_top),
              title: Text('Place before “${target.title}”'),
              onTap: () => Navigator.pop(context, DropIntent.before),
            ),
            ListTile(
              enabled: canMakeChild,
              leading: const Icon(Icons.account_tree),
              title: Text('Make it a child of “${target.title}”'),
              subtitle: canMakeChild
                  ? null
                  : const Text('The parent must be a higher hierarchy level.'),
              onTap: canMakeChild
                  ? () => Navigator.pop(context, DropIntent.makeChild)
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.vertical_align_bottom),
              title: Text('Place after “${target.title}”'),
              onTap: () => Navigator.pop(context, DropIntent.after),
            ),
          ],
        ),
      ),
    ),
  );
  if (intent != null) {
    try {
      await controller.applyDrop(
        sourceId: sourceId,
        targetId: targetId,
        intent: intent,
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int minimum;
  final int maximum;
  final ValueChanged<int> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: widget.label),
      onChanged: (value) {
        final parsed = (int.tryParse(value) ?? widget.minimum)
            .clamp(widget.minimum, widget.maximum)
            .toInt();
        widget.onChanged(parsed);
      },
    );
  }
}

class _ColorField extends StatelessWidget {
  const _ColorField({
    required this.label,
    required this.colorHex,
    required this.onChanged,
  });

  final String label;
  final String? colorHex;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = parseHexColor(colorHex);
    return OutlinedButton.icon(
      onPressed: () async {
        final selected = await _pickColor(context, current);
        if (selected == const Color(0x00000000)) {
          onChanged(null);
        } else if (selected != null) {
          onChanged(toHexColor(selected));
        }
      },
      icon: CircleAvatar(
        radius: 9,
        backgroundColor: current ?? Theme.of(context).colorScheme.surface,
      ),
      label: Text(label),
    );
  }
}

Future<Color?> _pickColor(BuildContext context, Color? current) {
  const clear = Color(0x00000000);
  final palette = <Color>[
    const Color(0xFF2E7D32),
    const Color(0xFF43A047),
    const Color(0xFF00897B),
    const Color(0xFF1565C0),
    const Color(0xFF3949AB),
    const Color(0xFF6A1B9A),
    const Color(0xFFD81B60),
    const Color(0xFFC62828),
    const Color(0xFFEF6C00),
    const Color(0xFFF9A825),
    const Color(0xFF6D4C41),
    const Color(0xFF455A64),
    Colors.white,
    const Color(0xFF171717),
  ];
  return showDialog<Color>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Choose color'),
      content: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final color in palette)
            InkWell(
              onTap: () => Navigator.pop(context, color),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: current == color
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                    width: current == color ? 4 : 1,
                  ),
                ),
              ),
            ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, clear),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Use default'),
          ),
        ],
      ),
    ),
  );
}

String _gtdLabel(GtdStatus value) => switch (value) {
  GtdStatus.inbox => 'Inbox',
  GtdStatus.toDo => 'To be done',
  GtdStatus.inProgress => 'In progress',
  GtdStatus.completed => 'Completed',
  GtdStatus.archived => 'Archive',
};

WorkItemType _nextChildType(WorkItemType? parentType) => switch (parentType) {
  null => WorkItemType.goal,
  WorkItemType.goal => WorkItemType.milestone,
  WorkItemType.milestone => WorkItemType.project,
  WorkItemType.project => WorkItemType.subproject,
  WorkItemType.subproject => WorkItemType.module,
  WorkItemType.module => WorkItemType.task,
  WorkItemType.task => WorkItemType.task,
};
