import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../database/local_database.dart';
import '../migration/migration_models.dart';
import '../models/models.dart';

enum DropIntent { before, makeChild, after, makeRoot }

class AppRepository {
  AppRepository(this.database);

  final LocalDatabase database;
  final Uuid _uuid = const Uuid();
  late final String deviceId;


  // Settings understood by the native Autivra4 V6 backup importer. Keep
  // browser/Firebase transport identity out of the reverse export so loading
  // the file into Autivra4 cannot replace that installation's Drive/device
  // configuration.
  static const Set<String> autivraCompatibleSettingKeys = {
    'accent_color',
    'background_color',
    'card_color',
    'daily_session_goal',
    'dashboard_palette',
    'do_first_importance',
    'do_first_level',
    'do_first_period',
    'do_first_status',
    'focus_panel_hidden',
    'font_family',
    'font_scale',
    'habit_name_width',
    'habit_row_heights_json',
    'habit_totals_bold',
    'journal_prompts_json',
    'mind_map_text_colors_json',
    'monthly_focus_days_goal',
    'monthly_session_goal',
    'northstar_body_scales_json',
    'northstar_title_scales_json',
    'points_goal',
    'points_milestone',
    'points_module',
    'points_per_focus_minute',
    'points_per_habit_checkin',
    'points_project',
    'points_subproject',
    'points_task',
    'tab_preferences_json',
    'tasks_descendants',
    'tasks_filter',
    'tasks_level',
    'text_color',
    'theme_mode',
    'weekly_focus_days_goal',
    'weekly_session_goal',
  };

  static const Set<String> autivraTransportSettingKeys = {
    'device_id',
    'drive_sync_folder',
    'sync_mode',
    'floating_timer_command',
    'floating_timer_heartbeat',
  };

  bool _isAutivraCompatibleSetting(String key) {
    if (autivraTransportSettingKeys.contains(key)) return false;
    if (autivraCompatibleSettingKeys.contains(key)) return true;
    return key.startsWith('study_table_') && key.endsWith('_display');
  }

  Future<void> initialize() async {
    deviceId = await database.getSetting('device_id') ?? _uuid.v4();
    await database.setSetting('device_id', deviceId);
    // SlamDone Web starts empty on a new browser so an Autivra4 migration
    // cannot be mixed with demo goals, default ranks, or sample study tables.
  }

  Future<List<WorkItem>> loadWorkItems() => database.loadWorkItems();
  Future<List<CanvasLayout>> loadLayouts(
    CanvasViewKind viewKind,
    DeviceClass deviceClass,
  ) => database.loadLayouts(viewKind: viewKind, deviceClass: deviceClass);
  Future<List<JournalEntry>> loadJournals() => database.loadJournalEntries();
  Future<List<TimeSession>> loadSessions() => database.loadTimeSessions();
  Future<List<Habit>> loadHabits() => database.loadHabits();
  Future<List<HabitEntry>> loadHabitEntries({String? monthPrefix}) =>
      database.loadHabitEntries(monthPrefix: monthPrefix);
  Future<List<NorthStarNote>> loadNorthStarNotes() =>
      database.loadNorthStarNotes();
  Future<List<RewardRank>> loadRewardRanks() => database.loadRewardRanks();
  Future<List<StudyTable>> loadStudyTables() => database.loadStudyTables();

  Future<Habit> createHabit({
    required String title,
    required HabitKind kind,
    required double monthGoal,
    String unit = '',
    String notes = '',
    String? colorHex,
    String? textColorHex,
  }) async {
    final existing = await database.loadHabits();
    final now = DateTime.now().toUtc();
    final habit = Habit(
      id: _uuid.v4(),
      title: title.trim().isEmpty ? 'Habit' : title.trim(),
      kind: kind,
      monthGoal: monthGoal,
      sortKey: existing.isEmpty
          ? 1000
          : existing.map((item) => item.sortKey).reduce(_max) + 1000,
      unit: unit,
      notes: notes,
      colorHex: colorHex,
      textColorHex: textColorHex,
      createdAt: now,
      updatedAt: now,
      revision: 1,
      deviceId: deviceId,
    );
    await database.saveHabit(habit);
    return habit;
  }

