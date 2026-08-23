import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/app_controller.dart';
import '../models/models.dart';
import '../repositories/app_repository.dart';
import '../utils/app_utils.dart';
import 'focus_dialogs.dart';
import 'work_item_dialogs.dart';

const _structuredBranchGap = 10.0;

CanvasLayout _structuredLayoutFor(
  AppController controller,
  Map<String, CanvasLayout> layouts,
  WorkItem item,
) => layouts[item.id] ?? controller.layoutFor(item, CanvasViewKind.bigPicture);

double _structuredBranchWidth({
  required AppController controller,
  required WorkItem item,
  required Map<String?, List<WorkItem>> byParent,
  required Map<String, CanvasLayout> layouts,
  required double maxRowWidth,
  required double zoom,
  required Map<String, double> widthCache,
}) {
  final cached = widthCache[item.id];
  if (cached != null) return cached;
  final layout = _structuredLayoutFor(controller, layouts, item);
  final cardWidth = layout.width * zoom + 16;
  if (layout.collapsed) {
    widthCache[item.id] = cardWidth;
    return cardWidth;
  }
  final children = byParent[item.id] ?? const <WorkItem>[];
  if (children.isEmpty) {
    widthCache[item.id] = cardWidth;
    return cardWidth;
  }
  final rows = _structuredTieredChildRows(
    controller: controller,
    children: children,
    byParent: byParent,
    layouts: layouts,
    maxRowWidth: maxRowWidth,
    zoom: zoom,
    widthCache: widthCache,
    maxChildrenPerRow: item.childColumns,
  );
  var widestRow = 0.0;
  for (final row in rows) {
    final rowWidth = row.fold<double>(0, (sum, child) {
      final width = _structuredBranchWidth(
        controller: controller,
        item: child,
        byParent: byParent,
        layouts: layouts,
        maxRowWidth: maxRowWidth,
        zoom: zoom,
        widthCache: widthCache,
      );
      return sum == 0 ? width : sum + _structuredBranchGap + width;
    });
    widestRow = math.max(widestRow, rowWidth);
  }
  final result = math.max(cardWidth, widestRow).toDouble();
  widthCache[item.id] = result;
  return result;
}

List<List<WorkItem>> _structuredTieredChildRows({
  required AppController controller,
  required List<WorkItem> children,
  required Map<String?, List<WorkItem>> byParent,
  required Map<String, CanvasLayout> layouts,
  required double maxRowWidth,
  required double zoom,
  required Map<String, double> widthCache,
  required int maxChildrenPerRow,
}) {
  final groups = <WorkItemType, List<WorkItem>>{};
  for (final child in children) {
    groups.putIfAbsent(child.type, () => <WorkItem>[]).add(child);
  }
  final orderedTypes = groups.keys.toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  final rows = <List<WorkItem>>[];
  for (final type in orderedTypes) {
    var current = <WorkItem>[];
    var currentWidth = 0.0;
    for (final child in groups[type]!) {
      final width = _structuredBranchWidth(
        controller: controller,
        item: child,
        byParent: byParent,
        layouts: layouts,
        maxRowWidth: maxRowWidth,
        zoom: zoom,
        widthCache: widthCache,
      ).clamp(96.0, maxRowWidth).toDouble();
      final nextWidth = current.isEmpty
          ? width
          : currentWidth + _structuredBranchGap + width;
      if (current.isNotEmpty &&
          (current.length >= maxChildrenPerRow.clamp(1, 12) ||
              nextWidth > maxRowWidth)) {
        rows.add(current);
        current = <WorkItem>[];
        currentWidth = 0;
      }
      current.add(child);
      currentWidth = currentWidth == 0
          ? width
          : currentWidth + _structuredBranchGap + width;
    }
    if (current.isNotEmpty) rows.add(current);
  }
  return rows;
}

class StructuredHierarchyView extends StatefulWidget {
  const StructuredHierarchyView({
    super.key,
    required this.controller,
    required this.items,
    required this.layouts,
  });

  final AppController controller;
  final List<WorkItem> items;
  final Map<String, CanvasLayout> layouts;

  @override
  State<StructuredHierarchyView> createState() =>
      _StructuredHierarchyViewState();
}

