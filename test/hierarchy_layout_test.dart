import 'package:supeslam/src/models/models.dart';
import 'package:supeslam/src/widgets/hierarchy_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 1);

  WorkItem item(String id, WorkItemType type, {String? parentId, double order = 1000}) =>
      WorkItem(
        id: id,
        title: id,
        type: type,
        parentId: parentId,
        sortKey: order,
        createdAt: now,
        updatedAt: now,
        revision: 1,
        deviceId: 'device',
      );

  CanvasLayout layout(String id, {bool collapsed = false}) => CanvasLayout(
        id: '${id}_bigPicture_desktop',
        itemId: id,
        viewKind: CanvasViewKind.bigPicture,
        deviceClass: DeviceClass.desktop,
        x: 0,
        y: 0,
        width: 300,
        height: 150,
        collapsed: collapsed,
        updatedAt: now,
        revision: 1,
        deviceId: 'device',
      );

  test('auto layout places descendants below their parent', () {
    final items = [
      item('goal', WorkItemType.goal),
      item('project', WorkItemType.project, parentId: 'goal'),
      item('task', WorkItemType.task, parentId: 'project'),
    ];
    final result = buildAutomaticHierarchyLayout(
      items: items,
      existing: {for (final value in items) value.id: layout(value.id)},
      viewKind: CanvasViewKind.bigPicture,
      deviceClass: DeviceClass.desktop,
    );
    expect(result['project']!.y, greaterThan(result['goal']!.y));
    expect(result['task']!.y, greaterThan(result['project']!.y));
  });

  test('collapsed layout hides descendants from the visible list', () {
    final items = [
      item('goal', WorkItemType.goal),
      item('task', WorkItemType.task, parentId: 'goal'),
    ];
    final visible = visibleHierarchyItems(
      items: items,
      layouts: {'goal': layout('goal', collapsed: true), 'task': layout('task')},
    );
    expect(visible.map((value) => value.id), ['goal']);
  });
}
