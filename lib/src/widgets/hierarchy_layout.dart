import '../models/models.dart';

Map<String, CanvasLayout> buildAutomaticHierarchyLayout({
  required List<WorkItem> items,
  required Map<String, CanvasLayout> existing,
  required CanvasViewKind viewKind,
  required DeviceClass deviceClass,
}) {
  final byParent = <String?, List<WorkItem>>{};
  for (final item in items) {
    byParent.putIfAbsent(item.parentId, () => <WorkItem>[]).add(item);
  }
  for (final siblings in byParent.values) {
    siblings.sort((a, b) => a.sortKey.compareTo(b.sortKey));
  }

  final result = <String, CanvasLayout>{};
  var cursorX = deviceClass == DeviceClass.mobile ? 120.0 : 260.0;
  final horizontalGap = deviceClass == DeviceClass.mobile ? 42.0 : 90.0;
  final verticalGap = viewKind == CanvasViewKind.mindMap ? 190.0 : 235.0;

  double place(WorkItem item, int depth) {
    final base = existing[item.id];
    if (base == null) return cursorX;
    final children = byParent[item.id] ?? const <WorkItem>[];
    double centerX;
    if (children.isEmpty || base.collapsed) {
      centerX = cursorX + base.width / 2;
      cursorX += base.width + horizontalGap;
    } else {
      final childCenters = <double>[];
      for (final child in children) {
        childCenters.add(place(child, depth + 1));
      }
      centerX = (childCenters.first + childCenters.last) / 2;
    }
    final x = (centerX - base.width / 2).clamp(20, 5000 - base.width).toDouble();
    final y = 120 + depth * verticalGap;
    result[item.id] = base.copyWith(x: x, y: y);
    return centerX;
  }

  final roots = byParent[null] ?? const <WorkItem>[];
  for (final root in roots) {
    place(root, 0);
    cursorX += horizontalGap * 0.8;
  }
  return result;
}

List<WorkItem> visibleHierarchyItems({
  required List<WorkItem> items,
  required Map<String, CanvasLayout> layouts,
}) {
  final byParent = <String?, List<WorkItem>>{};
  for (final item in items.where((item) => !item.isDeleted)) {
    byParent.putIfAbsent(item.parentId, () => <WorkItem>[]).add(item);
  }
  for (final siblings in byParent.values) {
    siblings.sort((a, b) => a.sortKey.compareTo(b.sortKey));
  }
  final result = <WorkItem>[];
  void walk(WorkItem item) {
    result.add(item);
    if (layouts[item.id]?.collapsed == true) return;
    for (final child in byParent[item.id] ?? const <WorkItem>[]) {
      walk(child);
    }
  }

  for (final root in byParent[null] ?? const <WorkItem>[]) {
    walk(root);
  }
  return result;
}
