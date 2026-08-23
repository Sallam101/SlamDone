import 'package:slamdone/src/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checklist progress clamps to two hundred units', () {
    final now = DateTime.utc(2026, 8, 1);
    final item = WorkItem(
      id: 'item',
      title: 'Study',
      type: WorkItemType.task,
      sortKey: 1000,
      checklistTotal: 250,
      checklistDone: 225,
      createdAt: now,
      updatedAt: now,
      revision: 1,
      deviceId: 'device',
    ).copyWith(checklistTotal: 250, checklistDone: 225);

    expect(item.checklistTotal, 200);
    expect(item.checklistDone, 200);
    expect(item.checklistLeft, 0);
    expect(item.progress, 1);
  });

  test('timer state accepts a deliberately unlinked session', () {
    final state = TimerStateRecord.idle().copyWith(
      mode: TimerMode.general,
      workItemId: null,
      title: 'General focus',
    );
    expect(state.workItemId, isNull);
    expect(state.mode, TimerMode.general);
  });

  test(
    'work item round trip keeps layout, energy, and recurrence settings',
    () {
      final now = DateTime.utc(2026, 8, 2);
      final source = WorkItem(
        id: 'recurring',
        title: 'Daily review',
        type: WorkItemType.task,
        sortKey: 1000,
        recurring: true,
        recurrenceDays: 3,
        energyLevel: EnergyLevel.low,
        childColumns: 7,
        createdAt: now,
        updatedAt: now,
        revision: 1,
        deviceId: 'device',
      );
      final restored = WorkItem.fromMap(source.toMap());
      expect(restored.recurring, isTrue);
      expect(restored.recurrenceDays, 3);
      expect(restored.energyLevel, EnergyLevel.low);
      expect(restored.childColumns, 7);
    },
  );

  test('NorthStar archive state survives a map round trip', () {
    final now = DateTime.utc(2026, 8, 2);
    final source = NorthStarNote(
      id: 'note',
      title: 'Rule',
      body: 'Body',
      sortKey: 1,
      archived: true,
      createdAt: now,
      updatedAt: now,
      revision: 1,
      deviceId: 'device',
    );
    expect(NorthStarNote.fromMap(source.toMap()).archived, isTrue);
  });
}