  Future<Habit> updateHabit(Habit habit) async {
    final updated = habit.copyWith(
      updatedAt: DateTime.now().toUtc(),
      revision: habit.revision + 1,
      deviceId: deviceId,
    );
    await database.saveHabit(updated);
    return updated;
  }

  Future<void> deleteHabit(Habit habit) async {
    await database.saveHabit(
      habit.copyWith(
        deletedAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
        revision: habit.revision + 1,
        deviceId: deviceId,
      ),
    );
  }

  Future<void> reorderHabits(List<Habit> ordered) async {
    for (var index = 0; index < ordered.length; index++) {
      await updateHabit(ordered[index].copyWith(sortKey: (index + 1) * 1000));
    }
  }

  Future<HabitEntry> setHabitValue(
    Habit habit,
    String dateKey,
    double value,
  ) async {
    final existing = await database.getHabitEntry(habit.id, dateKey);
    final now = DateTime.now().toUtc();
    final entry = existing == null
        ? HabitEntry(
            id: _uuid.v4(),
            habitId: habit.id,
            entryDate: dateKey,
            value: value < 0 ? 0 : value,
            updatedAt: now,
            revision: 1,
            deviceId: deviceId,
          )
        : existing.copyWith(
            value: value < 0 ? 0 : value,
            updatedAt: now,
            revision: existing.revision + 1,
            deviceId: deviceId,
          );
    await database.saveHabitEntry(entry);
    return entry;
  }

  Future<NorthStarNote> createNorthStarNote({
    required String title,
    String body = '',
  }) async {
    final existing = await database.loadNorthStarNotes();
    final now = DateTime.now().toUtc();
    final index = existing.length;
    final note = NorthStarNote(
      id: _uuid.v4(),
      title: title.trim().isEmpty ? 'NorthStar note' : title.trim(),
      body: body,
      sortKey: existing.isEmpty
          ? 1000
          : existing.map((item) => item.sortKey).reduce(_max) + 1000,
      x: 60 + (index % 3) * 350,
      y: 70 + (index ~/ 3) * 300,
      createdAt: now,
      updatedAt: now,
      revision: 1,
      deviceId: deviceId,
    );
    await database.saveNorthStarNote(note);
    return note;
  }

  Future<NorthStarNote> updateNorthStarNote(NorthStarNote note) async {
    final updated = note.copyWith(
      updatedAt: DateTime.now().toUtc(),
      revision: note.revision + 1,
      deviceId: deviceId,
    );
    await database.saveNorthStarNote(updated);
    return updated;
  }

  Future<void> deleteNorthStarNote(NorthStarNote note) async {
    await database.saveNorthStarNote(
      note.copyWith(
        deletedAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
        revision: note.revision + 1,
        deviceId: deviceId,
      ),
    );
  }

  Future<RewardRank> createRewardRank({
    required String name,
    required int minimumPoints,
    String icon = '⭐',
    String colorHex = '#6750A4',
  }) async {
    final existing = await database.loadRewardRanks();
    final now = DateTime.now().toUtc();
    final rank = RewardRank(
      id: _uuid.v4(),
      name: name.trim().isEmpty ? 'New rank' : name.trim(),
      minimumPoints: minimumPoints,
      sortKey: existing.isEmpty
          ? 1000
          : existing.map((item) => item.sortKey).reduce(_max) + 1000,
      icon: icon,
      colorHex: colorHex,
      createdAt: now,
      updatedAt: now,
      revision: 1,
      deviceId: deviceId,
    );
    await database.saveRewardRank(rank);
    return rank;
  }

  Future<RewardRank> updateRewardRank(RewardRank rank) async {
    final updated = rank.copyWith(
      updatedAt: DateTime.now().toUtc(),
      revision: rank.revision + 1,
      deviceId: deviceId,
    );
    await database.saveRewardRank(updated);
    return updated;
  }

