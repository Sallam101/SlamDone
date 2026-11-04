import 'package:slamdone/src/models/models.dart';
import 'package:slamdone/src/utils/app_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('75-day focus streak survives Denver fall-back DST transition', () {
    final sessions = <TimeSession>[
      for (var offset = 0; offset < 75; offset++)
        TimeSession(
          id: 'session-$offset',
          mode: TimerMode.general,
          title: 'Focus',
          plannedSeconds: 1500,
          elapsedSeconds: 1500,
          startedAt: DateTime(2026, 11, 3 - offset, 12).toUtc(),
          endedAt: DateTime(2026, 11, 3 - offset, 12, 25).toUtc(),
          completed: true,
          createdAt: DateTime.utc(2026, 11, 3),
          updatedAt: DateTime.utc(2026, 11, 3),
          revision: 1,
          deviceId: 'test',
        ),
    ];
    expect(calculateFocusDayStreak(sessions, DateTime(2026, 11, 3, 12)), 75);
  });

  test('date-only habit keys remain on their local calendar date', () {
    final nov4 = parseDateKey('2026-11-04');
    expect(nov4, isNotNull);
    expect(dateKey(nov4!), '2026-11-04');
    expect(nov4.hour, 0);
    expect(parseDateKey('2026-02-30'), isNull);
    expect(parseDateKey('2026-11-04T00:00:00Z'), isNull);
  });

  test('focus streak counts permanent completed history and ignores stopwatches', () {
    final nov3 = DateTime(2026, 11, 3, 12).toUtc();
    final deleted = TimeSession(
      id: 'deleted',
      mode: TimerMode.focus,
      title: 'Deleted',
      plannedSeconds: 1500,
      elapsedSeconds: 1500,
      startedAt: nov3,
      endedAt: nov3.add(const Duration(minutes: 25)),
      completed: true,
      createdAt: nov3,
      updatedAt: nov3,
      revision: 1,
      deviceId: 'test',
      deletedAt: nov3,
    );
    final stopwatch = TimeSession(
      id: 'stopwatch',
      mode: TimerMode.stopwatch,
      title: 'Stopwatch',
      plannedSeconds: 0,
      elapsedSeconds: 1500,
      startedAt: nov3,
      endedAt: nov3.add(const Duration(minutes: 25)),
      completed: true,
      createdAt: nov3,
      updatedAt: nov3,
      revision: 1,
      deviceId: 'test',
    );
    expect(calculateFocusDayStreak([deleted, stopwatch], DateTime(2026, 11, 3, 18)), 1);
  });

  test('calendar day arithmetic preserves midnight through DST', () {
    final nov1 = DateTime(2026, 11, 1);
    final nov2 = addCalendarDays(nov1, 1);
    final nov3 = addCalendarDays(nov2, 1);
    expect(dateKey(nov2), '2026-11-02');
    expect(dateKey(nov3), '2026-11-03');
    expect(nov2.hour, 0);
    expect(nov3.hour, 0);
  });


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