class _StructuredHierarchyViewState extends State<StructuredHierarchyView> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  double _zoom = 1.0;
  bool _middleMousePanning = false;

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveItems = widget.items.where((item) => !item.isDeleted).toList();
    final visibleIds = liveItems.map((item) => item.id).toSet();
    final byParent = <String?, List<WorkItem>>{};
    for (final item in liveItems) {
      // A filtered item becomes a display root when its real parent is hidden.
      // This keeps the selected level first instead of forcing Goal ancestors.
      final displayParent =
          item.parentId != null && visibleIds.contains(item.parentId)
          ? item.parentId
          : null;
      byParent.putIfAbsent(displayParent, () => <WorkItem>[]).add(item);
    }
    for (final children in byParent.values) {
      children.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    }
    final roots = byParent[null] ?? const <WorkItem>[];

    return LayoutBuilder(
      builder: (context, viewport) {
        final levelRowWidth = math.max(720.0, viewport.maxWidth - 86);
        final branchWidthCache = <String, double>{};
        final rootWidths = roots
            .map(
              (root) => _structuredBranchWidth(
                controller: widget.controller,
                item: root,
                byParent: byParent,
                layouts: widget.layouts,
                maxRowWidth: levelRowWidth,
                zoom: _zoom,
                widthCache: branchWidthCache,
              ),
            )
            .toList();
        final rootsWidth = rootWidths.fold<double>(0, (sum, width) {
          return sum == 0 ? width : sum + 24 + width;
        });
        final contentWidth = math
            .max(viewport.maxWidth - 2, rootsWidth + 56)
            .toDouble();
        final content = SizedBox(
          width: contentWidth,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 34, 76),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < roots.length; index++) ...[
                  SizedBox(
                    width: rootWidths[index],
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _HierarchyBranch(
                        key: ValueKey('branch-${roots[index].id}'),
                        controller: widget.controller,
                        item: roots[index],
                        byParent: byParent,
                        layouts: widget.layouts,
                        maxRowWidth: levelRowWidth,
                        zoom: _zoom,
                        widthCache: branchWidthCache,
                      ),
                    ),
                  ),
                  if (index != roots.length - 1) const SizedBox(width: 24),
                ],
              ],
            ),
          ),
        );

        return MouseRegion(
          cursor: _middleMousePanning ? SystemMouseCursors.move : MouseCursor.defer,
          child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerSignal: _handlePointerSignal,
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerCancel,
          child: Stack(
            children: [
            Positioned.fill(
              child: Scrollbar(
                controller: _verticalController,
                thumbVisibility: true,
                trackVisibility: true,
                interactive: true,
                thickness: 12,
                scrollbarOrientation: ScrollbarOrientation.right,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.vertical,
                child: Scrollbar(
                  controller: _horizontalController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  interactive: true,
                  thickness: 12,
                  scrollbarOrientation: ScrollbarOrientation.bottom,
                  notificationPredicate: (notification) =>
                      notification.metrics.axis == Axis.horizontal,
                  child: SingleChildScrollView(
                    controller: _horizontalController,
                    primary: false,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: contentWidth,
                      height: viewport.maxHeight,
                      child: SingleChildScrollView(
                        controller: _verticalController,
                        primary: false,
                        child: content,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18,
              bottom: 24,
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
            Positioned(
              right: 24,
              bottom: 24,
              child: Card(
                elevation: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Zoom out',
                      onPressed: () => _changeZoom(-0.1),
                      icon: const Icon(Icons.remove),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _zoom = 1.0),
                      child: Text('${(_zoom * 100).round()}%'),
                    ),
                    IconButton(
                      tooltip: 'Zoom in',
                      onPressed: () => _changeZoom(0.1),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
            ),
            ],
          ),
          ),
        );
      },
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      final scroll = resolved as PointerScrollEvent;
      if (HardwareKeyboard.instance.isControlPressed) {
        _changeZoom(scroll.scrollDelta.dy > 0 ? -0.1 : 0.1);
      } else {
        _scrollBy(scroll.scrollDelta.dx, scroll.scrollDelta.dy);
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
      _scrollBy(-event.delta.dx, -event.delta.dy);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_middleMousePanning) setState(() => _middleMousePanning = false);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_middleMousePanning) setState(() => _middleMousePanning = false);
  }

  void _scrollBy(double dx, double dy) {
    if (_horizontalController.hasClients && dx != 0) {
      final position = _horizontalController.position;
      _horizontalController.jumpTo(
        (_horizontalController.offset + dx)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
      );
    }
    if (_verticalController.hasClients && dy != 0) {
      final position = _verticalController.position;
      _verticalController.jumpTo(
        (_verticalController.offset + dy)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
      );
    }
  }

  void _changeZoom(double delta) {
    setState(() {
      _zoom = (_zoom + delta).clamp(0.5, 1.8).toDouble();
    });
  }
}