  Future<void> deleteRewardRank(RewardRank rank) async {
    await database.saveRewardRank(
      rank.copyWith(
        deletedAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
        revision: rank.revision + 1,
        deviceId: deviceId,
      ),
    );
  }

  Future<StudyTable> createStudyTable({required String title}) async {
    final existing = await database.loadStudyTables();
    final now = DateTime.now().toUtc();
    final table = StudyTable(
      id: _uuid.v4(),
      title: title.trim().isEmpty ? 'Study table' : title.trim(),
      columnsJson: jsonEncode(['Topic', 'Status']),
      rowsJson: jsonEncode([['', '']]),
      sortKey: existing.isEmpty
          ? 1000
          : existing.map((item) => item.sortKey).reduce(_max) + 1000,
      createdAt: now,
      updatedAt: now,
      revision: 1,
      deviceId: deviceId,
    );
    await database.saveStudyTable(table);
    return table;
  }

  Future<StudyTable> updateStudyTable(StudyTable table) async {
    final updated = table.copyWith(
      updatedAt: DateTime.now().toUtc(),
      revision: table.revision + 1,
      deviceId: deviceId,
    );
    await database.saveStudyTable(updated);
    return updated;
  }

  Future<void> deleteStudyTable(StudyTable table) async {
    await database.saveStudyTable(
      table.copyWith(
        deletedAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
        revision: table.revision + 1,
        deviceId: deviceId,
      ),
    );
  }

  Future<WorkItem> createWorkItem({
    required String title,
    required WorkItemType type,
    String? parentId,
  }) async {
    final siblings = (await database.loadWorkItems())
        .where((item) => item.parentId == parentId && !item.isDeleted)
        .toList();
    final now = DateTime.now().toUtc();
    final item = WorkItem(
      id: _uuid.v4(),
      title: title.trim().isEmpty ? 'Untitled' : title.trim(),
      type: type,
      parentId: parentId,
      sortKey: siblings.isEmpty
          ? 1000
          : siblings.map((item) => item.sortKey).reduce(_max) + 1000,
      createdAt: now,
      updatedAt: now,
      revision: 1,
      deviceId: deviceId,
    );
    await database.saveWorkItem(item);
    return item;
  }

  Future<WorkItem> createQuickTask(String title) async {
    final siblings = (await database.loadWorkItems())
        .where((item) => item.parentId == null && !item.isDeleted)
        .toList();
    final now = DateTime.now().toUtc();
    final item = WorkItem(
      id: _uuid.v4(),
      title: title.trim().isEmpty ? 'Untitled' : title.trim(),
      type: WorkItemType.task,
      parentId: null,
      sortKey: siblings.isEmpty
          ? 1000
          : siblings.map((item) => item.sortKey).reduce(_max) + 1000,
      folder: 'Uncategorized',
      gtdStatus: GtdStatus.inbox,
      createdAt: now,
      updatedAt: now,
      revision: 1,
      deviceId: deviceId,
    );
    await database.saveWorkItem(item);
    return item;
  }

  Future<WorkItem> updateWorkItem(WorkItem item) async {
    final normalized = _normalizeItemState(item);
    final updated = normalized.copyWith(
      updatedAt: DateTime.now().toUtc(),
      revision: item.revision + 1,
      deviceId: deviceId,
    );
    await database.saveWorkItem(updated);
    return updated;
  }

  WorkItem _normalizeItemState(WorkItem item) {
    if (item.status == WorkStatus.archived) {
      return item;
    }
    if (item.checklistTotal > 0 && item.checklistDone >= item.checklistTotal) {
      return item.copyWith(
        checklistDone: item.checklistTotal,
        status: WorkStatus.completed,
        gtdStatus: GtdStatus.completed,
      );
    }
    if (item.status == WorkStatus.completed && item.checklistTotal > 0) {
      return item.copyWith(checklistDone: item.checklistTotal);
    }
    return item;
  }

