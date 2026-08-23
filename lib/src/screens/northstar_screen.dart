import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/app_scope.dart';
import '../models/models.dart';
import '../services/word_export_service.dart';
import '../utils/app_utils.dart';

class NorthStarScreen extends StatefulWidget {
  const NorthStarScreen({super.key});

  @override
  State<NorthStarScreen> createState() => _NorthStarScreenState();
}

class _NorthStarScreenState extends State<NorthStarScreen> {
  bool _showHidden = false;
  bool _showArchived = false;
  bool _noteManipulationInProgress = false;
  String? _selectedNoteId;
  final TransformationController _transformController =
      TransformationController();
  bool _middleMousePanning = false;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final notes =
        controller.northStarNotes
            .where(
              (note) =>
                  (!note.hidden || _showHidden) &&
                  (!note.archived || _showArchived),
            )
            .toList()
          ..sort(
            (a, b) => a.pinned == b.pinned
                ? a.sortKey.compareTo(b.sortKey)
                : (a.pinned ? 1 : -1),
          );
    final selectedIndex = notes.indexWhere(
      (note) => note.id == _selectedNoteId,
    );
    if (selectedIndex >= 0 && selectedIndex != notes.length - 1) {
      final selected = notes.removeAt(selectedIndex);
      notes.add(selected);
    }
    NorthStarNote? selectedNote;
    for (final note in notes) {
      if (note.id == _selectedNoteId) {
        selectedNote = note;
        break;
      }
    }
    final activeNote = selectedNote;

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
                  const Icon(Icons.explore_outlined),
                  SizedBox(
                    width: (MediaQuery.sizeOf(context).width - 74)
                        .clamp(220, 520)
                        .toDouble(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NorthStar',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Text(
                          'A colorful, movable, resizable place for operating rules, images, links, and pinned reminders.',
                          softWrap: true,
                        ),
                      ],
                    ),
                  ),
                  FilterChip(
                    label: const Text('Hidden'),
                    selected: _showHidden,
                    onSelected: (value) => setState(() => _showHidden = value),
                  ),
                  FilterChip(
                    avatar: const Icon(Icons.archive_outlined, size: 18),
                    label: const Text('Archived'),
                    selected: _showArchived,
                    onSelected: (value) =>
                        setState(() => _showArchived = value),
                  ),
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<String?>(
                      isExpanded: true,
                      initialValue: activeNote?.id,
                      decoration: const InputDecoration(
                        labelText: 'Select a note',
                        prefixIcon: Icon(Icons.sticky_note_2_outlined),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Choose any note'),
                        ),
                        ...notes.map(
                          (note) => DropdownMenuItem<String?>(
                            value: note.id,
                            child: Text(
                              '${note.archived ? '[Archived] ' : ''}${note.title}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _selectedNoteId = value),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: notes.isEmpty
                        ? null
                        : () => _exportAll(context, notes),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Export Word'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _edit(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Note'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: MouseRegion(
              cursor: _middleMousePanning ? SystemMouseCursors.move : MouseCursor.defer,
              child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerSignal: _handlePointerSignal,
                      onPointerDown: _handlePointerDown,
                      onPointerMove: _handlePointerMove,
                      onPointerUp: _handlePointerUp,
                      onPointerCancel: _handlePointerCancel,
                      child: InteractiveViewer(
                        transformationController: _transformController,
                        minScale: 0.35,
                        maxScale: 2.4,
                        panEnabled:
                            !_noteManipulationInProgress && !_middleMousePanning,
                        scaleEnabled: !_noteManipulationInProgress,
                        trackpadScrollCausesScale: false,
                        boundaryMargin: const EdgeInsets.all(600),
                        constrained: false,
                        child: SizedBox(
                        width: 2600,
                        height: 1800,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            for (final note in notes)
                              _MovableNote(
                                key: ValueKey(note.id),
                                note: note,
                                titleScale: controller.northStarTitleScale(
                                  note.id,
                                ),
                                bodyScale: controller.northStarBodyScale(
                                  note.id,
                                ),
                                onEdit: () => _edit(context, note: note),
                                onExport: () => _exportNote(context, note),
                                onTogglePin: () =>
                                    controller.updateNorthStarNote(
                                      note.copyWith(pinned: !note.pinned),
                                    ),
                                selected: note.id == _selectedNoteId,
                                onSelect: () {
                                  if (_selectedNoteId != note.id) {
                                    setState(() => _selectedNoteId = note.id);
                                  }
                                },
                                currentCanvasScale: () => _transformController
                                    .value
                                    .getMaxScaleOnAxis()
                                    .clamp(0.35, 2.4)
                                    .toDouble(),
                                onManipulationChanged: (value) {
                                  if (_noteManipulationInProgress == value) {
                                    return;
                                  }
                                  setState(
                                    () => _noteManipulationInProgress = value,
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                  if (activeNote != null)
                    Positioned(
                      left: 14,
                      top: 14,
                      child: Card(
                        elevation: 7,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.open_with, size: 18),
                              const SizedBox(width: 7),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 220,
                                ),
                                child: Text(
                                  activeNote.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: () =>
                                    _edit(context, note: activeNote),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit'),
                              ),
                              const SizedBox(width: 6),
                              OutlinedButton.icon(
                                onPressed: () => controller.updateNorthStarNote(
                                  activeNote.copyWith(
                                    pinned: !activeNote.pinned,
                                  ),
                                ),
                                icon: Icon(
                                  activeNote.pinned
                                      ? Icons.push_pin
                                      : Icons.push_pin_outlined,
                                ),
                                label: Text(
                                  activeNote.pinned ? 'Unpin' : 'Pin',
                                ),
                              ),
                              const SizedBox(width: 6),
                              OutlinedButton.icon(
                                onPressed: () => controller.updateNorthStarNote(
                                  activeNote.copyWith(
                                    archived: !activeNote.archived,
                                  ),
                                ),
                                icon: Icon(
                                  activeNote.archived
                                      ? Icons.unarchive_outlined
                                      : Icons.archive_outlined,
                                ),
                                label: Text(
                                  activeNote.archived ? 'Restore' : 'Archive',
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close note controls',
                                onPressed: () =>
                                    setState(() => _selectedNoteId = null),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 14,
                    bottom: 14,
                    child: IgnorePointer(
                      child: Card(
                        elevation: 2,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          child: Text(
                            'Wheel pan • Middle drag 4-way • Ctrl+wheel zoom',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: Card(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Zoom out',
                            onPressed: () => _zoomBy(0.82),
                            icon: const Icon(Icons.remove),
                          ),
                          IconButton(
                            tooltip: 'Fit and center notes',
                            onPressed: notes.isEmpty
                                ? null
                                : () => _fitNotes(notes),
                            icon: const Icon(Icons.center_focus_strong),
                          ),
                          IconButton(
                            tooltip: 'Zoom in',
                            onPressed: () => _zoomBy(1.22),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      final scroll = resolved as PointerScrollEvent;
      if (HardwareKeyboard.instance.isControlPressed) {
        _zoomBy(scroll.scrollDelta.dy > 0 ? 0.90 : 1.10);
      } else {
        _panViewport(-scroll.scrollDelta.dx, -scroll.scrollDelta.dy);
      }
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    if ((event.buttons & kMiddleMouseButton) != 0) {
      setState(() => _middleMousePanning = true);
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_middleMousePanning && (event.buttons & kMiddleMouseButton) != 0) {
      _panViewport(event.delta.dx, event.delta.dy);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_middleMousePanning) setState(() => _middleMousePanning = false);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_middleMousePanning) setState(() => _middleMousePanning = false);
  }

  void _panViewport(double screenDx, double screenDy) {
    final current = _transformController.value;
    final scale = current.getMaxScaleOnAxis().clamp(0.35, 2.4).toDouble();
    _transformController.value = current.clone()
      ..translateByDouble(screenDx / scale, screenDy / scale, 0, 1);
  }

  void _zoomBy(double factor) {
    final current = _transformController.value;
    final scale = current.getMaxScaleOnAxis();
    final target = (scale * factor).clamp(0.35, 2.4).toDouble();
    final ratio = target / scale;
    _transformController.value = current.clone()
      ..scaleByDouble(ratio, ratio, ratio, 1);
  }

  void _fitNotes(List<NorthStarNote> notes) {
    if (notes.isEmpty) return;
    var left = notes.first.x;
    var top = notes.first.y;
    var right = notes.first.x + notes.first.width;
    var bottom = notes.first.y + notes.first.height;
    for (final note in notes.skip(1)) {
      if (note.x < left) left = note.x;
      if (note.y < top) top = note.y;
      if (note.x + note.width > right) right = note.x + note.width;
      if (note.y + note.height > bottom) bottom = note.y + note.height;
    }
    final boxWidth = (right - left + 180).clamp(320.0, 2600.0).toDouble();
    final boxHeight = (bottom - top + 180).clamp(260.0, 1800.0).toDouble();
    final viewport = context.size;
    if (viewport == null) return;
    final scale = (viewport.width / boxWidth).clamp(0.35, 1.6).toDouble();
    final yScale = (viewport.height / boxHeight).clamp(0.35, 1.6).toDouble();
    final fitted = scale < yScale ? scale : yScale;
    final matrix = Matrix4.identity()
      ..translateByDouble(
        (viewport.width - boxWidth * fitted) / 2 - left * fitted + 90 * fitted,
        (viewport.height - boxHeight * fitted) / 2 - top * fitted + 90 * fitted,
        0,
        1,
      )
      ..scaleByDouble(fitted, fitted, fitted, 1);
    _transformController.value = matrix;
  }

  Future<void> _exportNote(BuildContext context, NorthStarNote note) async {
    final path = await WordExportService.exportNorthStarNote(note);
    if (context.mounted && path != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Word document saved to $path')));
    }
  }

  Future<void> _exportAll(
    BuildContext context,
    List<NorthStarNote> notes,
  ) async {
    final path = await WordExportService.exportNorthStarCollection(notes);
    if (context.mounted && path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('NorthStar Word export saved to $path')),
      );
    }
  }

  Future<void> _edit(BuildContext context, {NorthStarNote? note}) async {
    final controller = AppScope.of(context);
    final title = TextEditingController(
      text: note?.title ?? 'New NorthStar note',
    );
    final body = TextEditingController(text: note?.body ?? '');
    final link = TextEditingController(text: note?.link ?? '');
    final folder = TextEditingController(text: note?.folder ?? '');
    var pinned = note?.pinned ?? false;
    var hidden = note?.hidden ?? false;
    var archived = note?.archived ?? false;
    var color = parseHexColor(note?.colorHex) ?? const Color(0xFFFFD86B);
    var textColor = parseHexColor(note?.textColorHex) ?? Colors.black;
    var weight = note?.fontWeightValue ?? 600;
    var titleScale = note == null
        ? 1.0
        : controller.northStarTitleScale(note.id);
    var bodyScale = note == null ? 1.0 : controller.northStarBodyScale(note.id);
    var imageBase64 = note?.imageBase64 ?? '';
    List<Map<String, dynamic>> checklist = [];
    try {
      checklist = (jsonDecode(note?.checklistJson ?? '[]') as List)
          .whereType<Map>()
          .map((value) => value.cast<String, dynamic>())
          .toList();
    } catch (_) {}

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 24,
          ),
          title: Text(
            note == null ? 'New NorthStar note' : 'Edit NorthStar note',
          ),
          content: SizedBox(
            width: (MediaQuery.sizeOf(context).width - 48)
                .clamp(240, 680)
                .toDouble(),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: body,
                    minLines: 6,
                    maxLines: 14,
                    decoration: const InputDecoration(
                      labelText: 'Notes / steps / purpose',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 320,
                        child: TextField(
                          controller: folder,
                          decoration: const InputDecoration(
                            labelText: 'Folder',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 320,
                        child: TextField(
                          controller: link,
                          decoration: const InputDecoration(
                            labelText: 'Link or video URL',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ColorButton(
                        label: 'Card',
                        color: color,
                        onChanged: (value) =>
                            setDialogState(() => color = value),
                      ),
                      _ColorButton(
                        label: 'Text',
                        color: textColor,
                        onChanged: (value) =>
                            setDialogState(() => textColor = value),
                      ),
                      SizedBox(
                        width: 190,
                        child: DropdownButtonFormField<int>(
                          initialValue: weight,
                          decoration: const InputDecoration(
                            labelText: 'Font boldness',
                          ),
                          items: const [300, 400, 500, 600, 700, 800, 900]
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text('$value'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => weight = value ?? weight),
                        ),
                      ),
                      SizedBox(
                        width: 230,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Title size ${(titleScale * 100).round()}%'),
                            Slider(
                              value: titleScale,
                              min: 0.65,
                              max: 2.0,
                              divisions: 27,
                              onChanged: (value) =>
                                  setDialogState(() => titleScale = value),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 230,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Body size ${(bodyScale * 100).round()}%'),
                            Slider(
                              value: bodyScale,
                              min: 0.65,
                              max: 2.0,
                              divisions: 27,
                              onChanged: (value) =>
                                  setDialogState(() => bodyScale = value),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final result = await FilePicker.pickFiles(
                            type: FileType.image,
                            withData: true,
                          );
                          final selected = result?.files.single;
                          final Uint8List? resolvedBytes = selected?.bytes;
                          if (resolvedBytes != null) {
                            setDialogState(
                              () => imageBase64 = base64Encode(resolvedBytes),
                            );
                          }
                        },
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Image'),
                      ),
                      if (imageBase64.isNotEmpty)
                        TextButton(
                          onPressed: () =>
                              setDialogState(() => imageBase64 = ''),
                          child: const Text('Remove image'),
                        ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: pinned,
                    onChanged: (value) => setDialogState(() => pinned = value),
                    title: const Text('Pin note'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: hidden,
                    onChanged: (value) => setDialogState(() => hidden = value),
                    title: const Text('Hide note'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: archived,
                    onChanged: (value) =>
                        setDialogState(() => archived = value),
                    title: const Text('Archive note'),
                    subtitle: const Text(
                      'Keeps the note and removes it from the active canvas.',
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Checklist',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setDialogState(
                          () => checklist.add({
                            'text': 'New step',
                            'done': false,
                          }),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Step'),
                      ),
                    ],
                  ),
                  for (var index = 0; index < checklist.length; index++)
                    Row(
                      children: [
                        Checkbox(
                          value: checklist[index]['done'] == true,
                          onChanged: (value) => setDialogState(
                            () => checklist[index]['done'] = value == true,
                          ),
                        ),
                        Expanded(
                          child: TextFormField(
                            initialValue:
                                checklist[index]['text']?.toString() ?? '',
                            onChanged: (value) =>
                                checklist[index]['text'] = value,
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              setDialogState(() => checklist.removeAt(index)),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          actions: [
            if (note != null)
              TextButton(
                onPressed: () async {
                  await controller.deleteNorthStarNote(note);
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

    if (accepted != true || title.text.trim().isEmpty) return;
    if (note == null) {
      final created = await controller.createNorthStarNote(
        title: title.text.trim(),
        body: body.text,
      );
      await controller.updateNorthStarNote(
        created.copyWith(
          pinned: pinned,
          hidden: hidden,
          archived: archived,
          colorHex: toHexColor(color),
          textColorHex: toHexColor(textColor),
          fontWeightValue: weight,
          imageBase64: imageBase64,
          link: link.text.trim(),
          folder: folder.text.trim(),
          checklistJson: jsonEncode(checklist),
          x: 80 + controller.northStarNotes.length * 30,
          y: 80 + controller.northStarNotes.length * 24,
        ),
      );
      await controller.setNorthStarTextScales(
        created.id,
        titleScale: titleScale,
        bodyScale: bodyScale,
      );
    } else {
      await controller.updateNorthStarNote(
        note.copyWith(
          title: title.text.trim(),
          body: body.text,
          pinned: pinned,
          hidden: hidden,
          archived: archived,
          colorHex: toHexColor(color),
          textColorHex: toHexColor(textColor),
          fontWeightValue: weight,
          imageBase64: imageBase64,
          link: link.text.trim(),
          folder: folder.text.trim(),
          checklistJson: jsonEncode(checklist),
        ),
      );
      await controller.setNorthStarTextScales(
        note.id,
        titleScale: titleScale,
        bodyScale: bodyScale,
      );
    }
  }
}

class _MovableNote extends StatefulWidget {
  const _MovableNote({
    super.key,
    required this.note,
    required this.titleScale,
    required this.bodyScale,
    required this.onEdit,
    required this.onExport,
    required this.onTogglePin,
    required this.selected,
    required this.onSelect,
    required this.currentCanvasScale,
    required this.onManipulationChanged,
  });

  final NorthStarNote note;
  final double titleScale;
  final double bodyScale;
  final VoidCallback onEdit;
  final VoidCallback onExport;
  final VoidCallback onTogglePin;
  final bool selected;
  final VoidCallback onSelect;
  final double Function() currentCanvasScale;
  final ValueChanged<bool> onManipulationChanged;

  @override
  State<_MovableNote> createState() => _MovableNoteState();
}

class _MovableNoteState extends State<_MovableNote> {
  late double x;
  late double y;
  late double width;
  late double height;
  bool _movedDuringPointer = false;
  bool _resizedDuringPointer = false;

  @override
  void initState() {
    super.initState();
    x = widget.note.x;
    y = widget.note.y;
    width = widget.note.width;
    height = widget.note.height;
  }

  @override
  void didUpdateWidget(covariant _MovableNote oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note.updatedAt != widget.note.updatedAt) {
      x = widget.note.x;
      y = widget.note.y;
      width = widget.note.width;
      height = widget.note.height;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final color =
        parseHexColor(widget.note.colorHex) ?? const Color(0xFFFFD86B);
    final textColor =
        parseHexColor(widget.note.textColorHex) ?? readableTextColor(color);
    final checklist = <Map<String, dynamic>>[];
    try {
      checklist.addAll(
        (jsonDecode(widget.note.checklistJson) as List).whereType<Map>().map(
          (value) => value.cast<String, dynamic>(),
        ),
      );
    } catch (_) {}

    return Positioned(
      left: x,
      top: y,
      width: width,
      height: height,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => widget.onSelect(),
        child: Material(
          elevation: widget.note.pinned ? 6 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: widget.selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: widget.selected ? 4 : 0,
            ),
          ),
          color: color,
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < 285 || constraints.maxHeight < 220;
              final headerHeight = compact ? 34.0 : 44.0;
              final titleSize = (compact ? 15.0 : 18.0) * widget.titleScale;
              final bodySize = (compact ? 11.5 : 14.0) * widget.bodyScale;
              final maxImageHeight = (constraints.maxHeight * 0.46)
                  .clamp(compact ? 62 : 90, 340)
                  .toDouble();

              return Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 10 : 14,
                        compact ? 7 : 10,
                        compact ? 10 : 14,
                        compact ? 10 : 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: headerHeight,
                            child: Row(
                              children: [
                                Expanded(
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.move,
                                    child: Tooltip(
                                      message:
                                          'Drag this title area to move. Double-click to edit.',
                                      child: Listener(
                                        behavior: HitTestBehavior.opaque,
                                        onPointerDown: (_) {
                                          _movedDuringPointer = false;
                                          widget.onSelect();
                                          widget.onManipulationChanged(true);
                                        },
                                        onPointerMove: (event) {
                                          final scale = widget
                                              .currentCanvasScale();
                                          _movedDuringPointer = true;
                                          setState(() {
                                            x += event.delta.dx / scale;
                                            y += event.delta.dy / scale;
                                          });
                                        },
                                        onPointerUp: (_) {
                                          widget.onManipulationChanged(false);
                                          if (_movedDuringPointer) {
                                            controller.updateNorthStarNote(
                                              widget.note.copyWith(x: x, y: y),
                                            );
                                          }
                                        },
                                        onPointerCancel: (_) =>
                                            widget.onManipulationChanged(false),
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onDoubleTap: widget.onEdit,
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 34,
                                                height: 34,
                                                child: Icon(
                                                  Icons.open_with,
                                                  size: compact ? 17 : 20,
                                                  color: textColor,
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  widget.note.title,
                                                  maxLines: compact ? 1 : 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  softWrap: true,
                                                  style: TextStyle(
                                                    color: textColor,
                                                    fontWeight:
                                                        FontWeight
                                                            .values[((widget
                                                                            .note
                                                                            .fontWeightValue /
                                                                        100)
                                                                    .round() -
                                                                1)
                                                            .clamp(0, 8)
                                                            .toInt()],
                                                    fontSize: titleSize,
                                                    height: 1.05,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: widget.note.pinned
                                      ? 'Unpin note'
                                      : 'Pin note',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 30,
                                    height: 30,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: widget.onTogglePin,
                                  icon: Icon(
                                    widget.note.pinned
                                        ? Icons.push_pin
                                        : Icons.push_pin_outlined,
                                    color: textColor,
                                    size: compact ? 15 : 17,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Export note to Word',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 30,
                                    height: 30,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: widget.onExport,
                                  icon: Icon(
                                    Icons.description_outlined,
                                    color: textColor,
                                    size: compact ? 15 : 17,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit note',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(
                                    width: 30,
                                    height: 30,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: widget.onEdit,
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    color: textColor,
                                    size: compact ? 15 : 17,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ClipRect(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.only(right: 4),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (widget.note.folder.isNotEmpty)
                                      Text(
                                        widget.note.folder,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: textColor.withValues(
                                            alpha: .72,
                                          ),
                                          fontSize: compact ? 9.5 : 11,
                                        ),
                                      ),
                                    if (widget.note.imageBase64.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minHeight: compact ? 54 : 78,
                                            maxHeight: maxImageHeight,
                                          ),
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: Image.memory(
                                              base64Decode(
                                                widget.note.imageBase64,
                                              ),
                                              fit: BoxFit.contain,
                                              alignment: Alignment.topCenter,
                                              errorBuilder:
                                                  (context, error, stack) =>
                                                      const SizedBox.shrink(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (widget.note.body.trim().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        widget.note.body,
                                        softWrap: true,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: bodySize,
                                          height: 1.25,
                                        ),
                                      ),
                                    ],
                                    if (checklist.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      for (final item in checklist)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 4,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Icon(
                                                item['done'] == true
                                                    ? Icons.check_box
                                                    : Icons
                                                          .check_box_outline_blank,
                                                size: compact ? 14 : 16,
                                                color: textColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  item['text']?.toString() ??
                                                      '',
                                                  softWrap: true,
                                                  style: TextStyle(
                                                    color: textColor,
                                                    fontSize: compact
                                                        ? 10.5
                                                        : 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                    if (widget.note.link.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        widget.note.link,
                                        maxLines: compact ? 1 : 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: textColor,
                                          decoration: TextDecoration.underline,
                                          fontSize: compact ? 9.5 : 11,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 18),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeDownRight,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (_) {
                          _resizedDuringPointer = false;
                          widget.onSelect();
                          widget.onManipulationChanged(true);
                        },
                        onPointerMove: (event) {
                          final scale = widget.currentCanvasScale();
                          _resizedDuringPointer = true;
                          setState(() {
                            width = (width + event.delta.dx / scale)
                                .clamp(220, 900)
                                .toDouble();
                            height = (height + event.delta.dy / scale)
                                .clamp(160, 760)
                                .toDouble();
                          });
                        },
                        onPointerUp: (_) {
                          widget.onManipulationChanged(false);
                          if (_resizedDuringPointer) {
                            controller.updateNorthStarNote(
                              widget.note.copyWith(
                                width: width,
                                height: height,
                              ),
                            );
                          }
                        },
                        onPointerCancel: (_) =>
                            widget.onManipulationChanged(false),
                        child: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.bottomRight,
                          child: Icon(
                            Icons.drag_handle,
                            color: textColor,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ColorButton extends StatelessWidget {
  const _ColorButton({
    required this.label,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFFFFD86B),
      Color(0xFF80CBC4),
      Color(0xFF90CAF9),
      Color(0xFFCE93D8),
      Color(0xFFFFAB91),
      Color(0xFFFFFFFF),
      Color(0xFF212121),
    ];
    return PopupMenuButton<Color>(
      onSelected: onChanged,
      itemBuilder: (context) => colors
          .map(
            (value) => PopupMenuItem(
              value: value,
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: value, radius: 10),
                  const SizedBox(width: 8),
                  Text(
                    '#${value.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Chip(
        avatar: CircleAvatar(backgroundColor: color, radius: 9),
        label: Text(label),
      ),
    );
  }
}
