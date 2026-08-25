import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../database/local_database.dart';
import '../migration/migration_models.dart';
import '../models/models.dart';
import '../repositories/app_repository.dart';
import '../services/sync_service.dart';
import '../services/timer_engine.dart';
import '../services/top_bar_theme_bridge.dart';


class AutoArchiveNotice {
  const AutoArchiveNotice({
    required this.itemId,
    required this.title,
    required this.sequence,
  });

  final String itemId;
  final String title;
  final int sequence;
}

class AppController extends ChangeNotifier {
  AppController({required this.database, required this.repository});

  final LocalDatabase database;
  final AppRepository repository;

  late final SyncService syncService;
  late final TimerEngine timerEngine;

  List<WorkItem> workItems = const [];
  List<JournalEntry> journals = const [];
  List<TimeSession> sessions = const [];
  List<Habit> habits = const [];
  List<HabitEntry> habitEntries = const [];
  List<NorthStarNote> northStarNotes = const [];
  List<RewardRank> rewardRanks = const [];
  List<StudyTable> studyTables = const [];
  Map<String, CanvasLayout> bigPictureLayouts = const {};
  Map<String, CanvasLayout> mindMapLayouts = const {};
  final Set<String> editingJournalIds = <String>{};

  AppSection selectedSection = defaultTargetPlatform == TargetPlatform.windows
      ? AppSection.overview
      : AppSection.doFirst;
  bool loading = true;
  bool focusPanelHidden = false;
  ThemeMode themeMode = ThemeMode.light;
  int accentColorValue = 0xFF4CAF7A;
  int topBarColorValue = 0;
  int backgroundColorValue = 0;
  int cardColorValue = 0;
  int textColorValue = 0;
  double fontScale = 1.0;
  String fontFamily = defaultTargetPlatform == TargetPlatform.android ? 'Roboto' : 'Segoe UI';
  int dailySessionGoal = 10;
  int defaultSessionMinutes = 25;
  int weeklySessionGoal = 50;
  int weeklyFocusDaysGoal = 5;
  int weeklySessionMinutes = 25;
  int monthlySessionGoal = 200;
  int monthlyFocusDaysGoal = 20;
  int monthlySessionMinutes = 25;
  double habitNameWidth = 260;
  Map<String, double> habitRowHeights = const {};
  bool habitTotalsBold = true;
  Map<String, String> mindMapTextColors = const {};
  Map<String, double> northStarTitleScales = const {};
  Map<String, double> northStarBodyScales = const {};
  int pointsPerFocusMinute = 1;
  int pointsPerHabitCheckIn = 5;
  int dashboardPaletteIndex = 0;
  Map<WorkItemType, int> itemPointValues = const {
    WorkItemType.goal: 1000,
    WorkItemType.milestone: 500,
    WorkItemType.project: 250,
    WorkItemType.subproject: 150,
    WorkItemType.module: 75,
    WorkItemType.task: 25,
  };
  List<TabPreference> tabPreferences = const [];
  List<Map<String, dynamic>> journalPrompts = const [];
  String? message;
  Timer? _messageClearTimer;
  bool floatingTimerVisible = false;
  AutoArchiveNotice? autoArchiveNotice;
  int _autoArchiveNoticeSequence = 0;
  final Map<String, Timer> _autoArchiveTimers = <String, Timer>{};
  final Map<String, WorkItem> _autoArchiveSnapshots = <String, WorkItem>{};
  String _lastTimerCompletionToken = '';
  String _lastTimerAutoArchiveToken = '';

  DeviceClass get deviceClass {
    final platform = defaultTargetPlatform;
    final desktop = platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
    return desktop ? DeviceClass.desktop : DeviceClass.mobile;
  }

  static List<TabPreference> defaultTabPreferences() => [
    const TabPreference(
      section: AppSection.overview,
      label: 'Overview',
      colorValue: 0xFF26A69A,
      iconKey: 'overview',
    ),
    const TabPreference(
      section: AppSection.doFirst,
      label: 'Do First',
      colorValue: 0xFFFFA726,
      iconKey: 'bolt',
    ),
    const TabPreference(
      section: AppSection.bigPicture,
      label: 'Big Picture',
      colorValue: 0xFF42A5F5,
      iconKey: 'dashboard',
    ),
    const TabPreference(
      section: AppSection.mindMap,
      label: 'Mind Map',
      colorValue: 0xFFAB47BC,
      iconKey: 'hub',
    ),
    const TabPreference(
      section: AppSection.focus,
      label: 'Focus',
      colorValue: 0xFFEF5350,
      iconKey: 'timer',
    ),
    const TabPreference(
      section: AppSection.tasks,
      label: 'Tasks',
      colorValue: 0xFF5C6BC0,
      iconKey: 'tasks',
    ),
    const TabPreference(
      section: AppSection.calendar,
      label: 'Calendar',
      colorValue: 0xFF26C6DA,
      iconKey: 'calendar',
    ),
    const TabPreference(
      section: AppSection.habits,
      label: 'Habits',
      colorValue: 0xFF66BB6A,
      iconKey: 'habit',
    ),
    const TabPreference(
      section: AppSection.journal,
      label: 'Journal',
      colorValue: 0xFFEC407A,
      iconKey: 'journal',
    ),
    const TabPreference(
      section: AppSection.northStar,
      label: 'NorthStar',
      colorValue: 0xFFFFCA28,
      iconKey: 'northstar',
    ),
    const TabPreference(
      section: AppSection.rewards,
      label: 'Rewards',
      colorValue: 0xFFFF7043,
      iconKey: 'rewards',
    ),
    const TabPreference(
      section: AppSection.gtdPara,
      label: 'GTD + PARA',
      colorValue: 0xFF78909C,
      iconKey: 'kanban',
    ),
    const TabPreference(
      section: AppSection.studyTables,
      label: 'Tables',
      colorValue: 0xFF7E57C2,
      iconKey: 'table',
    ),
    const TabPreference(
      section: AppSection.settings,
      label: 'Settings',
      colorValue: 0xFF8D6E63,
      iconKey: 'settings',
    ),
  ];