  Future<void> setWorkItemCompleted(WorkItem item, bool completed) async {
    final wasCompleted = item.isCompleted;
    final next = item.copyWith(
      status: completed ? WorkStatus.completed : WorkStatus.active,
      gtdStatus: completed ? GtdStatus.completed : GtdStatus.inProgress,
      checklistDone: completed
          ? item.checklistTotal
          : item.checklistDone.clamp(0, item.checklistTotal).toInt(),
    );
    await updateWorkItem(next);
    if (completed && !wasCompleted && item.recurring) {
      await _cloneRecurringItem(item);
    }
  }

  Future<WorkItem?> advanceChecklist(String itemId) async {
    final item = await database.getWorkItem(itemId);
    if (item == null || item.isDeleted) return null;
    final targetTotal = item.checklistTotal > 0
        ? item.checklistTotal
        : item.sessionGoal.clamp(1, 200).toInt();
    final nextDone = (item.checklistDone + 1).clamp(0, targetTotal).toInt();
    final completed = nextDone >= targetTotal;
    final updated = await updateWorkItem(
      item.copyWith(
        checklistTotal: targetTotal,
        checklistDone: nextDone,
        status: completed ? WorkStatus.completed : WorkStatus.active,
        gtdStatus: completed ? GtdStatus.completed : GtdStatus.inProgress,
      ),
    );
    if (completed && item.recurring && !item.isCompleted) {
      await _cloneRecurringItem(item);
    }
    return updated;
  }

  Future<void> _cloneRecurringItem(WorkItem item) async {
    final now = DateTime.now().toUtc();
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final originalDue = item.dueDate?.toLocal();
    final originalDay = originalDue == null
        ? todayStart
        : DateTime(originalDue.year, originalDue.month, originalDue.day);
    final baseDay = originalDay.isBefore(todayStart) ? todayStart : originalDay;
    final nextDue = baseDay
        .add(Duration(days: item.recurrenceDays.clamp(1, 3650)))
        .toUtc();
    await database.saveWorkItem(
      WorkItem(
        id: _uuid.v4(),
        title: item.title,
        type: item.type,
        parentId: item.parentId,
        sortKey: await _nextSortKey(item.parentId),
        notes: item.notes,
        dueDate: nextDue,
        priority: item.priority,
        urgent: item.urgent,
        status: WorkStatus.active,
        gtdStatus: GtdStatus.toDo,
        paraCategory: item.paraCategory,
        checklistTotal: item.checklistTotal,
        checklistDone: 0,
        timerMinutes: item.timerMinutes,
        sessionGoal: item.sessionGoal,
        recurring: true,
        recurrenceDays: item.recurrenceDays,
        energyLevel: item.energyLevel,
        childColumns: item.childColumns,
        titleScale: item.titleScale,
        titleBold: item.titleBold,
        textColorHex: item.textColorHex,
        folder: item.folder,
        createdAt: now,
        updatedAt: now,
        revision: 1,
        deviceId: deviceId,
      ),
    );
  }

  Future<void> deleteWorkItem(WorkItem item) async {
    final all = await database.loadWorkItems();
    final children =
        all
            .where(
              (candidate) =>
                  candidate.parentId == item.id && !candidate.isDeleted,
            )
            .toList()
          ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    for (final child in children) {
      await updateWorkItem(child.copyWith(parentId: item.parentId));
    }
    if (children.isNotEmpty) {
      final promoted =
          (await database.loadWorkItems())
              .where(
                (candidate) =>
                    candidate.parentId == item.parentId && !candidate.isDeleted,
              )
              .toList()
            ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
      await _normalizeSiblingOrder(promoted, item.parentId);
    }
    final now = DateTime.now().toUtc();
    await database.saveWorkItem(
      item.copyWith(
        deletedAt: now,
        updatedAt: now,
        revision: item.revision + 1,
        deviceId: deviceId,
      ),
    );
  }