class _HierarchyBranch extends StatelessWidget {
  const _HierarchyBranch({
    super.key,
    required this.controller,
    required this.item,
    required this.byParent,
    required this.layouts,
    required this.maxRowWidth,
    required this.zoom,
    required this.widthCache,
  });

  final AppController controller;
  final WorkItem item;
  final Map<String?, List<WorkItem>> byParent;
  final Map<String, CanvasLayout> layouts;
  final double maxRowWidth;
  final double zoom;
  final Map<String, double> widthCache;

  @override
  Widget build(BuildContext context) {
    final layout =
        layouts[item.id] ??
        controller.layoutFor(item, CanvasViewKind.bigPicture);
    final children = layout.collapsed
        ? const <WorkItem>[]
        : byParent[item.id] ?? const <WorkItem>[];
    final childRows = _structuredTieredChildRows(
      controller: controller,
      children: children,
      byParent: byParent,
      layouts: layouts,
      maxRowWidth: maxRowWidth,
      zoom: zoom,
      widthCache: widthCache,
      maxChildrenPerRow: item.childColumns,
    );
    final connectorColor = Theme.of(
      context,
    ).colorScheme.outline.withValues(alpha: .46);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _OrderDropZone(
              controller: controller,
              target: item,
              intent: DropIntent.before,
            ),
            _StructuredCard(
              key: ValueKey('structured-card-${item.id}'),
              controller: controller,
              item: item,
              layout: layout,
              zoom: zoom,
            ),
            _OrderDropZone(
              controller: controller,
              target: item,
              intent: DropIntent.after,
            ),
          ],
        ),
        if (childRows.isNotEmpty) ...[
          const SizedBox(height: 3),
          Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 0,
                bottom: 0,
                child: Container(width: 1.25, color: connectorColor),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < childRows.length; index++) ...[
                    if (index > 0) const SizedBox(height: 7),
                    _HierarchyChildRow(
                      controller: controller,
                      children: childRows[index],
                      byParent: byParent,
                      layouts: layouts,
                      maxRowWidth: maxRowWidth,
                      zoom: zoom,
                      widthCache: widthCache,
                      connectorColor: connectorColor,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _HierarchyChildRow extends StatelessWidget {
  const _HierarchyChildRow({
    required this.controller,
    required this.children,
    required this.byParent,
    required this.layouts,
    required this.maxRowWidth,
    required this.zoom,
    required this.connectorColor,
    required this.widthCache,
  });

  final AppController controller;
  final List<WorkItem> children;
  final Map<String?, List<WorkItem>> byParent;
  final Map<String, CanvasLayout> layouts;
  final double maxRowWidth;
  final double zoom;
  final Color connectorColor;
  final Map<String, double> widthCache;

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Stack(
        children: [
          Positioned(
            left: 4,
            right: 4,
            top: 10,
            child: Container(height: 1.25, color: connectorColor),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 1.25, height: 16, color: connectorColor),
                    _HierarchyBranch(
                      key: ValueKey('branch-${children[index].id}'),
                      controller: controller,
                      item: children[index],
                      byParent: byParent,
                      layouts: layouts,
                      maxRowWidth: maxRowWidth,
                      zoom: zoom,
                      widthCache: widthCache,
                    ),
                  ],
                ),
                if (index != children.length - 1)
                  const SizedBox(width: _structuredBranchGap),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _FittingCardText extends StatelessWidget {
  const _FittingCardText({
    required this.text,
    required this.maxLines,
    required this.maxFontSize,
    required this.minFontSize,
    required this.style,
  });

  final String text;
  final int maxLines;
  final double maxFontSize;
  final double minFontSize;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var size = maxFontSize;
        final direction = Directionality.of(context);
        final scaler = MediaQuery.textScalerOf(context);
        while (size > minFontSize) {
          final painter = TextPainter(
            text: TextSpan(
              text: text,
              style: style.copyWith(fontSize: size),
            ),
            maxLines: maxLines,
            textAlign: TextAlign.center,
            textDirection: direction,
            textScaler: scaler,
          )..layout(maxWidth: constraints.maxWidth);
          if (!painter.didExceedMaxLines &&
              painter.height <= constraints.maxHeight) {
            break;
          }
          size -= .75;
        }
        return Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
            style: style.copyWith(
              fontSize: size.clamp(minFontSize, maxFontSize).toDouble(),
            ),
          ),
        );
      },
    );
  }
}