  static List<Map<String, dynamic>> defaultJournalPrompts() => [
    {
      'id': 'winBig',
      'question': 'What do you want to achieve today to win big?',
      'width': 1.0,
    },
    {
      'id': 'feel',
      'question': 'How do you want to feel today, and why?',
      'width': 0.5,
    },
    {'id': 'grateful', 'question': 'What are you grateful for?', 'width': 0.5},
    {
      'id': 'regret',
      'question': 'What would you regret not doing when you are 80?',
      'width': 0.5,
    },
    {
      'id': 'pretending',
      'question': 'What am I pretending not to know?',
      'width': 0.5,
    },
    {
      'id': 'flow',
      'question': 'What consistently makes me lose track of time?',
      'width': 0.5,
    },
    {
      'id': 'notTolerate',
      'question': 'What does the best version of myself not tolerate?',
      'width': 0.5,
    },
  ];

  Future<void> initialize() async {
    await repository.initialize();
    syncService = SyncService(
      database: database,
      onRemoteChanged: _reloadRemoteState,
      isJournalEditing: editingJournalIds.contains,
    );
    timerEngine = TimerEngine(
      database: database,
      repository: repository,
      role: TimerOwner.main,
    );
    syncService.addListener(notifyListeners);
    timerEngine.addListener(_onTimerChanged);
    await _loadSettings();
    await refreshAll();
    await timerEngine.initialize();
    await syncService.initialize();
    loading = false;
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    focusPanelHidden =
        (await database.getSetting('focus_panel_hidden')) == 'true';
    final savedTheme = await database.getSetting('theme_mode');
    themeMode = ThemeMode.values.firstWhere(
      (value) => value.name == savedTheme,
      orElse: () => ThemeMode.light,
    );
    accentColorValue =
        int.tryParse(await database.getSetting('accent_color') ?? '') ??
        0xFF4CAF7A;
    topBarColorValue =
        int.tryParse(await database.getSetting('top_bar_color') ?? '') ?? 0;
    applyTopBarThemeColor(topBarColorValue);
    backgroundColorValue =
        int.tryParse(await database.getSetting('background_color') ?? '') ?? 0;
    cardColorValue =
        int.tryParse(await database.getSetting('card_color') ?? '') ?? 0;
    textColorValue =
        int.tryParse(await database.getSetting('text_color') ?? '') ?? 0;
    fontScale =
        (double.tryParse(await database.getSetting('font_scale') ?? '') ?? 1.0)
            .clamp(0.8, 1.6)
            .toDouble();
    fontFamily =
        await database.getSetting('font_family') ??
        (defaultTargetPlatform == TargetPlatform.android ? 'Roboto' : 'Segoe UI');
    dailySessionGoal =
        (int.tryParse(await database.getSetting('daily_session_goal') ?? '') ??
                10)
            .clamp(1, 200)
            .toInt();
    defaultSessionMinutes =
        (int.tryParse(
                  await database.getSetting('default_session_minutes') ?? '',
                ) ??
                25)
            .clamp(1, 720)
            .toInt();
    weeklySessionGoal =
        (int.tryParse(await database.getSetting('weekly_session_goal') ?? '') ??
                50)
            .clamp(1, 1400)
            .toInt();
    weeklyFocusDaysGoal =
        (int.tryParse(
                  await database.getSetting('weekly_focus_days_goal') ?? '',
                ) ??
                5)
            .clamp(1, 7)
            .toInt();
    weeklySessionMinutes =
        (int.tryParse(
                  await database.getSetting('weekly_session_minutes') ?? '',
                ) ??
                defaultSessionMinutes)
            .clamp(1, 720)
            .toInt();
    monthlySessionGoal =
        (int.tryParse(
                  await database.getSetting('monthly_session_goal') ?? '',
                ) ??
                200)
            .clamp(1, 6200)
            .toInt();
    monthlyFocusDaysGoal =
        (int.tryParse(
                  await database.getSetting('monthly_focus_days_goal') ?? '',
                ) ??
                20)
            .clamp(1, 31)
            .toInt();
    monthlySessionMinutes =
        (int.tryParse(
                  await database.getSetting('monthly_session_minutes') ?? '',
                ) ??
                defaultSessionMinutes)
            .clamp(1, 720)
            .toInt();
    mindMapTextColors = _decodeStringMap(
      await database.getSetting('mind_map_text_colors_json'),
    );
    northStarTitleScales = _decodeDoubleMap(
      await database.getSetting('northstar_title_scales_json'),
    );
    northStarBodyScales = _decodeDoubleMap(
      await database.getSetting('northstar_body_scales_json'),
    );
    habitNameWidth =
        (double.tryParse(await database.getSetting('habit_name_width') ?? '') ??
                260)
            .clamp(190, 520)
            .toDouble();
    habitRowHeights = _decodeDoubleMap(
      await database.getSetting('habit_row_heights_json'),
    );
    habitTotalsBold =
        (await database.getSetting('habit_totals_bold')) != 'false';
    pointsPerFocusMinute =
        (int.tryParse(
                  await database.getSetting('points_per_focus_minute') ?? '',
                ) ??
                1)
            .clamp(0, 1000)
            .toInt();
    pointsPerHabitCheckIn =
        (int.tryParse(
                  await database.getSetting('points_per_habit_checkin') ?? '',
                ) ??
                5)
            .clamp(0, 10000)
            .toInt();
    dashboardPaletteIndex =
        (int.tryParse(await database.getSetting('dashboard_palette') ?? '') ??
                0)
            .clamp(0, 4)
            .toInt();
    itemPointValues = {
      for (final type in WorkItemType.values)
        type:
            (int.tryParse(
                      await database.getSetting('points_${type.name}') ?? '',
                    ) ??
                    _defaultPoints(type))
                .clamp(0, 100000)
                .toInt(),
    };

    final tabJson = await database.getSetting('tab_preferences_json');
    tabPreferences = _decodeTabPreferences(tabJson);
    final promptJson = await database.getSetting('journal_prompts_json');
    journalPrompts = _decodeJournalPrompts(promptJson);
  }