  Future<void> applyDrop({
    required String sourceId,
    String? targetId,
    required DropIntent intent,
  }) async {
    final all = await database.loadWorkItems();
    final byId = {for (final item in all) item.id: item};
    final source = byId[sourceId];
    if (source == null || sourceId == targetId) return;

    if (targetId != null && _wouldCreateCycle(sourceId, targetId, byId)) {
      throw StateError(
        'That move would place an item inside its own descendant.',
      );
    }

    if (intent == DropIntent.makeRoot) {
      await updateWorkItem(
        source.copyWith(
          parentId: null,
          type: WorkItemType.goal,
          sortKey: await _nextSortKey(null),
        ),
      );
      return;
    }

    final target = targetId == null ? null : byId[targetId];
    if (target == null) return;

    if (intent == DropIntent.makeChild) {
      if (target.type.index >= source.type.index) {
        throw StateError(
          'A ${source.type.name} can only be placed under a higher-level item.',
        );
      }
      await updateWorkItem(
        source.copyWith(
          parentId: target.id,
          sortKey: await _nextSortKey(target.id),
        ),
      );
      return;
    }

    final siblingParent = target.parentId;
    final siblings =
        all
            .where(
              (item) => item.parentId == siblingParent && item.id != source.id,
            )
            .toList()
          ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    final targetIndex = siblings.indexWhere((item) => item.id == target.id);
    final insertionIndex = intent == DropIntent.before
        ? targetIndex
        : targetIndex + 1;
    siblings.insert(
      insertionIndex.clamp(0, siblings.length).toInt(),
      source.copyWith(parentId: siblingParent),
    );
    await _normalizeSiblingOrder(siblings, siblingParent);
  }

  bool _wouldCreateCycle(
    String sourceId,
    String candidateParentId,
    Map<String, WorkItem> byId,
  ) {
    String? cursor = candidateParentId;
    while (cursor != null) {
      if (cursor == sourceId) return true;
      cursor = byId[cursor]?.parentId;
    }
    return false;
  }

  Future<double> _nextSortKey(String? parentId) async {
    final siblings = (await database.loadWorkItems())
        .where((item) => item.parentId == parentId)
        .toList();
    if (siblings.isEmpty) return 1000;
    return siblings.map((item) => item.sortKey).reduce(_max) + 1000;
  }

  Future<void> _normalizeSiblingOrder(
    List<WorkItem> siblings,
    String? parentId,
  ) async {
    for (var index = 0; index < siblings.length; index++) {
      final current = siblings[index];
      final desired = (index + 1) * 1000.0;
      if (current.parentId != parentId || current.sortKey != desired) {
        await updateWorkItem(
          current.copyWith(parentId: parentId, sortKey: desired),
        );
      }
    }
  }

  Future<CanvasLayout> saveLayout(CanvasLayout layout) async {
    final updated = layout.copyWith(
      updatedAt: DateTime.now().toUtc(),
      revision: layout.revision + 1,
      deviceId: deviceId,
    );
    await database.saveLayout(updated);
    return updated;
  }

  CanvasLayout defaultLayout({
    required String itemId,
    required CanvasViewKind viewKind,
    required DeviceClass deviceClass,
    double x = 80,
    double y = 80,
  }) {
    final now = DateTime.now().toUtc();
    return CanvasLayout(
      id: '${itemId}_${viewKind.name}_${deviceClass.name}',
      itemId: itemId,
      viewKind: viewKind,
      deviceClass: deviceClass,
      x: x,
      y: y,
      width: viewKind == CanvasViewKind.mindMap ? 260 : 330,
      height: viewKind == CanvasViewKind.mindMap ? 105 : 170,
      updatedAt: now,
      revision: 1,
      deviceId: deviceId,
    );
  }

  Future<JournalEntry> getOrCreateJournal(String dateKey) async {
    final existing = await database.getJournalByDate(dateKey);
    if (existing != null) return existing;
    final now = DateTime.now().toUtc();
    final entry = JournalEntry(
      id: _uuid.v4(),
      entryDate: dateKey,
      createdAt: now,
      updatedAt: now,
      revision: 1,
      deviceId: deviceId,
    );
    await database.saveJournal(entry);
    return entry;
  }

