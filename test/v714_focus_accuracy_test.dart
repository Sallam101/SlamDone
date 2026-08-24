import 'package:flutter_test/flutter_test.dart';
import 'package:slamdone/src/database/local_database.dart';
import 'package:slamdone/src/models/models.dart';
import 'package:slamdone/src/repositories/app_repository.dart';
import 'package:slamdone/src/services/timer_engine.dart';
import 'package:slamdone/src/utils/work_item_filters.dart';

class _FakeDatabase extends LocalDatabase {
  final Map<String, String> settings = <String, String>{};
  final Map<String, TimeSession> sessionRows = <String, TimeSession>{};
  TimerStateRecord timerState = TimerStateRecord.idle();
  int timerStateSaves = 0;

  @override
  Future<String?> getSetting(String key) async => settings[key];

  @override
  Future<void> setSetting(
    String key,
    String value, {
    bool enqueue = true,
  }) async {
    settings[key] = value;
  }

  @override
  Future<void> saveTimeSession(
    TimeSession session, {
    bool enqueue = true,
  }) async {
    sessionRows[session.id] = session;
  }

  @override
  Future<TimeSession?> getTimeSession(String id) async => sessionRows[id];

  @override
  Future<List<TimeSession>> loadTimeSessions({int? limit}) async {
    final rows = sessionRows.values
        .where((session) => session.deletedAt == null)
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    if (limit == null || rows.length <= limit) return rows;
    return rows.take(limit).toList(growable: false);
  }

  @override
  Future<TimerStateRecord> loadTimerState() async => timerState;

  @override
  Future<void> saveTimerState(
    TimerStateRecord state, {
    bool enqueue = true,
  }) async {
    timerState = state;
    timerStateSaves += 1;
  }
}

void main() {
  test('shared uncategorized predicate matches only root Uncategorized tasks', () {
    final now = DateTime.utc(2026, 8, 24);
    WorkItem item({
      required String id,
      required WorkItemType type,
      String? parentId,
      String folder = '',
    }) => WorkItem(
      id: id,
      title: id,
      type: type,
      parentId: parentId,
      folder: folder,
      sortKey: 1000,
      createdAt: now,
      updatedAt: now,
      revision: 1,
      deviceId: 'device',
    );

    expect(
      isUncategorizedTask(
        item(id: 'root-task', type: WorkItemType.task, folder: 'Uncategorized'),
      ),
      isTrue,
    );
    expect(
      isUncategorizedTask(
        item(id: 'blank-folder', type: WorkItemType.task, folder: '  '),
      ),
      isTrue,
    );
    expect(
      isUncategorizedTask(
        item(
          id: 'child-task',
          type: WorkItemType.task,
          parentId: 'project',
          folder: 'Uncategorized',
        ),
      ),
      isFalse,
    );
    expect(
      isUncategorizedTask(
        item(id: 'project', type: WorkItemType.project, folder: 'Uncategorized'),
      ),
      isFalse,
    );
  });

  test('manual focus session can be soft-deleted and restored exactly', () async {
    final database = _FakeDatabase();
    final repository = AppRepository(database);
    await repository.initialize();
    final instant = DateTime.utc(2026, 8, 24, 15, 30);

    final created = await repository.createManualFocusSession(
      minutes: 25,
      now: instant,
    );

    expect(created.mode, TimerMode.general);
    expect(created.completed, isTrue);
    expect(created.plannedSeconds, 1500);
    expect(created.elapsedSeconds, 1500);
    expect(created.startedAt, instant);
    expect(created.endedAt, instant);
    expect(created.notes, contains('[slamdone:manual-focus]'));
    expect((await database.loadTimeSessions()).single.id, created.id);

    final deleted = await repository.softDeleteTimeSession(created.id);
    expect(deleted, isNotNull);
    final deletedSession = deleted!;
    expect(deletedSession.elapsedSeconds, 1500);
    expect(deletedSession.deletedAt, isNotNull);
    expect(deletedSession.revision, created.revision + 1);
    expect(await database.loadTimeSessions(), isEmpty);

    final restored = await repository.restoreTimeSession(created.id);
    expect(restored, isNotNull);
    final restoredSession = restored!;
    expect(restoredSession.deletedAt, isNull);
    expect(restoredSession.elapsedSeconds, 1500);
    expect(restoredSession.revision, deletedSession.revision + 1);
    expect((await database.loadTimeSessions()).single.id, created.id);
  });

  test('persisted running timer reopens paused without wall-clock catch-up', () async {
    final database = _FakeDatabase();
    final repository = AppRepository(database);
    await repository.initialize();
    final now = DateTime.now().toUtc();
    database.timerState = TimerStateRecord(
      mode: TimerMode.general,
      owner: TimerOwner.main,
      title: 'Focus',
      durationSeconds: 1500,
      remainingSeconds: 1200,
      elapsedSeconds: 300,
      running: true,
      paused: false,
      autoRepeat: true,
      startedAt: now.subtract(const Duration(minutes: 10)),
      endAt: now.add(const Duration(minutes: 15)),
      updatedAt: now.subtract(const Duration(minutes: 10)),
      completionToken: 'token',
    );

    final engine = TimerEngine(
      database: database,
      repository: repository,
      role: TimerOwner.main,
    );
    await engine.initialize();

    expect(engine.state.running, isFalse);
    expect(engine.state.paused, isTrue);
    expect(engine.state.remainingSeconds, 1200);
    expect(engine.state.elapsedSeconds, 300);
    expect(engine.state.startedAt, isNull);
    expect(engine.state.endAt, isNull);
    expect(database.timerStateSaves, 1);

    engine.dispose();
  });
}