  List<TabPreference> _decodeTabPreferences(String? raw) {
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final values = decoded
              .whereType<Map>()
              .map(
                (item) => TabPreference.fromMap(item.cast<String, dynamic>()),
              )
              .map((item) {
                final label = item.label == 'Focus To Win' ? 'Focus'
                    : item.label == 'Study Tables' ? 'Tables'
                    : item.label;
                return TabPreference(
                  section: item.section,
                  label: label,
                  colorValue: item.colorValue,
                  iconKey: item.iconKey,
                );
              })
              .toList();
          final seen = values.map((item) => item.section).toSet();
          for (final fallback in defaultTabPreferences()) {
            if (!seen.contains(fallback.section)) values.add(fallback);
          }
          return values;
        }
      } catch (_) {}
    }
    return defaultTabPreferences();
  }

  List<Map<String, dynamic>> _decodeJournalPrompts(String? raw) {
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final prompts = decoded
              .whereType<Map>()
              .map((item) => item.cast<String, dynamic>())
              .where(
                (item) =>
                    item['id']?.toString().isNotEmpty == true &&
                    item['question']?.toString().isNotEmpty == true,
              )
              .toList();
          if (prompts.isNotEmpty) return prompts;
        }
      } catch (_) {}
    }
    return defaultJournalPrompts();
  }

  Map<String, String> _decodeStringMap(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map.unmodifiable({
          for (final entry in decoded.entries)
            if (entry.key.toString().isNotEmpty &&
                entry.value?.toString().isNotEmpty == true)
              entry.key.toString(): entry.value.toString(),
        });
      }
    } catch (_) {}
    return const {};
  }

  Map<String, double> _decodeDoubleMap(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map.unmodifiable({
          for (final entry in decoded.entries)
            if (double.tryParse(entry.value.toString()) != null)
              entry.key.toString(): double.parse(entry.value.toString()),
        });
      }
    } catch (_) {}
    return const {};
  }

  int _defaultPoints(WorkItemType type) => switch (type) {
    WorkItemType.goal => 1000,
    WorkItemType.milestone => 500,
    WorkItemType.project => 250,
    WorkItemType.subproject => 150,
    WorkItemType.module => 75,
    WorkItemType.task => 25,
  };

  void _onTimerChanged() {
    // Timer ticks are painted by widgets that listen directly to TimerEngine.
    // Avoid rebuilding the entire application four times per second.
    final state = timerEngine.state;
    final token = state.completionToken;
    if (token.isNotEmpty && token != _lastTimerCompletionToken) {
      _lastTimerCompletionToken = token;
      unawaited(refreshSessions());
      unawaited(refreshWorkItemsAndLayouts());
      _scheduleCloudPush();
    }

    final workItemId = timerEngine.state.workItemId;
    final finishedCountdown =
        !timerEngine.isActive &&
        state.mode != TimerMode.stopwatch &&
        state.remainingSeconds <= 0 &&
        workItemId != null;
    if (finishedCountdown &&
        token.isNotEmpty &&
        token != _lastTimerAutoArchiveToken) {
      _lastTimerAutoArchiveToken = token;
      final before = itemById(workItemId);
      if (before != null) {
        unawaited(_refreshAfterTimerCompletion(before));
        return;
      }
    }

    if (!timerEngine.isActive) {
      unawaited(refreshSessions());
      unawaited(refreshWorkItemsAndLayouts());
    }
  }

  Future<void> _refreshAfterTimerCompletion(WorkItem before) async {
    await refreshSessions();
    await refreshWorkItemsAndLayouts();
    _scheduleAutoArchiveIfNeeded(before, itemById(before.id));
  }

  Future<void> _reloadRemoteState() async {
    await _loadSettings();
    await refreshAll();
    await timerEngine.reloadFromDatabase();
  }

  Future<void> refreshAll() async {
    workItems = await repository.loadWorkItems();
    journals = await repository.loadJournals();
    sessions = await repository.loadSessions();
    habits = await repository.loadHabits();
    habitEntries = await repository.loadHabitEntries();
    northStarNotes = await repository.loadNorthStarNotes();
    rewardRanks = await repository.loadRewardRanks();
    studyTables = await repository.loadStudyTables();
    bigPictureLayouts = {
      for (final layout in await repository.loadLayouts(
        CanvasViewKind.bigPicture,
        deviceClass,
      ))
        layout.itemId: layout,
    };
    mindMapLayouts = {
      for (final layout in await repository.loadLayouts(
        CanvasViewKind.mindMap,
        deviceClass,
      ))
        layout.itemId: layout,
    };
    notifyListeners();
  }

  Future<void> refreshWorkItemsAndLayouts() async {
    workItems = await repository.loadWorkItems();
    bigPictureLayouts = {
      for (final layout in await repository.loadLayouts(
        CanvasViewKind.bigPicture,
        deviceClass,
      ))
        layout.itemId: layout,
    };
    mindMapLayouts = {
      for (final layout in await repository.loadLayouts(
        CanvasViewKind.mindMap,
        deviceClass,
      ))
        layout.itemId: layout,
    };
    notifyListeners();
  }

  Future<void> refreshJournals() async {
    journals = await repository.loadJournals();
    notifyListeners();
  }

  Future<void> refreshSessions() async {
    sessions = await repository.loadSessions();
    notifyListeners();
  }

  Future<TimeSession> addManualFocusSession() async {
    final session = await repository.createManualFocusSession(
      minutes: defaultSessionMinutes,
    );
    await refreshSessions();
    _scheduleCloudPush();
    return session;
  }

  Future<TimeSession?> removeFocusSession(String id) async {
    final removed = await repository.softDeleteTimeSession(id);
    if (removed != null) {
      await refreshSessions();
      _scheduleCloudPush();
    }
    return removed;
  }

  Future<TimeSession?> restoreFocusSession(String id) async {
    final restored = await repository.restoreTimeSession(id);
    if (restored != null) {
      await refreshSessions();
      _scheduleCloudPush();
    }
    return restored;
  }

  Future<void> refreshHabits() async {
    habits = await repository.loadHabits();
    habitEntries = await repository.loadHabitEntries();
    notifyListeners();
  }

  Future<void> refreshNorthStar() async {
    northStarNotes = await repository.loadNorthStarNotes();
    notifyListeners();
  }

  Future<void> refreshRewards() async {
    rewardRanks = await repository.loadRewardRanks();
    notifyListeners();
  }

  Future<void> refreshStudyTables() async {
    studyTables = await repository.loadStudyTables();
    notifyListeners();
  }

  void selectSection(AppSection section) {
    selectedSection = section;
    notifyListeners();
  }

  TabPreference tabPreference(AppSection section) {
    return tabPreferences.firstWhere(
      (item) => item.section == section,
      orElse: () =>
          defaultTabPreferences().firstWhere((item) => item.section == section),
    );
  }

  WorkItem? itemById(String? id) {
    if (id == null) return null;
    for (final item in workItems) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<WorkItem> childrenOf(String? parentId) {
    final result =
        workItems
            .where((item) => item.parentId == parentId && !item.isDeleted)
            .toList()
          ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return result;
  }

  List<WorkItem> descendantsOf(String id) {
    final output = <WorkItem>[];
    void walk(String parentId) {
      for (final child in childrenOf(parentId)) {
        output.add(child);
        walk(child.id);
      }
    }

    walk(id);
    return output;
  }

  void _scheduleCloudPush() => syncService.schedulePush();

  Future<WorkItem> createWorkItem({
    required String title,
    required WorkItemType type,
    String? parentId,
  }) async {
    final item = await repository.createWorkItem(
      title: title,
      type: type,
      parentId: parentId,
    );
    await refreshWorkItemsAndLayouts();
    _scheduleCloudPush();
    return item;
  }

  Future<WorkItem> createQuickTask(String title) async {
    final item = await repository.createQuickTask(title);
    workItems = [...workItems, item]
      ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    notifyListeners();
    _scheduleCloudPush();
    return item;
  }

  Future<void> updateWorkItem(WorkItem item) async {
    final before = itemById(item.id) ?? item;
    await repository.updateWorkItem(item);
    await refreshWorkItemsAndLayouts();
    _scheduleCloudPush();
    _scheduleAutoArchiveIfNeeded(before, itemById(item.id));
  }

  Future<void> moveWorkItemToGtdStatus(
    WorkItem item,
    GtdStatus target,
  ) async {
    final targetWorkStatus = target == GtdStatus.completed
        ? WorkStatus.completed
        : target == GtdStatus.archived
            ? WorkStatus.archived
            : WorkStatus.active;
    var targetChecklistDone = item.checklistDone;
    if (target == GtdStatus.completed && item.checklistTotal > 0) {
      targetChecklistDone = item.checklistTotal;
    } else if (target != GtdStatus.archived &&
        target != GtdStatus.completed &&
        item.checklistTotal > 0 &&
        targetChecklistDone >= item.checklistTotal) {
      targetChecklistDone = (item.checklistTotal - 1).clamp(0, item.checklistTotal).toInt();
    }
    if (targetWorkStatus == WorkStatus.active) {
      _cancelPendingAutoArchive(item.id);
    }
    await repository.updateWorkItem(
      item.copyWith(
        gtdStatus: target,
        status: targetWorkStatus,
        checklistDone: targetChecklistDone,
      ),
    );
    await refreshWorkItemsAndLayouts();
    _scheduleCloudPush();
  }

  Future<void> setWorkItemCompleted(WorkItem item, bool value) async {
    final before = itemById(item.id) ?? item;
    if (!value) {
      _cancelPendingAutoArchive(item.id);
    }
    await repository.setWorkItemCompleted(item, value);
    await refreshWorkItemsAndLayouts();
    _scheduleCloudPush();
    if (value) {
      _scheduleAutoArchiveIfNeeded(before, itemById(item.id));
    }
  }

  Future<void> updateChecklist(WorkItem item, int done) async {
    final before = itemById(item.id) ?? item;
    final normalized = done.clamp(0, item.checklistTotal).toInt();
    await repository.updateWorkItem(
      item.copyWith(
        checklistDone: normalized,
        status: item.checklistTotal > 0 && normalized >= item.checklistTotal
            ? WorkStatus.completed
            : WorkStatus.active,
        gtdStatus: item.checklistTotal > 0 && normalized >= item.checklistTotal
            ? GtdStatus.completed
            : GtdStatus.inProgress,
      ),
    );
    await refreshWorkItemsAndLayouts();
    _scheduleCloudPush();
    final current = itemById(item.id);
    if (current != null && current.status != WorkStatus.completed) {
      _cancelPendingAutoArchive(item.id);
    } else {
      _scheduleAutoArchiveIfNeeded(before, current);
    }
  }

  bool _canAutoArchive(WorkItem item) =>
      item.type == WorkItemType.task && item.parentId != null;

  void _scheduleAutoArchiveIfNeeded(WorkItem before, WorkItem? current) {
    if (current == null ||
        before.isCompleted ||
        current.status != WorkStatus.completed ||
        !_canAutoArchive(current)) {
      return;
    }
    _autoArchiveTimers.remove(current.id)?.cancel();
    _autoArchiveSnapshots[current.id] = before;
    autoArchiveNotice = AutoArchiveNotice(
      itemId: current.id,
      title: current.title,
      sequence: ++_autoArchiveNoticeSequence,
    );
    notifyListeners();
    _autoArchiveTimers[current.id] = Timer(const Duration(seconds: 5), () {
      unawaited(_commitPendingAutoArchive(current.id));
    });
  }

  Future<void> _commitPendingAutoArchive(String itemId) async {
    _autoArchiveTimers.remove(itemId)?.cancel();
    final current = itemById(itemId);
    if (current == null || current.status != WorkStatus.completed) {
      _autoArchiveSnapshots.remove(itemId);
      if (autoArchiveNotice?.itemId == itemId) {
        autoArchiveNotice = null;
      }
      return;
    }
    await repository.updateWorkItem(
      current.copyWith(
        status: WorkStatus.archived,
        gtdStatus: GtdStatus.archived,
      ),
    );
    _autoArchiveSnapshots.remove(itemId);
    if (autoArchiveNotice?.itemId == itemId) {
      autoArchiveNotice = null;
    }
    await refreshWorkItemsAndLayouts();
    _scheduleCloudPush();
  }

  Future<void> undoAutoArchive(String itemId) async {
    _autoArchiveTimers.remove(itemId)?.cancel();
    final before = _autoArchiveSnapshots.remove(itemId);
    final current = itemById(itemId);
    if (before == null || current == null) return;
    await repository.updateWorkItem(
      current.copyWith(
        status: before.status,
        gtdStatus: before.gtdStatus,
        checklistDone: before.checklistDone,
      ),
    );
    if (autoArchiveNotice?.itemId == itemId) {
      autoArchiveNotice = null;
    }
    _setMessage('Completion undone: ${current.title}');
    await refreshWorkItemsAndLayouts();
    _scheduleCloudPush();
  }

  void _cancelPendingAutoArchive(String itemId) {
    _autoArchiveTimers.remove(itemId)?.cancel();
    _autoArchiveSnapshots.remove(itemId);
    if (autoArchiveNotice?.itemId == itemId) {
      autoArchiveNotice = null;
    }
  }

  Future<void> unarchiveWorkItem(WorkItem item) async {
    _cancelPendingAutoArchive(item.id);
    await repository.updateWorkItem(
      item.copyWith(
        status: WorkStatus.completed,
        gtdStatus: GtdStatus.completed,
      ),
    );
    _setMessage('Unarchived: ${item.title}');
    await refreshWorkItemsAndLayouts();
    _scheduleCloudPush();
  }

  Future<void> deleteWorkItem(WorkItem item) async {
    await repository.deleteWorkItem(item);
    await refreshWorkItemsAndLayouts();
    _scheduleCloudPush();
  }

  Future<void> applyDrop({
    required String sourceId,
    String? targetId,
    required DropIntent intent,
  }) async {
    await repository.applyDrop(
      sourceId: sourceId,
      targetId: targetId,
      intent: intent,
    );
    await refreshWorkItemsAndLayouts();
    _scheduleCloudPush();
  }

  CanvasLayout layoutFor(
    WorkItem item,
    CanvasViewKind viewKind, {
    double x = 80,
    double y = 80,
  }) {
    final source = viewKind == CanvasViewKind.bigPicture
        ? bigPictureLayouts
        : mindMapLayouts;
    return source[item.id] ??
        repository.defaultLayout(
          itemId: item.id,
          viewKind: viewKind,
          deviceClass: deviceClass,
          x: x,
          y: y,
        );
  }

  Future<void> saveLayout(CanvasLayout layout) async {
    final saved = await repository.saveLayout(layout);
    if (layout.viewKind == CanvasViewKind.bigPicture) {
      bigPictureLayouts = {...bigPictureLayouts, saved.itemId: saved};
    } else {
      mindMapLayouts = {...mindMapLayouts, saved.itemId: saved};
    }
    notifyListeners();
    _scheduleCloudPush();
  }

  Future<JournalEntry> getOrCreateJournal(String dateKey) async {
    final entry = await repository.getOrCreateJournal(dateKey);
    await refreshJournals();
    _scheduleCloudPush();
    return entry;
  }

  Future<JournalEntry> saveJournal(
    JournalEntry entry, {
    bool notifyGlobal = true,
  }) async {
    final saved = await repository.saveJournal(entry);
    journals = [saved, ...journals.where((value) => value.id != saved.id)]
      ..sort((a, b) => b.entryDate.compareTo(a.entryDate));
    if (notifyGlobal) notifyListeners();
    _scheduleCloudPush();
    return saved;
  }

  Future<void> deleteJournal(JournalEntry entry) async {
    await repository.deleteJournal(entry);
    await refreshJournals();
    _scheduleCloudPush();
  }

  Future<void> snapshotJournal(JournalEntry entry) =>
      repository.snapshotJournal(entry);

  Future<List<JournalVersion>> journalVersions(String journalId) =>
      repository.journalVersions(journalId);

  void beginJournalEdit(String journalId) {
    editingJournalIds.add(journalId);
  }

  Future<void> endJournalEdit(String journalId) async {
    editingJournalIds.remove(journalId);
    // Publish the silently autosaved journal to the rest of the UI once when
    // editing ends. Let cloud reconciliation continue without blocking the
    // editor from closing.
    notifyListeners();
    syncService.schedulePush(delay: const Duration(milliseconds: 120));
  }

  Future<Habit> createHabit({
    required String title,
    required HabitKind kind,
    required double monthGoal,
    String unit = '',
    String notes = '',
    String? colorHex,
    String? textColorHex,
  }) async {
    final habit = await repository.createHabit(
      title: title,
      kind: kind,
      monthGoal: monthGoal,
      unit: unit,
      notes: notes,
      colorHex: colorHex,
      textColorHex: textColorHex,
    );
    await refreshHabits();
    _scheduleCloudPush();
    return habit;
  }

  Future<void> updateHabit(Habit habit) async {
    await repository.updateHabit(habit);
    await refreshHabits();
    _scheduleCloudPush();
  }

  Future<void> deleteHabit(Habit habit) async {
    await repository.deleteHabit(habit);
    await refreshHabits();
    _scheduleCloudPush();
  }

  Future<void> reorderHabits(List<Habit> ordered) async {
    await repository.reorderHabits(ordered);
    await refreshHabits();
    _scheduleCloudPush();
  }

  Future<void> setHabitValue(Habit habit, String dateKey, double value) async {
    await repository.setHabitValue(habit, dateKey, value);
    await refreshHabits();
    _scheduleCloudPush();
  }

  Future<NorthStarNote> createNorthStarNote({
    required String title,
    String body = '',
  }) async {
    final note = await repository.createNorthStarNote(title: title, body: body);
    await refreshNorthStar();
    _scheduleCloudPush();
    return note;
  }

  Future<void> updateNorthStarNote(NorthStarNote note) async {
    await repository.updateNorthStarNote(note);
    await refreshNorthStar();
    _scheduleCloudPush();
  }

  Future<void> deleteNorthStarNote(NorthStarNote note) async {
    await repository.deleteNorthStarNote(note);
    await refreshNorthStar();
    _scheduleCloudPush();
  }

  Future<RewardRank> createRewardRank({
    required String name,
    required int minimumPoints,
    String icon = '⭐',
    String colorHex = '#6750A4',
  }) async {
    final rank = await repository.createRewardRank(
      name: name,
      minimumPoints: minimumPoints,
      icon: icon,
      colorHex: colorHex,
    );
    await refreshRewards();
    _scheduleCloudPush();
    return rank;
  }

  Future<void> updateRewardRank(RewardRank rank) async {
    await repository.updateRewardRank(rank);
    await refreshRewards();
    _scheduleCloudPush();
  }

  Future<void> deleteRewardRank(RewardRank rank) async {
    await repository.deleteRewardRank(rank);
    await refreshRewards();
    _scheduleCloudPush();
  }

  Future<StudyTable> createStudyTable(String title) async {
    final table = await repository.createStudyTable(title: title);
    await refreshStudyTables();
    _scheduleCloudPush();
    return table;
  }

  Future<void> updateStudyTable(StudyTable table) async {
    await repository.updateStudyTable(table);
    await refreshStudyTables();
    _scheduleCloudPush();
  }

  Future<void> deleteStudyTable(StudyTable table) async {
    await repository.deleteStudyTable(table);
    await refreshStudyTables();
    _scheduleCloudPush();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await database.setSetting('theme_mode', mode.name);
    notifyListeners();
    _scheduleCloudPush();
  }

  Future<void> setAccentColor(int value) async {
    accentColorValue = value;
    await database.setSetting('accent_color', value.toString());
    notifyListeners();
    _scheduleCloudPush();
  }

  Future<void> setTopBarColor(int value) async {
    topBarColorValue = value;
    await database.setSetting('top_bar_color', value.toString());
    applyTopBarThemeColor(value);
    notifyListeners();
    _scheduleCloudPush();
  }

  Future<void> setBackgroundColor(int value) async {
    backgroundColorValue = value;
    await database.setSetting('background_color', value.toString());
    notifyListeners();
    _scheduleCloudPush();
  }

  Future<void> setCardColor(int value) async {
    cardColorValue = value;
    await database.setSetting('card_color', value.toString());
    notifyListeners();
    _scheduleCloudPush();
  }

  Future<void> setTextColor(int value) async {
    textColorValue = value;
    await database.setSetting('text_color', value.toString());
    notifyListeners();
    _scheduleCloudPush();
  }

  Future<void> setFontScale(double value) async {
    fontScale = value.clamp(0.8, 1.6).toDouble();
    await database.setSetting('font_scale', fontScale.toString());
    notifyListeners();
    _scheduleCloudPush();
  }

  Future<void> setFontFamily(String value) async {
    fontFamily = value;
    await database.setSetting('font_family', value);
    notifyListeners();
    _scheduleCloudPush();
  }

  Future<void> resetAppearance() async {
    themeMode = ThemeMode.light;
    accentColorValue = 0xFF4CAF7A;
    topBarColorValue = 0;
    backgroundColorValue = 0;
    cardColorValue = 0;
    textColorValue = 0;
    fontScale = 1.0;
    fontFamily = defaultTargetPlatform == TargetPlatform.android ? 'Roboto' : 'Segoe UI';
    await database.setSetting('theme_mode', themeMode.name);
    await database.setSetting('accent_color', accentColorValue.toString());
    await database.setSetting('top_bar_color', '0');
    applyTopBarThemeColor(0);
    await database.setSetting('background_color', '0');
    await database.setSetting('card_color', '0');
    await database.setSetting('text_color', '0');
    await database.setSetting('font_scale', '1.0');
    await database.setSetting('font_family', fontFamily);
    notifyListeners();
  }

  Future<void> setDailySessionGoal(int value) async {
    dailySessionGoal = value.clamp(1, 200).toInt();
    await database.setSetting(
      'daily_session_goal',
      dailySessionGoal.toString(),
    );
    notifyListeners();
  }

  Future<void> setDefaultSessionMinutes(int value) async {
    defaultSessionMinutes = value.clamp(1, 720).toInt();
    await database.setSetting(
      'default_session_minutes',
      defaultSessionMinutes.toString(),
    );
    notifyListeners();
  }

  Future<void> setWeeklyFocusGoals({
    required int sessions,
    required int days,
    int? minutesPerSession,
  }) async {
    weeklySessionGoal = sessions.clamp(1, 1400).toInt();
    weeklyFocusDaysGoal = days.clamp(1, 7).toInt();
    weeklySessionMinutes = (minutesPerSession ?? weeklySessionMinutes)
        .clamp(1, 720)
        .toInt();
    await database.setSetting(
      'weekly_session_goal',
      weeklySessionGoal.toString(),
    );
    await database.setSetting(
      'weekly_focus_days_goal',
      weeklyFocusDaysGoal.toString(),
    );
    await database.setSetting(
      'weekly_session_minutes',
      weeklySessionMinutes.toString(),
    );
    notifyListeners();
  }

  Future<void> setMonthlyFocusGoals({
    required int sessions,
    required int days,
    int? minutesPerSession,
  }) async {
    monthlySessionGoal = sessions.clamp(1, 6200).toInt();
    monthlyFocusDaysGoal = days.clamp(1, 31).toInt();
    monthlySessionMinutes = (minutesPerSession ?? monthlySessionMinutes)
        .clamp(1, 720)
        .toInt();
    await database.setSetting(
      'monthly_session_goal',
      monthlySessionGoal.toString(),
    );
    await database.setSetting(
      'monthly_focus_days_goal',
      monthlyFocusDaysGoal.toString(),
    );
    await database.setSetting(
      'monthly_session_minutes',
      monthlySessionMinutes.toString(),
    );
    notifyListeners();
  }

  Future<void> setDashboardPalette(int index) async {
    dashboardPaletteIndex = index.clamp(0, 4).toInt();
    await database.setSetting(
      'dashboard_palette',
      dashboardPaletteIndex.toString(),
    );
    notifyListeners();
  }

  Future<String?> readUiSetting(String key) => database.getSetting(key);

  Future<void> writeUiSetting(String key, String value) async {
    await database.setSetting(key, value);
    _scheduleCloudPush();
  }

  Future<void> writeLocalUiSetting(String key, String value) async {
    await database.setSetting(key, value, enqueue: false);
  }

  Future<void> setMindMapTextColor(String itemId, String? hex) async {
    final next = Map<String, String>.from(mindMapTextColors);
    if (hex == null || hex.isEmpty) {
      next.remove(itemId);
    } else {
      next[itemId] = hex;
    }
    mindMapTextColors = Map.unmodifiable(next);
    await database.setSetting('mind_map_text_colors_json', jsonEncode(next));
    notifyListeners();
  }

  double northStarTitleScale(String noteId) =>
      (northStarTitleScales[noteId] ?? 1.0).clamp(0.65, 2.0).toDouble();

  double northStarBodyScale(String noteId) =>
      (northStarBodyScales[noteId] ?? 1.0).clamp(0.65, 2.0).toDouble();

  Future<void> setNorthStarTextScales(
    String noteId, {
    required double titleScale,
    required double bodyScale,
  }) async {
    final nextTitles = Map<String, double>.from(northStarTitleScales)
      ..[noteId] = titleScale.clamp(0.65, 2.0).toDouble();
    final nextBodies = Map<String, double>.from(northStarBodyScales)
      ..[noteId] = bodyScale.clamp(0.65, 2.0).toDouble();
    northStarTitleScales = Map.unmodifiable(nextTitles);
    northStarBodyScales = Map.unmodifiable(nextBodies);
    await database.setSetting(
      'northstar_title_scales_json',
      jsonEncode(nextTitles),
    );
    await database.setSetting(
      'northstar_body_scales_json',
      jsonEncode(nextBodies),
    );
    notifyListeners();
  }

  int completedSessionCountBetween(DateTime start, DateTime endExclusive) {
    return sessions.where((session) {
      final local = session.startedAt.toLocal();
      return session.completed &&
          session.mode != TimerMode.stopwatch &&
          !local.isBefore(start) &&
          local.isBefore(endExclusive);
    }).length;
  }

  int focusMinutesBetween(DateTime start, DateTime endExclusive) {
    return sessions
        .where((session) {
          final local = session.startedAt.toLocal();
          return session.completed &&
              session.mode != TimerMode.stopwatch &&
              !local.isBefore(start) &&
              local.isBefore(endExclusive);
        })
        .fold<int>(
          0,
          (sum, session) => sum + (session.elapsedSeconds / 60).round(),
        );
  }

  int focusDaysBetween(DateTime start, DateTime endExclusive) {
    return sessions
        .where((session) {
          final local = session.startedAt.toLocal();
          return session.completed &&
              session.mode != TimerMode.stopwatch &&
              !local.isBefore(start) &&
              local.isBefore(endExclusive);
        })
        .map((session) {
          final local = session.startedAt.toLocal();
          return DateTime(local.year, local.month, local.day);
        })
        .toSet()
        .length;
  }

  Future<void> setHabitNameWidth(double value) async {
    habitNameWidth = value.clamp(190, 520).toDouble();
    await database.setSetting('habit_name_width', habitNameWidth.toString());
    notifyListeners();
  }

  Future<void> setHabitRowHeight(String habitId, double value) async {
    final next = Map<String, double>.from(habitRowHeights)
      ..[habitId] = value.clamp(88, 520).toDouble();
    habitRowHeights = Map.unmodifiable(next);
    await database.setSetting('habit_row_heights_json', jsonEncode(next));
    notifyListeners();
  }

  Future<void> setHabitTotalsBold(bool value) async {
    habitTotalsBold = value;
    await database.setSetting('habit_totals_bold', value.toString());
    notifyListeners();
  }

  Future<void> setRewardRules({
    required int perMinute,
    required Map<WorkItemType, int> itemValues,
    int? perHabitCheckIn,
  }) async {
    pointsPerFocusMinute = perMinute.clamp(0, 1000).toInt();
    pointsPerHabitCheckIn = (perHabitCheckIn ?? pointsPerHabitCheckIn)
        .clamp(0, 10000)
        .toInt();
    itemPointValues = Map.unmodifiable(itemValues);
    await database.setSetting(
      'points_per_focus_minute',
      pointsPerFocusMinute.toString(),
    );
    await database.setSetting(
      'points_per_habit_checkin',
      pointsPerHabitCheckIn.toString(),
    );
    for (final entry in itemPointValues.entries) {
      await database.setSetting(
        'points_${entry.key.name}',
        entry.value.toString(),
      );
    }
    notifyListeners();
  }

  Future<void> saveTabPreferences(List<TabPreference> values) async {
    tabPreferences = List.unmodifiable(values);
    await database.setSetting(
      'tab_preferences_json',
      jsonEncode(values.map((item) => item.toMap()).toList()),
    );
    notifyListeners();
  }

  Future<void> saveJournalPrompts(List<Map<String, dynamic>> prompts) async {
    journalPrompts = List.unmodifiable(prompts);
    await database.setSetting('journal_prompts_json', jsonEncode(prompts));
    notifyListeners();
  }

  void _setMessage(String value) {
    message = value;
    _messageClearTimer?.cancel();
    notifyListeners();
    _messageClearTimer = Timer(const Duration(seconds: 5), () {
      if (message != value) return;
      message = null;
      notifyListeners();
    });
  }

  Future<MigrationImportResult> importMigration() async {
    final result = await repository.importMigrationJsonFile();
    await _loadSettings();
    await refreshAll();
    await timerEngine.reloadFromDatabase();
    await syncService.syncNow();
    _setMessage(
      'Autivra migration applied: ${result.totalChanged} local records changed.',
    );
    return result;
  }

  Future<int> importV4() async {
    final count = await repository.importV4JsonFile();
    await refreshAll();
    _setMessage('Imported $count records without duplicating existing IDs.');
    return count;
  }

  Future<void> exportBackup() async {
    final file = await repository.exportBackup();
    _setMessage(
      file == null ? 'Export cancelled.' : 'Backup downloaded: $file',
    );
  }


  Future<void> exportForAutivra4() async {
    // Pull any newer phone/cloud edits first so the native Autivra4 update
    // file represents the latest reconciled SlamDone state on this PC.
    await syncService.syncNow();
    final file = await repository.exportForAutivra4();
    _setMessage(
      file == null
          ? 'Autivra4 export cancelled.'
          : 'Autivra4-compatible update JSON downloaded: $file',
    );
  }

  Future<void> setFocusPanelHidden(bool hidden) async {
    focusPanelHidden = hidden;
    await database.setSetting('focus_panel_hidden', hidden.toString());
  }

  List<TimeSession> get todayFocusSessions {
    final now = DateTime.now();
    final result = sessions.where((session) {
      final local = session.startedAt.toLocal();
      return session.completed &&
          session.mode != TimerMode.stopwatch &&
          local.year == now.year &&
          local.month == now.month &&
          local.day == now.day;
    }).toList();
    result.sort((a, b) {
      final byStart = a.startedAt.compareTo(b.startedAt);
      if (byStart != 0) return byStart;
      final byEnd = a.endedAt.compareTo(b.endedAt);
      if (byEnd != 0) return byEnd;
      return a.id.compareTo(b.id);
    });
    return result;
  }

  int get todaySessionCount => todayFocusSessions.length;

  int get todayMinutes => todayFocusSessions.fold<int>(
    0,
    (sum, session) => sum + (session.elapsedSeconds / 60).round(),
  );

  int get totalRewardPoints {
    final focusPoints = sessions
        .where((session) => session.completed)
        .fold<int>(
          0,
          (sum, session) =>
              sum +
              (session.elapsedSeconds / 60).round() * pointsPerFocusMinute,
        );
    final itemPoints = workItems
        .where((item) => item.isCompleted && !item.isDeleted)
        .fold<int>(0, (sum, item) => sum + (itemPointValues[item.type] ?? 0));
    final habitPoints =
        habitEntries
            .where((entry) => entry.deletedAt == null && entry.value > 0)
            .length *
        pointsPerHabitCheckIn;
    return focusPoints + itemPoints + habitPoints;
  }

  RewardRank? get currentRewardRank {
    if (rewardRanks.isEmpty) return null;
    final sorted = [...rewardRanks]
      ..sort((a, b) => a.minimumPoints.compareTo(b.minimumPoints));
    RewardRank current = sorted.first;
    for (final rank in sorted) {
      if (totalRewardPoints >= rank.minimumPoints) current = rank;
    }
    return current;
  }

  int get focusDayStreak {
    final completedDays = sessions.where((session) => session.completed).map((
      session,
    ) {
      final value = session.startedAt.toLocal();
      return DateTime(value.year, value.month, value.day);
    }).toSet();
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    if (!completedDays.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (completedDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<void> launchFloatingTimer() async => showFloatingTimer();

  void showFloatingTimer() {
    floatingTimerVisible = true;
    _setMessage('Floating timer opened inside SlamDone.');
  }

  void hideFloatingTimer() {
    floatingTimerVisible = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _messageClearTimer?.cancel();
    for (final timer in _autoArchiveTimers.values) {
      timer.cancel();
    }
    _autoArchiveTimers.clear();
    syncService.removeListener(notifyListeners);
    timerEngine.removeListener(_onTimerChanged);
    syncService.dispose();
    timerEngine.dispose();
    super.dispose();
  }
}