  Future<JournalEntry> saveJournal(JournalEntry entry) async {
    final updated = entry.copyWith(
      updatedAt: DateTime.now().toUtc(),
      revision: entry.revision + 1,
      deviceId: deviceId,
    );
    await database.saveJournal(updated);
    return updated;
  }

  Future<void> deleteJournal(JournalEntry entry) async {
    final now = DateTime.now().toUtc();
    await database.saveJournal(
      entry.copyWith(
        deletedAt: now,
        updatedAt: now,
        revision: entry.revision + 1,
        deviceId: deviceId,
      ),
    );
  }

  Future<void> snapshotJournal(JournalEntry entry) async {
    await database.saveJournalVersion(
      JournalVersion(
        id: _uuid.v4(),
        journalId: entry.id,
        snapshotJson: jsonEncode(entry.toMap()),
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<List<JournalVersion>> journalVersions(String journalId) =>
      database.loadJournalVersions(journalId);

  Future<void> saveTimeSession(TimeSession session) =>
      database.saveTimeSession(session);

  Future<TimeSession> createManualFocusSession({
    required int minutes,
    DateTime? now,
  }) async {
    final instant = (now ?? DateTime.now()).toUtc();
    final seconds = minutes.clamp(1, 720).toInt() * 60;
    final session = TimeSession(
      id: _uuid.v4(),
      mode: TimerMode.general,
      title: 'Manual focus',
      plannedSeconds: seconds,
      elapsedSeconds: seconds,
      startedAt: instant,
      endedAt: instant,
      completed: true,
      notes: '[slamdone:manual-focus]',
      createdAt: instant,
      updatedAt: instant,
      revision: 1,
      deviceId: deviceId,
    );
    await database.saveTimeSession(session);
    return session;
  }

  TimeSession _copyTimeSessionForLedger(
    TimeSession current, {
    required DateTime updatedAt,
    required DateTime? deletedAt,
  }) => TimeSession(
    id: current.id,
    ownerId: current.ownerId,
    mode: current.mode,
    workItemId: current.workItemId,
    title: current.title,
    plannedSeconds: current.plannedSeconds,
    elapsedSeconds: current.elapsedSeconds,
    startedAt: current.startedAt,
    endedAt: current.endedAt,
    completed: current.completed,
    notes: current.notes,
    createdAt: current.createdAt,
    updatedAt: updatedAt,
    revision: current.revision + 1,
    deviceId: deviceId,
    deletedAt: deletedAt,
  );

  Future<TimeSession?> softDeleteTimeSession(String id) async {
    final current = await database.getTimeSession(id);
    if (current == null) return null;
    if (current.deletedAt != null) return current;
    final now = DateTime.now().toUtc();
    final deleted = _copyTimeSessionForLedger(
      current,
      updatedAt: now,
      deletedAt: now,
    );
    await database.saveTimeSession(deleted);
    return deleted;
  }

  Future<TimeSession?> restoreTimeSession(String id) async {
    final current = await database.getTimeSession(id);
    if (current == null) return null;
    if (current.deletedAt == null) return current;
    final now = DateTime.now().toUtc();
    final restored = _copyTimeSessionForLedger(
      current,
      updatedAt: now,
      deletedAt: null,
    );
    await database.saveTimeSession(restored);
    return restored;
  }

  Future<String?> exportForAutivra4() async {
    final allSettings = await database.loadAllSettings();
    final compatibleSettings = <String, String>{};
    for (final entry in allSettings.entries) {
      if (_isAutivraCompatibleSetting(entry.key)) {
        compatibleSettings[entry.key] = entry.value;
      }
    }
    // LocalDatabase.exportAllEntities() intentionally mirrors the native
    // Autivra4 V6 entity list: work items/layouts/journals/focus/habits/
    // NorthStar/rewards/study tables, without journal_versions or timer state.
    final entities = await database.exportAllEntities();
    const nativeEntities = <String>{
      'work_items',
      'canvas_layouts',
      'journal_entries',
      'time_sessions',
      'habits',
      'habit_entries',
      'northstar_notes',
      'reward_ranks',
      'study_tables',
    };
    entities.removeWhere((key, _) => !nativeEntities.contains(key));
    final payload = {
      'version': 6,
      'application': 'Autivra4',
      'exportedAt': isoNow(),
      'entities': entities,
      'settings': compatibleSettings,
    };

    final fileName =
        'Autivra4_Update_From_SlamDone_${DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now())}.json';
    final bytes = Uint8List.fromList(utf8.encode(
      const JsonEncoder.withIndent('  ').convert(payload),
    ));
    final result = await FilePicker.saveFile(
      dialogTitle: 'Export SlamDone progress for Autivra4',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
    return result?.toString() ?? fileName;
  }

  Future<String?> exportBackup() async {
    final payload = {
      'version': 7,
      'application': 'SlamDone',
      'migrationSource': 'Autivra4-compatible',
      'exportedAt': isoNow(),
      'entities': await database.exportAllEntities(),
      'settings': await database.loadAllSettings(),
    };
    final fileName =
        'SlamDone_Backup_${DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now())}.json';
    final bytes = Uint8List.fromList(utf8.encode(
      const JsonEncoder.withIndent('  ').convert(payload),
    ));
    final result = await FilePicker.saveFile(
      dialogTitle: 'Export SlamDone backup',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
    return result?.toString() ?? fileName;
  }

  Future<MigrationImportResult> importMigrationJsonFile() async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Select the private Autivra4 to SlamDone migration JSON',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) {
      throw const FormatException('Migration selection was cancelled.');
    }
    final data = picked.files.single.bytes;
    if (data == null) {
      throw const FormatException('The selected migration could not be read.');
    }
    return importMigrationJson(utf8.decode(data));
  }

  Future<MigrationImportResult> importMigrationJson(String rawJson) async {
    final payload = MigrationPayload.fromJson(rawJson);
    final changed = await database.applyMigrationPayload(payload);
    await database.setSetting('migration_last_sha256', payload.sourceSha256);
    await database.setSetting('migration_completed_at', isoNow());
    final localCounts = await database.migrationCounts();
    return MigrationImportResult(
      changedByTable: Map.unmodifiable(changed),
      sourceCounts: Map.unmodifiable(payload.sourceCounts),
      localCounts: Map.unmodifiable(localCounts),
      sourceSha256: payload.sourceSha256,
    );
  }

  Future<int> importV4JsonFile() async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Select an Autivra4 / SlamDone / Goal Tree JSON backup',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return 0;
    final file = picked.files.single;
    final data = file.bytes;
    if (data == null) {
      throw const FormatException('The selected backup could not be read in this browser.');
    }
    final raw = utf8.decode(data);
    return importJson(raw);
  }

  Future<int> importJson(String rawJson) async {
    final parsed = jsonDecode(rawJson);
    if (parsed is! Map) {
      throw const FormatException(
        'The selected file is not a planner JSON object.',
      );
    }
    final root = parsed.cast<String, dynamic>();
    if (root['entities'] is Map) {
      return _importAutivraEntities(
        (root['entities'] as Map).cast<String, dynamic>(),
        settings: root['settings'] is Map
            ? (root['settings'] as Map).cast<String, dynamic>()
            : null,
      );
    }
    return _importLegacyV4(root);
  }

  Future<int> _importAutivraEntities(
    Map<String, dynamic> entities, {
    Map<String, dynamic>? settings,
  }) async {
    var imported = 0;
    final tables = <String, Future<void> Function(Map<String, Object?>)>{
      'work_items': (row) => database.saveWorkItem(WorkItem.fromMap(row)),
      'canvas_layouts': (row) => database.saveLayout(CanvasLayout.fromMap(row)),
      'journal_entries': (row) =>
          database.saveJournal(JournalEntry.fromMap(row)),
      'time_sessions': (row) =>
          database.saveTimeSession(TimeSession.fromMap(row)),
      'habits': (row) => database.saveHabit(Habit.fromMap(row)),
      'habit_entries': (row) =>
          database.saveHabitEntry(HabitEntry.fromMap(row)),
      'northstar_notes': (row) =>
          database.saveNorthStarNote(NorthStarNote.fromMap(row)),
      'reward_ranks': (row) => database.saveRewardRank(RewardRank.fromMap(row)),
      'study_tables': (row) => database.saveStudyTable(StudyTable.fromMap(row)),
    };
    for (final entry in tables.entries) {
      final rawRows = entities[entry.key];
      if (rawRows is! List) continue;
      for (final raw in rawRows) {
        if (raw is! Map) continue;
        final row = raw.cast<String, Object?>();
        final id = row['id']?.toString();
        if (id == null || id.isEmpty) continue;
        final exists = await database.db.query(
          entry.key,
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (exists.isNotEmpty) continue;
        await entry.value(row);
        imported++;
      }
    }
    if (settings != null) {
      for (final entry in settings.entries) {
        await database.setSetting(entry.key, entry.value.toString());
      }
    }
    return imported;
  }

  Future<int> _importLegacyV4(Map<String, dynamic> root) async {
    var imported = 0;
    final knownIds = <String>{};

    Future<void> importNode(
      Map<String, dynamic> node,
      String? parentId,
      double order,
    ) async {
      final oldId = node['id']?.toString();
      final id = oldId != null && oldId.isNotEmpty ? oldId : _uuid.v4();
      if (!knownIds.add(id) || await database.getWorkItem(id) != null) return;
      final now = DateTime.now().toUtc();
      final type = WorkItemType.values.firstWhere(
        (value) => value.name == node['type']?.toString(),
        orElse: () => WorkItemType.task,
      );
      final dueDateRaw = node['dueDate']?.toString();
      final total = ((node['unitsTotal'] as num?)?.toInt() ?? 0)
          .clamp(0, 200)
          .toInt();
      final done = ((node['unitsDone'] as num?)?.toInt() ?? 0)
          .clamp(0, total)
          .toInt();
      final item = WorkItem(
        id: id,
        title: node['title']?.toString() ?? 'Untitled',
        type: type,
        parentId: parentId,
        sortKey: order,
        notes: node['notes']?.toString() ?? '',
        dueDate: dueDateRaw == null || dueDateRaw.isEmpty
            ? null
            : DateTime.tryParse(dueDateRaw)?.toUtc(),
        priority: (node['priority']?.toString() ?? 'normal').asPriorityLevel(),
        urgent: node['priority']?.toString() == 'urgent',
        status: node['archived'] == true
            ? WorkStatus.archived
            : total > 0 && done >= total
            ? WorkStatus.completed
            : WorkStatus.active,
        checklistTotal: total,
        checklistDone: done,
        timerMinutes: ((node['timerMinutes'] as num?)?.toInt() ?? 25)
            .clamp(1, 720)
            .toInt(),
        createdAt: now,
        updatedAt: now,
        revision: 1,
        deviceId: deviceId,
      );
      await database.saveWorkItem(item);
      imported++;
      final children = node['children'];
      if (children is List) {
        for (var index = 0; index < children.length; index++) {
          final child = children[index];
          if (child is Map) {
            await importNode(
              child.cast<String, dynamic>(),
              id,
              (index + 1) * 1000,
            );
          }
        }
      }
    }

    final nodes = root['nodes'];
    if (nodes is List) {
      for (var index = 0; index < nodes.length; index++) {
        final node = nodes[index];
        if (node is Map) {
          await importNode(
            node.cast<String, dynamic>(),
            null,
            (index + 1) * 1000,
          );
        }
      }
    }
    return imported;
  }

  static double _max(double a, double b) => a > b ? a : b;
}
