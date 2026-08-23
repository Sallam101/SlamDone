import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import 'canvas_painters.dart';

class CanvasWorkspace extends StatefulWidget {
  const CanvasWorkspace({
    super.key,
    required this.items,
    required this.layouts,
    required this.viewKind,
    required this.freeMove,
    required this.showConnections,
    required this.onLayoutChanged,
    required this.onDropRequested,
    required this.onEdit,
    required this.onDelete,
    required this.onAddChild,
    this.onChecklistChanged,
    this.onMakeRoot,
    this.onFocus,
    this.onItemChanged,
    this.textColorOverrides = const {},
    this.onTextColorChanged,
  });

  final List<WorkItem> items;
  final Map<String, CanvasLayout> layouts;
  final CanvasViewKind viewKind;
  final bool freeMove;
  final bool showConnections;
  final Future<void> Function(CanvasLayout layout) onLayoutChanged;
  final Future<void> Function(String sourceId, String targetId) onDropRequested;
  final Future<void> Function(WorkItem item) onEdit;
  final Future<void> Function(WorkItem item) onDelete;
  final Future<void> Function(WorkItem parent) onAddChild;
  final Future<void> Function(WorkItem item, int done)? onChecklistChanged;
  final Future<void> Function(String sourceId)? onMakeRoot;
  final Future<void> Function(WorkItem item)? onFocus;
  final Future<void> Function(WorkItem item)? onItemChanged;
  final Map<String, String> textColorOverrides;
  final Future<void> Function(String itemId, String? colorHex)?
  onTextColorChanged;

  @override
  State<CanvasWorkspace> createState() => _CanvasWorkspaceState();
}

class _CanvasWorkspaceState extends State<CanvasWorkspace> {
  static const Size _worldSize = Size(5200, 3600);
  final TransformationController _transformationController =
      TransformationController();
  late Map<String, CanvasLayout> _working;
  bool _manipulatingNode = false;
  bool _middleMousePanning = false;

  @override
  void initState() {
    super.initState();
    _working = Map<String, CanvasLayout>.from(widget.layouts);
  }