class _OrderDropZone extends StatelessWidget {
  const _OrderDropZone({
    required this.controller,
    required this.target,
    required this.intent,
  });

  final AppController controller;
  final WorkItem target;
  final DropIntent intent;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != target.id,
      onAcceptWithDetails: (details) async {
        try {
          await controller.applyDrop(
            sourceId: details.data,
            targetId: target.id,
            intent: intent,
          );
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(error.toString())));
          }
        }
      },
      builder: (context, candidates, rejected) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: candidates.isEmpty ? 6 : 22,
        height: 96,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: candidates.isEmpty
              ? Colors.transparent
              : Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _StructuredCard extends StatefulWidget {
  const _StructuredCard({
    super.key,
    required this.controller,
    required this.item,
    required this.layout,
    required this.zoom,
  });

  final AppController controller;
  final WorkItem item;
  final CanvasLayout layout;
  final double zoom;

  @override
  State<_StructuredCard> createState() => _StructuredCardState();
}

class _StructuredCardState extends State<_StructuredCard> {
  late CanvasLayout _layout;

  @override
  void initState() {
    super.initState();
    _layout = widget.layout;
  }

  @override
  void didUpdateWidget(covariant _StructuredCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.layout.updatedAt.isAfter(_layout.updatedAt) ||
        widget.layout.width != _layout.width ||
        widget.layout.height != _layout.height ||
        widget.layout.collapsed != _layout.collapsed ||
        widget.layout.colorHex != _layout.colorHex) {
      _layout = widget.layout;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = _layout.width.clamp(180, 1100).toDouble();
    final effectiveHeight = _layout.height.clamp(104, 760).toDouble();
    final card = _buildCard(
      context,
      width: effectiveWidth,
      height: effectiveHeight,
      interactive: true,
    );

    // Moving is intentionally limited to the move handle in the card header.
    // This keeps normal clicks, checklist edits, and bottom-right resizing from
    // accidentally starting a hierarchy drag.
    return SizedBox(
      width: effectiveWidth * widget.zoom,
      height: effectiveHeight * widget.zoom,
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: effectiveWidth,
          height: effectiveHeight,
          child: card,
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required double width,
    required double height,
    required bool interactive,
  }) {
    final item = widget.item;
    final scheme = Theme.of(context).colorScheme;
    final baseColor = parseHexColor(_layout.colorHex) ?? _typeColor(item.type);
    final background = item.isCompleted
        ? Color.alphaBlend(Colors.grey.withValues(alpha: 0.42), baseColor)
        : baseColor;
    final foreground =
        parseHexColor(item.textColorHex) ?? readableTextColor(background);

    return DragTarget<String>(
      onWillAcceptWithDetails: interactive
          ? (details) {
              final source = widget.controller.itemById(details.data);
              return source != null &&
                  source.id != item.id &&
                  item.type.index < source.type.index;
            }
          : null,
      onAcceptWithDetails: interactive
          ? (details) async {
              try {
                await widget.controller.applyDrop(
                  sourceId: details.data,
                  targetId: item.id,
                  intent: DropIntent.makeChild,
                );
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              }
            }
          : null,
      builder: (context, candidates, rejected) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: candidates.isNotEmpty
                ? scheme.onPrimaryContainer
                : foreground,
            width: candidates.isNotEmpty ? 4 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(context, foreground, interactive),
                    const SizedBox(height: 3),
                    Expanded(
                      child: _buildAdaptiveBody(
                        context,
                        foreground,
                        availableHeight: height - 43,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (interactive)
              Positioned(
                right: 0,
                bottom: 0,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeDownRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) {
                      setState(() {
                        _layout = _layout.copyWith(
                          width:
                              (_layout.width + details.delta.dx / widget.zoom)
                                  .clamp(180, 1100)
                                  .toDouble(),
                          height:
                              (_layout.height + details.delta.dy / widget.zoom)
                                  .clamp(104, 760)
                                  .toDouble(),
                        );
                      });
                    },
                    onPanEnd: (_) => _saveLayout(_layout),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Icon(
                        Icons.zoom_out_map,
                        size: 16,
                        color: foreground.withValues(alpha: 0.82),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Color foreground,
    bool interactive,
  ) {
    final item = widget.item;
    return SizedBox(
      height: 28,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final showAdd = interactive && width >= 225;
          final showFocus = interactive && width >= 255;
          final showEdit = interactive && width >= 285;
          final showColor = interactive && width >= 325;
          final showDelete = interactive && width >= 365;
          final needsOverflow =
              interactive &&
              (item.isArchived ||
                  !showAdd ||
                  !showFocus ||
                  !showEdit ||
                  !showColor ||
                  !showDelete);

          return Row(
            children: [
              Expanded(
                child: Text(
                  item.type.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground.withValues(alpha: 0.78),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.05,
                  ),
                ),
              ),
              if (interactive) ...[
                const SizedBox(width: 2),
                _moveHandle(context, foreground),
                _iconButton(
                  tooltip: _layout.collapsed
                      ? 'Show descendants'
                      : 'Hide descendants',
                  icon: _layout.collapsed
                      ? Icons.unfold_more
                      : Icons.unfold_less,
                  color: foreground,
                  onPressed: () => _saveLayout(
                    _layout.copyWith(collapsed: !_layout.collapsed),
                  ),
                ),
                if (showAdd)
                  _iconButton(
                    tooltip: 'Add child',
                    icon: Icons.add_circle_outline,
                    color: foreground,
                    onPressed: () => showWorkItemEditor(
                      context,
                      widget.controller,
                      parent: item,
                    ),
                  ),
                if (showFocus)
                  _iconButton(
                    tooltip: 'Quick focus',
                    icon: Icons.timer_outlined,
                    color: foreground,
                    onPressed: () => showQuickFocusDialog(
                      context,
                      widget.controller,
                      item: item,
                    ),
                  ),
                if (showEdit)
                  _iconButton(
                    tooltip: 'Edit',
                    icon: Icons.edit_outlined,
                    color: foreground,
                    onPressed: () => showWorkItemEditor(
                      context,
                      widget.controller,
                      item: item,
                    ),
                  ),
                if (showColor)
                  _iconButton(
                    tooltip: 'Change color',
                    icon: Icons.palette_outlined,
                    color: foreground,
                    onPressed: _chooseColor,
                  ),
                if (showDelete)
                  _iconButton(
                    tooltip: 'Delete',
                    icon: Icons.delete_outline,
                    color: foreground,
                    onPressed: () => showDeleteWorkItemDialog(
                      context,
                      widget.controller,
                      item,
                    ),
                  ),
                if (needsOverflow)
                  _buildHeaderOverflowMenu(
                    context,
                    foreground,
                    showAdd: showAdd,
                    showFocus: showFocus,
                    showEdit: showEdit,
                    showColor: showColor,
                    showDelete: showDelete,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderOverflowMenu(
    BuildContext context,
    Color foreground, {
    required bool showAdd,
    required bool showFocus,
    required bool showEdit,
    required bool showColor,
    required bool showDelete,
  }) {
    final item = widget.item;
    final entries = <PopupMenuEntry<String>>[
      if (item.isArchived)
        const PopupMenuItem<String>(
          value: 'unarchive',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.unarchive_outlined),
            title: Text('Unarchive item'),
          ),
        ),
      if (item.isArchived) const PopupMenuDivider(),
      if (!showAdd)
        const PopupMenuItem<String>(
          value: 'add',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.add_circle_outline),
            title: Text('Add child'),
          ),
        ),
      if (!showFocus)
        const PopupMenuItem<String>(
          value: 'focus',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.timer_outlined),
            title: Text('Quick focus'),
          ),
        ),
      if (!showEdit)
        const PopupMenuItem<String>(
          value: 'edit',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit'),
          ),
        ),
      if (!showColor)
        const PopupMenuItem<String>(
          value: 'color',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.palette_outlined),
            title: Text('Change color'),
          ),
        ),
      const PopupMenuDivider(),
      const PopupMenuItem<String>(
        value: 'titleSmaller',
        child: ListTile(
          dense: true,
          leading: Icon(Icons.text_decrease),
          title: Text('Title smaller'),
        ),
      ),
      const PopupMenuItem<String>(
        value: 'titleLarger',
        child: ListTile(
          dense: true,
          leading: Icon(Icons.text_increase),
          title: Text('Title larger'),
        ),
      ),
      if (!showDelete)
        const PopupMenuItem<String>(
          value: 'delete',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.delete_outline),
            title: Text('Delete'),
          ),
        ),
    ];

    return SizedBox(
      width: 23,
      height: 23,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        tooltip: 'More card actions',
        itemBuilder: (context) => entries,
        child: Center(
          child: Icon(Icons.more_vert, size: 14, color: foreground),
        ),
        onSelected: (value) {
          switch (value) {
            case 'unarchive':
              widget.controller.unarchiveWorkItem(item);
              break;
            case 'add':
              showWorkItemEditor(context, widget.controller, parent: item);
              break;
            case 'focus':
              showQuickFocusDialog(context, widget.controller, item: item);
              break;
            case 'edit':
              showWorkItemEditor(context, widget.controller, item: item);
              break;
            case 'titleSmaller':
              widget.controller.updateWorkItem(
                item.copyWith(
                  titleScale: (item.titleScale - 0.1)
                      .clamp(0.75, 2.0)
                      .toDouble(),
                ),
              );
              break;
            case 'titleLarger':
              widget.controller.updateWorkItem(
                item.copyWith(
                  titleScale: (item.titleScale + 0.1)
                      .clamp(0.75, 2.0)
                      .toDouble(),
                ),
              );
              break;
            case 'color':
              _chooseColor();
              break;
            case 'delete':
              showDeleteWorkItemDialog(context, widget.controller, item);
              break;
          }
        },
      ),
    );
  }

  Widget _buildAdaptiveBody(
    BuildContext context,
    Color foreground, {
    required double availableHeight,
  }) {
    final item = widget.item;
    final hasChecklist = item.checklistTotal > 0;
    final compact = availableHeight < 90;
    final roomy = availableHeight >= 165;
    final veryRoomy = availableHeight >= 235;
    final titleFont = (18 * item.titleScale)
        .clamp(compact ? 10.5 : 12.0, 38.0)
        .toDouble();
    final titleLines = compact
        ? 2
        : availableHeight < 150
        ? 3
        : 5;
    final titleHeight = (availableHeight * (hasChecklist ? .32 : .62))
        .clamp(compact ? 28.0 : 38.0, veryRoomy ? 120.0 : 86.0)
        .toDouble();
    final showTags = availableHeight >= 75;
    final showNotes = item.notes.trim().isNotEmpty && veryRoomy;
    final showProgress = hasChecklist && availableHeight >= 102;
    final showChecklist = hasChecklist && availableHeight >= 122;

    final tagWidgets = <Widget>[
      _tag(item.priority.name.toUpperCase(), foreground),
      if (item.dueDate != null)
        _tag(
          MaterialLocalizations.of(
            context,
          ).formatShortDate(item.dueDate!.toLocal()),
          foreground,
        ),
      _tag(item.status.name.toUpperCase(), foreground),
      if (item.urgent) _tag('URGENT', foreground),
      if (item.recurring)
        _tag(
          item.recurrenceDays == 1
              ? 'DAILY'
              : 'EVERY ${item.recurrenceDays} DAYS',
          foreground,
        ),
      if (item.energyLevel != EnergyLevel.none) _energyTag(item.energyLevel),
    ];

    return ClipRect(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Title is always the first and most visible card element.
          SizedBox(
            height: titleHeight,
            child: _FittingCardText(
              text: item.title,
              maxLines: titleLines,
              maxFontSize: titleFont,
              minFontSize: compact ? 8.5 : 9.5,
              style: TextStyle(
                color: foreground,
                height: 1.08,
                fontWeight: item.titleBold ? FontWeight.w800 : FontWeight.w500,
                decoration: item.isCompleted
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
          ),
          if (showTags) ...[
            const SizedBox(height: 5),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 3,
              children: tagWidgets,
            ),
          ],
          if (showNotes) ...[
            const SizedBox(height: 5),
            Text(
              item.notes,
              maxLines: roomy ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: foreground.withValues(alpha: 0.78),
                fontSize: 9.5,
                height: 1.08,
              ),
            ),
          ],
          if (showChecklist) ...[
            const SizedBox(height: 6),
            Expanded(child: _buildMiniChecklist(context, item, foreground)),
          ] else
            const Spacer(),
          if (showProgress) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: item.progress,
              color: foreground,
              backgroundColor: foreground.withValues(alpha: 0.22),
            ),
            const SizedBox(height: 3),
            Text(
              '${item.checklistDone} done • ${item.checklistLeft} left • '
              '${(item.progress * 100).round()}%',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: foreground, fontSize: 9.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _energyTag(EnergyLevel energy) {
    final high = energy == EnergyLevel.high;
    final color = high ? const Color(0xFFFF8A00) : const Color(0xFF29B6F6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: .7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            high ? Icons.bolt : Icons.battery_saver,
            size: 10,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            high ? 'HIGH ENERGY' : 'LOW ENERGY',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 7.5,
              fontWeight: FontWeight.w900,
              letterSpacing: .25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChecklist(
    BuildContext context,
    WorkItem item,
    Color foreground,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const boxSize = 16.0;
        const gap = 3.0;
        final columns = ((constraints.maxWidth + gap) / (boxSize + gap))
            .floor()
            .clamp(1, 60)
            .toInt();
        final rows = (constraints.maxHeight / (boxSize + gap))
            .floor()
            .clamp(1, 12)
            .toInt();
        final capacity = (columns * rows).clamp(1, 200).toInt();
        final visible = capacity.clamp(1, item.checklistTotal).toInt();
        return ClipRect(
          child: Align(
            alignment: Alignment.center,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var index = 0; index < visible; index++)
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => widget.controller.updateChecklist(
                      item,
                      index < item.checklistDone ? index : index + 1,
                    ),
                    child: Container(
                      width: boxSize,
                      height: boxSize,
                      decoration: BoxDecoration(
                        color: index < item.checklistDone
                            ? Colors.green
                            : foreground.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: index < item.checklistDone
                              ? Colors.green.shade700
                              : foreground.withValues(alpha: 0.52),
                        ),
                      ),
                      child: index < item.checklistDone
                          ? const Icon(
                              Icons.check,
                              size: 11,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dragFeedback(BuildContext context, double width, double height) {
    final item = widget.item;
    final background = parseHexColor(_layout.colorHex) ?? _typeColor(item.type);
    final foreground =
        parseHexColor(item.textColorHex) ?? readableTextColor(background);
    return Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: 0.9,
        child: Container(
          width: width.clamp(180, 420).toDouble(),
          height: height.clamp(104, 220).toDouble(),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: foreground, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              item.title,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _moveHandle(BuildContext context, Color color) {
    final width = _layout.width.clamp(180, 420).toDouble();
    final height = _layout.height.clamp(104, 220).toDouble();
    return Draggable<String>(
      data: widget.item.id,
      feedback: _dragFeedback(context, width, height),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: Icon(Icons.open_with, size: 14, color: color),
      ),
      child: Semantics(
        label: 'Move or reparent',
        button: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.move,
          child: SizedBox(
            width: 23,
            height: 23,
            child: Icon(Icons.open_with, size: 14, color: color),
          ),
        ),
      ),
    );
  }

  Widget _iconButton({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      label: tooltip,
      button: true,
      child: SizedBox(
        width: 23,
        height: 23,
        child: IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onPressed: onPressed,
          icon: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }

  Widget _tag(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.45)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 7.5,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Future<void> _saveLayout(CanvasLayout layout) async {
    setState(() => _layout = layout);
    await widget.controller.saveLayout(layout);
  }

  Future<void> _chooseColor() async {
    final palette = <Color>[
      const Color(0xFF43A047),
      const Color(0xFF1E88E5),
      const Color(0xFF8E24AA),
      const Color(0xFFF4511E),
      const Color(0xFFFDD835),
      const Color(0xFF00897B),
      const Color(0xFF3949AB),
      const Color(0xFFD81B60),
      const Color(0xFF6D4C41),
      const Color(0xFF546E7A),
    ];
    final selected = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Card color'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final color in palette)
              InkWell(
                onTap: () => Navigator.pop(context, color),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await _saveLayout(_layout.copyWith(colorHex: toHexColor(selected)));
    }
  }

  Color _typeColor(WorkItemType type) => switch (type) {
    WorkItemType.goal => const Color(0xFF2E7D32),
    WorkItemType.milestone => const Color(0xFF1565C0),
    WorkItemType.project => const Color(0xFF6A1B9A),
    WorkItemType.subproject => const Color(0xFF00838F),
    WorkItemType.module => const Color(0xFFEF6C00),
    WorkItemType.task => const Color(0xFF455A64),
  };
}