  @override
  void didUpdateWidget(covariant CanvasWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = Map<String, CanvasLayout>.from(_working);
    for (final entry in widget.layouts.entries) {
      final local = next[entry.key];
      if (local == null || entry.value.updatedAt.isAfter(local.updatedAt)) {
        next[entry.key] = entry.value;
      }
    }
    next.removeWhere((id, _) => !widget.items.any((item) => item.id == id));
    _working = next;
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final itemById = {for (final item in widget.items) item.id: item};
    final rects = <String, Rect>{};
    for (final item in widget.items) {
      final layout = _working[item.id] ?? widget.layouts[item.id];
      if (layout != null) {
        rects[item.id] = Rect.fromLTWH(
          layout.x,
          layout.y,
          layout.width,
          layout.height,
        );
      }
    }
    final parentByChild = {
      for (final item in widget.items) item.id: item.parentId,
    };

    return MouseRegion(
      cursor: _middleMousePanning ? SystemMouseCursors.move : MouseCursor.defer,
      child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(
        color: scheme.surfaceContainerLowest,
        child: Stack(
          children: [
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerSignal: _handlePointerSignal,
              onPointerDown: _handlePointerDown,
              onPointerMove: _handlePointerMove,
              onPointerUp: _handlePointerUp,
              onPointerCancel: _handlePointerCancel,
              child: InteractiveViewer(
                transformationController: _transformationController,
                constrained: false,
                panEnabled: !_manipulatingNode && !_middleMousePanning,
                scaleEnabled: !_manipulatingNode,
                trackpadScrollCausesScale: false,
                minScale: 0.2,
                maxScale: 3.2,
                boundaryMargin: const EdgeInsets.all(1200),
                child: SizedBox(
                width: _worldSize.width,
                height: _worldSize.height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: DotGridPainter(
                            color: scheme.outlineVariant.withValues(
                              alpha: 0.65,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.showConnections)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: ConnectionPainter(
                              rects: rects,
                              parentByChild: parentByChild,
                              color: scheme.primary.withValues(alpha: 0.48),
                            ),
                          ),
                        ),
                      ),
                    if (widget.onMakeRoot != null)
                      Positioned(
                        left: 24,
                        top: 24,
                        child: DragTarget<String>(
                          onWillAcceptWithDetails: (details) => true,
                          onAcceptWithDetails: (details) =>
                              widget.onMakeRoot!(details.data),
                          builder: (context, candidates, rejected) =>
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 210,
                                height: 56,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: candidates.isNotEmpty
                                      ? scheme.primaryContainer
                                      : scheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: candidates.isNotEmpty
                                        ? scheme.primary
                                        : scheme.outlineVariant,
                                  ),
                                ),
                                child: const Text('Drop here to make a Goal'),
                              ),
                        ),
                      ),
                    for (final item in widget.items)
                      _buildNode(context, item, itemById),
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _zoom(0.82),
                        icon: const Icon(Icons.remove),
                      ),
                      IconButton(
                        onPressed: () => _transformationController.value =
                            Matrix4.identity(),
                        icon: const Icon(Icons.center_focus_strong),
                      ),
                      IconButton(
                        onPressed: () => _zoom(1.2),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildNode(
    BuildContext context,
    WorkItem item,
    Map<String, WorkItem> itemById,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final layout = _working[item.id] ?? widget.layouts[item.id];
    if (layout == null) return const SizedBox.shrink();
    final color = _parseHex(layout.colorHex) ?? _typeColor(item.type, scheme);
    final requestedTextColor = widget.viewKind == CanvasViewKind.mindMap
        ? widget.textColorOverrides[item.id]
        : item.textColorHex;
    final foreground =
        _parseHex(requestedTextColor) ??
        (ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black87);

    return Positioned(
      left: layout.x,
      top: layout.y,
      width: layout.width,
      height: layout.height,
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) => details.data != item.id,
        onAcceptWithDetails: (details) =>
            widget.onDropRequested(details.data, item.id),
        builder: (context, candidates, rejected) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.08),
                  blurRadius: candidates.isNotEmpty ? 20 : 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Color.alphaBlend(
                color.withValues(alpha: 0.22),
                scheme.surface,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: candidates.isNotEmpty ? scheme.primary : color,
                  width: candidates.isNotEmpty ? 3 : 1.4,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context, item, layout, color, foreground),
                      Expanded(
                        child: widget.viewKind == CanvasViewKind.mindMap
                            ? _buildMindMapBody(context, item, foreground)
                            : _buildBigPictureBody(
                                context,
                                item,
                                itemById,
                                foreground,
                              ),
                      ),
                    ],
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeDownRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (_) =>
                            setState(() => _manipulatingNode = true),
                        onPanUpdate: (details) {
                          final current = _working[item.id] ?? layout;
                          final next = current.copyWith(
                            width: current.width + details.delta.dx,
                            height: current.height + details.delta.dy,
                          );
                          setState(() => _working[item.id] = next);
                        },
                        onPanEnd: (_) {
                          final current = _working[item.id]!;
                          final snapped = current.copyWith(
                            width: (current.width / 10).round() * 10.0,
                            height: (current.height / 10).round() * 10.0,
                          );
                          setState(() {
                            _working[item.id] = snapped;
                            _manipulatingNode = false;
                          });
                          widget.onLayoutChanged(snapped);
                        },
                        onPanCancel: () =>
                            setState(() => _manipulatingNode = false),
                        child: const SizedBox(
                          width: 28,
                          height: 28,
                          child: Align(
                            alignment: Alignment.bottomRight,
                            child: Icon(Icons.drag_handle, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WorkItem item,
    CanvasLayout layout,
    Color color,
    Color foreground,
  ) {
    final compact = widget.viewKind == CanvasViewKind.mindMap;
    final header = SizedBox(
      height: compact ? 16 : 42,
      child: ColoredBox(
        color: color.withValues(alpha: compact ? 0.20 : 0.38),
        child: Padding(
          padding: compact
              ? const EdgeInsets.fromLTRB(7, 0, 1, 0)
              : const EdgeInsets.fromLTRB(12, 5, 6, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.type.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foreground.withValues(alpha: .82),
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 6.5 : null,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Draggable<String>(
                data: item.id,
                feedback: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 220,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(item.title, maxLines: 2),
                    ),
                  ),
                ),
                childWhenDragging: const Icon(
                  Icons.account_tree_outlined,
                  size: 20,
                ),
                child: Semantics(
                  label: 'Drag to reorder or change parent',
                  button: true,
                  child: Icon(
                    Icons.account_tree_outlined,
                    size: compact ? 10 : 20,
                    color: foreground,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(
                  width: compact ? 17 : 34,
                  height: compact ? 15 : 32,
                ),
                onPressed: () {
                  final next = layout.copyWith(collapsed: !layout.collapsed);
                  setState(() => _working[item.id] = next);
                  widget.onLayoutChanged(next);
                },
                icon: Icon(
                  layout.collapsed ? Icons.unfold_more : Icons.unfold_less,
                  size: compact ? 10 : 20,
                ),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: compact ? 11 : 22,
                onSelected: (action) async {
                  switch (action) {
                    case 'focus':
                      await widget.onFocus?.call(item);
                      break;
                    case 'edit':
                      await widget.onEdit(item);
                      break;
                    case 'add':
                      await widget.onAddChild(item);
                      break;
                    case 'lock':
                      final next = layout.copyWith(locked: !layout.locked);
                      setState(() => _working[item.id] = next);
                      await widget.onLayoutChanged(next);
                      break;
                    case 'color':
                      final selected = await _chooseColor(
                        context,
                        layout.colorHex,
                        title: 'Card color',
                      );
                      if (selected != null) {
                        final next = layout.copyWith(colorHex: selected);
                        setState(() => _working[item.id] = next);
                        await widget.onLayoutChanged(next);
                      }
                      break;
                    case 'unarchive':
                      if (widget.onItemChanged != null) {
                        await widget.onItemChanged!(
                          item.copyWith(
                            status: WorkStatus.completed,
                            gtdStatus: GtdStatus.completed,
                          ),
                        );
                      }
                      break;
                    case 'textColor':
                      final current = widget.viewKind == CanvasViewKind.mindMap
                          ? widget.textColorOverrides[item.id]
                          : item.textColorHex;
                      final selected = await _chooseColor(
                        context,
                        current,
                        title: 'Card text color',
                        includeAutomatic: true,
                      );
                      if (selected != null) {
                        if (widget.viewKind == CanvasViewKind.mindMap &&
                            widget.onTextColorChanged != null) {
                          await widget.onTextColorChanged!(
                            item.id,
                            selected.isEmpty ? null : selected,
                          );
                        } else if (widget.onItemChanged != null) {
                          await widget.onItemChanged!(
                            item.copyWith(
                              textColorHex: selected.isEmpty ? null : selected,
                            ),
                          );
                        }
                      }
                      break;
                    case 'delete':
                      await widget.onDelete(item);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (widget.onFocus != null)
                    const PopupMenuItem(
                      value: 'focus',
                      child: Text('Quick focus'),
                    ),
                  const PopupMenuItem(value: 'edit', child: Text('Edit item')),
                  const PopupMenuItem(value: 'add', child: Text('Add child')),
                  PopupMenuItem(
                    value: 'lock',
                    child: Text(
                      layout.locked ? 'Unlock position' : 'Lock position',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'color',
                    child: Text('Change card color'),
                  ),
                  if (widget.onItemChanged != null ||
                      widget.onTextColorChanged != null)
                    const PopupMenuItem(
                      value: 'textColor',
                      child: Text('Change text color'),
                    ),
                  if (item.isArchived && widget.onItemChanged != null)
                    const PopupMenuItem(
                      value: 'unarchive',
                      child: Text('Unarchive item'),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete item'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (!widget.freeMove || layout.locked) return header;
    return MouseRegion(
      cursor: SystemMouseCursors.move,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => setState(() => _manipulatingNode = true),
        onPanUpdate: (details) {
          final current = _working[item.id] ?? layout;
          final next = current.copyWith(
            x: (current.x + details.delta.dx)
                .clamp(0, _worldSize.width - current.width)
                .toDouble(),
            y: (current.y + details.delta.dy)
                .clamp(0, _worldSize.height - current.height)
                .toDouble(),
          );
          setState(() => _working[item.id] = next);
        },
        onPanEnd: (_) {
          final current = _working[item.id]!;
          final snapped = current.copyWith(
            x: (current.x / 10).round() * 10.0,
            y: (current.y / 10).round() * 10.0,
          );
          setState(() {
            _working[item.id] = snapped;
            _manipulatingNode = false;
          });
          widget.onLayoutChanged(snapped);
        },
        onPanCancel: () => setState(() => _manipulatingNode = false),
        child: header,
      ),
    );
  }

  Widget _buildMindMapBody(
    BuildContext context,
    WorkItem item,
    Color foreground,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = (constraints.maxWidth - 24).clamp(40.0, 900.0);
        final availableHeight = (constraints.maxHeight - 16).clamp(28.0, 700.0);
        final lengthFactor = (item.title.length / 26).clamp(1.0, 5.0);
        final preferred = (24 / (1 + (lengthFactor - 1) * 0.22)).clamp(
          11.0,
          24.0,
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 28, 10),
          child: Center(
            child: SizedBox(
              width: availableWidth,
              height: availableHeight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: availableWidth),
                  child: Text(
                    item.title,
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: TextStyle(
                      color: foreground,
                      fontSize: preferred,
                      fontWeight: FontWeight.w800,
                      height: 1.08,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBigPictureBody(
    BuildContext context,
    WorkItem item,
    Map<String, WorkItem> itemById,
    Color foreground,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final parent = item.parentId == null ? null : itemById[item.parentId];

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final compact = height < 96;
        final medium = height >= 96 && height < 150;
        final showParent = parent != null && height >= 112;
        final showMeta = height >= 72;
        final showChecklist = item.checklistTotal > 0 && height >= 170;
        final verticalPadding = compact ? 6.0 : 10.0;
        final titleLines = compact ? 2 : (medium ? 3 : 5);

        return Padding(
          padding: EdgeInsets.fromLTRB(
            14,
            verticalPadding,
            30,
            verticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    item.title,
                    maxLines: titleLines,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                      height: 1.12,
                      decoration: item.isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                ),
              ),
              if (showParent) ...[
                const SizedBox(height: 3),
                Text(
                  'Under ${parent.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: foreground.withValues(alpha: .75),
                  ),
                ),
              ],
              if (showMeta) ...[
                if (!compact && !showChecklist) const Spacer(),
                _buildBigPictureMeta(context, item, scheme),
              ],
              if (showChecklist) ...[
                const SizedBox(height: 8),
                Expanded(child: _buildChecklistPreview(context, item)),
              ],
            ],
          ),
        );
      },
    );
  }


  Widget _buildBigPictureMeta(
    BuildContext context,
    WorkItem item,
    ColorScheme scheme,
  ) {
    final statusColor = switch (item.status) {
      WorkStatus.active => scheme.primary,
      WorkStatus.completed => Colors.green.shade700,
      WorkStatus.archived => scheme.outline,
    };
    final chips = <Widget>[
      _statusPill(
        context,
        item.priority.name.toUpperCase(),
        _priorityColor(item.priority, scheme),
      ),
      const SizedBox(width: 5),
      _statusPill(context, item.status.name.toUpperCase(), statusColor),
      if (item.urgent) ...[
        const SizedBox(width: 5),
        _statusPill(context, 'URGENT', scheme.error),
      ],
      if (item.energyLevel != EnergyLevel.none) ...[
        const SizedBox(width: 5),
        _statusPill(
          context,
          '${item.energyLevel.name.toUpperCase()} ENERGY',
          item.energyLevel == EnergyLevel.high
              ? const Color(0xFFEF6C00)
              : const Color(0xFF0288D1),
        ),
      ],
      if (item.dueDate != null) ...[
        const SizedBox(width: 5),
        _statusPill(
          context,
          'DUE ${MaterialLocalizations.of(context).formatShortDate(item.dueDate!.toLocal())}',
          scheme.tertiary,
        ),
      ],
      if (item.checklistTotal > 0) ...[
        const SizedBox(width: 5),
        _statusPill(
          context,
          '${item.checklistDone}/${item.checklistTotal} • ${(item.progress * 100).round()}%',
          scheme.secondary,
        ),
      ],
    ];
    return SizedBox(
      height: 25,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: chips),
      ),
    );
  }

  Widget _buildChecklistPreview(BuildContext context, WorkItem item) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        const boxExtent = 22.0;
        final columns = (constraints.maxWidth / boxExtent)
            .floor()
            .clamp(1, 50)
            .toInt();
        final rows = ((constraints.maxHeight - 34) / boxExtent)
            .floor()
            .clamp(1, 20)
            .toInt();
        final visibleCount = (columns * rows)
            .clamp(1, item.checklistTotal)
            .toInt();
        final hiddenCount = item.checklistTotal - visibleCount;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      ...List.generate(visibleCount, (index) {
                        final checked = index < item.checklistDone;
                        return InkWell(
                          borderRadius: BorderRadius.circular(5),
                          onTap: widget.onChecklistChanged == null
                              ? null
                              : () => widget.onChecklistChanged!(
                                  item,
                                  checked ? index : index + 1,
                                ),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: checked
                                  ? Colors.green
                                  : scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: checked
                                    ? Colors.green
                                    : scheme.outlineVariant,
                              ),
                            ),
                            child: checked
                                ? const Icon(
                                    Icons.check,
                                    size: 13,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        );
                      }),
                      if (hiddenCount > 0)
                        SizedBox(
                          height: 18,
                          child: Center(
                            child: Text(
                              '+$hiddenCount',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            LinearProgressIndicator(value: item.progress),
            const SizedBox(height: 3),
            Text(
              '${item.checklistDone} completed • ${item.checklistLeft} left • ${(item.progress * 100).round()}%',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        );
      },
    );
  }

  Widget _statusPill(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<String?> _chooseColor(
    BuildContext context,
    String? current, {
    required String title,
    bool includeAutomatic = true,
  }) async {
    const palette = <String>[
      '#6750A4',
      '#1565C0',
      '#00897B',
      '#2E7D32',
      '#EF6C00',
      '#C62828',
      '#6D4C41',
      '#455A64',
      '#AD1457',
      '#5E35B1',
      '#FFFFFF',
      '#000000',
    ];
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: palette.map((hex) {
            final color = _parseHex(hex)!;
            final selected = current?.toUpperCase() == hex;
            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => Navigator.pop(dialogContext, hex),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
        actions: [
          if (includeAutomatic)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, ''),
              child: const Text('Automatic'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
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
        final factor = scroll.scrollDelta.dy > 0 ? 0.90 : 1.10;
        _zoom(factor);
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
    final current = _transformationController.value;
    final scale = current.getMaxScaleOnAxis().clamp(0.2, 3.2).toDouble();
    _transformationController.value = current.clone()
      ..translateByDouble(screenDx / scale, screenDy / scale, 0, 1);
  }

  void _zoom(double factor) {
    final current = _transformationController.value;
    final scale = current.getMaxScaleOnAxis().clamp(0.2, 3.2).toDouble();
    final target = (scale * factor).clamp(0.2, 3.2).toDouble();
    final ratio = target / scale;
    _transformationController.value = current.clone()
      ..scaleByDouble(ratio, ratio, ratio, 1.0);
  }

  Color _typeColor(WorkItemType type, ColorScheme scheme) {
    return switch (type) {
      WorkItemType.goal => scheme.primary,
      WorkItemType.milestone => scheme.tertiary,
      WorkItemType.project => scheme.secondary,
      WorkItemType.subproject => const Color(0xFF4E7D6A),
      WorkItemType.module => const Color(0xFF7B61A8),
      WorkItemType.task => const Color(0xFF5D6B7A),
    };
  }

  Color _priorityColor(PriorityLevel priority, ColorScheme scheme) {
    return switch (priority) {
      PriorityLevel.normal => scheme.secondary,
      PriorityLevel.important => const Color(0xFFB36B00),
      PriorityLevel.urgent => scheme.error,
    };
  }

  Color? _parseHex(String? value) {
    if (value == null) return null;
    final normalized = value.replaceAll('#', '');
    if (normalized.length != 6) return null;
    final parsed = int.tryParse(normalized, radix: 16);
    return parsed == null ? null : Color(0xFF000000 | parsed);
  }
}
