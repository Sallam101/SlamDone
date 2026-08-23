import 'dart:convert';

String isoNow() => DateTime.now().toUtc().toIso8601String();

DateTime? parseDateTime(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toUtc();
}

bool intToBool(Object? value) => value == true || value == 1 || value == '1';
int boolToInt(bool value) => value ? 1 : 0;

enum WorkItemType { goal, milestone, project, subproject, module, task }

enum WorkStatus { active, completed, archived }

enum WorkItemVisibilityFilter {
  hideArchived,
  activeOnly,
  completedOnly,
  archivedOnly,
  completedAndArchived,
  notCompleted,
  all,
}

enum PriorityLevel { normal, important, urgent }

enum EnergyLevel { none, low, high }

enum GtdStatus { inbox, toDo, inProgress, completed, archived }

enum CanvasViewKind { bigPicture, mindMap }

enum DeviceClass { desktop, mobile }

enum TimerMode { focus, general, stopwatch }

enum TimerOwner { main, floating }

enum HabitKind { checkbox, number }

enum AppSection {
  overview,
  doFirst,
  bigPicture,
  mindMap,
  focus,
  tasks,
  calendar,
  habits,
  journal,
  northStar,
  rewards,
  gtdPara,
  studyTables,
  settings,
}

extension EnumNameParsing on String {
  WorkItemType asWorkItemType() => WorkItemType.values.firstWhere(
    (value) => value.name == this,
    orElse: () => WorkItemType.task,
  );

  WorkStatus asWorkStatus() => WorkStatus.values.firstWhere(
    (value) => value.name == this,
    orElse: () => WorkStatus.active,
  );

  PriorityLevel asPriorityLevel() => PriorityLevel.values.firstWhere(
    (value) => value.name == this,
    orElse: () => PriorityLevel.normal,
  );

  EnergyLevel asEnergyLevel() => EnergyLevel.values.firstWhere(
    (value) => value.name == this,
    orElse: () => EnergyLevel.none,
  );

  GtdStatus asGtdStatus() => GtdStatus.values.firstWhere(
    (value) => value.name == this,
    orElse: () => GtdStatus.inbox,
  );

  TimerMode asTimerMode() => TimerMode.values.firstWhere(
    (value) => value.name == this,
    orElse: () => TimerMode.general,
  );

  TimerOwner asTimerOwner() => TimerOwner.values.firstWhere(
    (value) => value.name == this,
    orElse: () => TimerOwner.main,
  );
}

class WorkItem {
  const WorkItem({
    required this.id,
    required this.title,
    required this.type,
    required this.sortKey,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
    required this.deviceId,
    this.ownerId,
    this.parentId,
    this.notes = '',
    this.dueDate,
    this.priority = PriorityLevel.normal,
    this.urgent = false,
    this.status = WorkStatus.active,
    this.gtdStatus = GtdStatus.inbox,
    this.paraCategory = 'Projects',
    this.checklistTotal = 0,
    this.checklistDone = 0,
    this.timerMinutes = 25,
    this.sessionGoal = 1,
    this.recurring = false,
    this.recurrenceDays = 1,
    this.energyLevel = EnergyLevel.none,
    this.childColumns = 4,
    this.titleScale = 1.0,
    this.titleBold = true,
    this.textColorHex,
    this.folder = '',
    this.deletedAt,
  });

  final String id;
  final String? ownerId;
  final String title;
  final WorkItemType type;
  final String? parentId;
  final double sortKey;
  final String notes;
  final DateTime? dueDate;
  final PriorityLevel priority;
  final bool urgent;
  final WorkStatus status;
  final GtdStatus gtdStatus;
  final String paraCategory;
  final int checklistTotal;
  final int checklistDone;
  final int timerMinutes;
  final int sessionGoal;
  final bool recurring;
  final int recurrenceDays;
  final EnergyLevel energyLevel;
  final int childColumns;
  final double titleScale;
  final bool titleBold;
  final String? textColorHex;
  final String folder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;
  final String deviceId;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
  bool get isArchived => status == WorkStatus.archived;
  bool get isCompleted =>
      status == WorkStatus.completed || status == WorkStatus.archived;

  bool matchesVisibilityFilter(WorkItemVisibilityFilter filter) => switch (filter) {
    WorkItemVisibilityFilter.hideArchived => status != WorkStatus.archived,
    WorkItemVisibilityFilter.activeOnly => status == WorkStatus.active,
    WorkItemVisibilityFilter.completedOnly => status == WorkStatus.completed,
    WorkItemVisibilityFilter.archivedOnly => status == WorkStatus.archived,
    WorkItemVisibilityFilter.completedAndArchived =>
      status == WorkStatus.completed || status == WorkStatus.archived,
    WorkItemVisibilityFilter.notCompleted => status != WorkStatus.completed,
    WorkItemVisibilityFilter.all => true,
  };
  int get checklistLeft =>
      (checklistTotal - checklistDone).clamp(0, 200).toInt();
  double get progress => checklistTotal <= 0
      ? (isCompleted ? 1.0 : 0.0)
      : checklistDone.clamp(0, checklistTotal) / checklistTotal;

  WorkItem copyWith({
    String? ownerId,
    String? title,
    WorkItemType? type,
    Object? parentId = _sentinel,
    double? sortKey,
    String? notes,
    Object? dueDate = _sentinel,
    PriorityLevel? priority,
    bool? urgent,
    WorkStatus? status,
    GtdStatus? gtdStatus,
    String? paraCategory,
    int? checklistTotal,
    int? checklistDone,
    int? timerMinutes,
    int? sessionGoal,
    bool? recurring,
    int? recurrenceDays,
    EnergyLevel? energyLevel,
    int? childColumns,
    double? titleScale,
    bool? titleBold,
    Object? textColorHex = _sentinel,
    String? folder,
    DateTime? updatedAt,
    int? revision,
    String? deviceId,
    Object? deletedAt = _sentinel,
  }) {
    final nextTotal = (checklistTotal ?? this.checklistTotal)
        .clamp(0, 200)
        .toInt();
    final nextDone = (checklistDone ?? this.checklistDone)
        .clamp(0, nextTotal)
        .toInt();
    return WorkItem(
      id: id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      type: type ?? this.type,
      parentId: identical(parentId, _sentinel)
          ? this.parentId
          : parentId as String?,
      sortKey: sortKey ?? this.sortKey,
      notes: notes ?? this.notes,
      dueDate: identical(dueDate, _sentinel)
          ? this.dueDate
          : dueDate as DateTime?,
      priority: priority ?? this.priority,
      urgent: urgent ?? this.urgent,
      status: status ?? this.status,
      gtdStatus: gtdStatus ?? this.gtdStatus,
      paraCategory: paraCategory ?? this.paraCategory,
      checklistTotal: nextTotal,
      checklistDone: nextDone,
      timerMinutes: (timerMinutes ?? this.timerMinutes).clamp(1, 720).toInt(),
      sessionGoal: (sessionGoal ?? this.sessionGoal).clamp(1, 200).toInt(),
      recurring: recurring ?? this.recurring,
      recurrenceDays: (recurrenceDays ?? this.recurrenceDays)
          .clamp(1, 3650)
          .toInt(),
      energyLevel: energyLevel ?? this.energyLevel,
      childColumns: (childColumns ?? this.childColumns).clamp(1, 12).toInt(),
      titleScale: (titleScale ?? this.titleScale).clamp(0.75, 2.0).toDouble(),
      titleBold: titleBold ?? this.titleBold,
      textColorHex: identical(textColorHex, _sentinel)
          ? this.textColorHex
          : textColorHex as String?,
      folder: folder ?? this.folder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      revision: revision ?? this.revision,
      deviceId: deviceId ?? this.deviceId,
      deletedAt: identical(deletedAt, _sentinel)
          ? this.deletedAt
          : deletedAt as DateTime?,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'owner_id': ownerId,
    'title': title,
    'type': type.name,
    'parent_id': parentId,
    'sort_key': sortKey,
    'notes': notes,
    'due_date': dueDate?.toUtc().toIso8601String(),
    'priority': priority.name,
    'urgent': boolToInt(urgent),
    'status': status.name,
    'gtd_status': gtdStatus.name,
    'para_category': paraCategory,
    'checklist_total': checklistTotal,
    'checklist_done': checklistDone,
    'timer_minutes': timerMinutes,
    'session_goal': sessionGoal,
    'recurring': boolToInt(recurring),
    'recurrence_days': recurrenceDays,
    'energy_level': energyLevel.name,
    'child_columns': childColumns,
    'title_scale': titleScale,
    'title_bold': boolToInt(titleBold),
    'text_color_hex': textColorHex,
    'folder': folder,
    'created_at': createdAt.toUtc().toIso8601String(),
    'client_updated_at': updatedAt.toUtc().toIso8601String(),
    'revision': revision,
    'device_id': deviceId,
    'deleted_at': deletedAt?.toUtc().toIso8601String(),
  };

  factory WorkItem.fromMap(Map<String, Object?> map) {
    final legacyPriority = (map['priority'] as String? ?? 'normal')
        .asPriorityLevel();
    return WorkItem(
      id: map['id']! as String,
      ownerId: map['owner_id'] as String?,
      title: (map['title'] as String?)?.trim().isNotEmpty == true
          ? map['title']! as String
          : 'Untitled',
      type: (map['type'] as String? ?? 'task').asWorkItemType(),
      parentId: map['parent_id'] as String?,
      sortKey: (map['sort_key'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String? ?? '',
      dueDate: parseDateTime(map['due_date']),
      priority: legacyPriority,
      urgent: map.containsKey('urgent')
          ? intToBool(map['urgent'])
          : legacyPriority == PriorityLevel.urgent,
      status: (map['status'] as String? ?? 'active').asWorkStatus(),
      gtdStatus: (map['gtd_status'] as String? ?? 'inbox').asGtdStatus(),
      paraCategory: map['para_category'] as String? ?? 'Projects',
      checklistTotal: (map['checklist_total'] as num?)?.toInt() ?? 0,
      checklistDone: (map['checklist_done'] as num?)?.toInt() ?? 0,
      timerMinutes: (map['timer_minutes'] as num?)?.toInt() ?? 25,
      sessionGoal: (map['session_goal'] as num?)?.toInt() ?? 1,
      recurring: intToBool(map['recurring']),
      recurrenceDays: (map['recurrence_days'] as num?)?.toInt() ?? 1,
      energyLevel: (map['energy_level'] as String? ?? 'none').asEnergyLevel(),
      childColumns: (map['child_columns'] as num?)?.toInt() ?? 4,
      titleScale: (map['title_scale'] as num?)?.toDouble() ?? 1.0,
      titleBold: map.containsKey('title_bold')
          ? intToBool(map['title_bold'])
          : true,
      textColorHex: map['text_color_hex'] as String?,
      folder: map['folder'] as String? ?? '',
      createdAt: parseDateTime(map['created_at']) ?? DateTime.now().toUtc(),
      updatedAt:
          parseDateTime(map['client_updated_at']) ??
          parseDateTime(map['updated_at']) ??
          DateTime.now().toUtc(),
      revision: (map['revision'] as num?)?.toInt() ?? 1,
      deviceId: map['device_id'] as String? ?? 'unknown',
      deletedAt: parseDateTime(map['deleted_at']),
    );
  }
}

class CanvasLayout {
  const CanvasLayout({
    required this.id,
    required this.itemId,
    required this.viewKind,
    required this.deviceClass,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.updatedAt,
    required this.revision,
    required this.deviceId,
    this.ownerId,
    this.collapsed = false,
    this.locked = false,
    this.colorHex,
    this.deletedAt,
  });

  final String id;
  final String? ownerId;
  final String itemId;
  final CanvasViewKind viewKind;
  final DeviceClass deviceClass;
  final double x;
  final double y;
  final double width;
  final double height;
  final bool collapsed;
  final bool locked;
  final String? colorHex;
  final DateTime updatedAt;
  final int revision;
  final String deviceId;
  final DateTime? deletedAt;

  CanvasLayout copyWith({
    String? ownerId,
    double? x,
    double? y,
    double? width,
    double? height,
    bool? collapsed,
    bool? locked,
    Object? colorHex = _sentinel,
    DateTime? updatedAt,
    int? revision,
    String? deviceId,
    Object? deletedAt = _sentinel,
  }) {
    return CanvasLayout(
      id: id,
      ownerId: ownerId ?? this.ownerId,
      itemId: itemId,
      viewKind: viewKind,
      deviceClass: deviceClass,
      x: x ?? this.x,
      y: y ?? this.y,
      width: (width ?? this.width).clamp(150, 1100).toDouble(),
      height: (height ?? this.height).clamp(72, 760).toDouble(),
      collapsed: collapsed ?? this.collapsed,
      locked: locked ?? this.locked,
      colorHex: identical(colorHex, _sentinel)
          ? this.colorHex
          : colorHex as String?,
      updatedAt: updatedAt ?? this.updatedAt,
      revision: revision ?? this.revision,
      deviceId: deviceId ?? this.deviceId,
      deletedAt: identical(deletedAt, _sentinel)
          ? this.deletedAt
          : deletedAt as DateTime?,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'owner_id': ownerId,
    'item_id': itemId,
    'view_kind': viewKind.name,
    'device_class': deviceClass.name,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'collapsed': boolToInt(collapsed),
    'locked': boolToInt(locked),
    'color_hex': colorHex,
    'client_updated_at': updatedAt.toUtc().toIso8601String(),
    'revision': revision,
    'device_id': deviceId,
    'deleted_at': deletedAt?.toUtc().toIso8601String(),
  };

  Map<String, Object?> toCloudMap() {
    final map = toMap();
    map['collapsed'] = collapsed;
    map['locked'] = locked;
    return map;
  }

  factory CanvasLayout.fromMap(Map<String, Object?> map) => CanvasLayout(
    id: map['id']! as String,
    ownerId: map['owner_id'] as String?,
    itemId: map['item_id']! as String,
    viewKind: CanvasViewKind.values.firstWhere(
      (value) => value.name == map['view_kind'],
      orElse: () => CanvasViewKind.bigPicture,
    ),
    deviceClass: DeviceClass.values.firstWhere(
      (value) => value.name == map['device_class'],
      orElse: () => DeviceClass.desktop,
    ),
    x: (map['x'] as num?)?.toDouble() ?? 0,
    y: (map['y'] as num?)?.toDouble() ?? 0,
    width: (map['width'] as num?)?.toDouble() ?? 300,
    height: (map['height'] as num?)?.toDouble() ?? 150,
    collapsed: intToBool(map['collapsed']),
    locked: intToBool(map['locked']),
    colorHex: map['color_hex'] as String?,
    updatedAt:
        parseDateTime(map['client_updated_at']) ??
        parseDateTime(map['updated_at']) ??
        DateTime.now().toUtc(),
    revision: (map['revision'] as num?)?.toInt() ?? 1,
    deviceId: map['device_id'] as String? ?? 'unknown',
    deletedAt: parseDateTime(map['deleted_at']),
  );
}

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.entryDate,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
    required this.deviceId,
    this.ownerId,
    this.winBig = '',
    this.feel = '',
    this.grateful = '',
    this.body = '',
    this.regret = '',
    this.pretending = '',
    this.flow = '',
    this.notTolerate = '',
    this.customJson = '{}',
    this.folder = '',
    this.archived = false,
    this.deletedAt,
  });

  final String id;
  final String? ownerId;
  final String entryDate;
  final String winBig;
  final String feel;
  final String grateful;
  final String body;
  final String regret;
  final String pretending;
  final String flow;
  final String notTolerate;
  final String customJson;
  final String folder;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;
  final String deviceId;
  final DateTime? deletedAt;

  Map<String, String> get customAnswers {
    try {
      final decoded = jsonDecode(customJson);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
        );
      }
    } catch (_) {}
    return <String, String>{};
  }

  JournalEntry copyWith({
    String? ownerId,
    String? winBig,
    String? feel,
    String? grateful,
    String? body,
    String? regret,
    String? pretending,
    String? flow,
    String? notTolerate,
    String? customJson,
    String? folder,
    bool? archived,
    DateTime? updatedAt,
    int? revision,
    String? deviceId,
    Object? deletedAt = _sentinel,
  }) {
    return JournalEntry(
      id: id,
      ownerId: ownerId ?? this.ownerId,
      entryDate: entryDate,
      winBig: winBig ?? this.winBig,
      feel: feel ?? this.feel,
      grateful: grateful ?? this.grateful,
      body: body ?? this.body,
      regret: regret ?? this.regret,
      pretending: pretending ?? this.pretending,
      flow: flow ?? this.flow,
      notTolerate: notTolerate ?? this.notTolerate,
      customJson: customJson ?? this.customJson,
      folder: folder ?? this.folder,
      archived: archived ?? this.archived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      revision: revision ?? this.revision,
      deviceId: deviceId ?? this.deviceId,
      deletedAt: identical(deletedAt, _sentinel)
          ? this.deletedAt
          : deletedAt as DateTime?,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'owner_id': ownerId,
    'entry_date': entryDate,
    'win_big': winBig,
    'feel': feel,
    'grateful': grateful,
    'body': body,
    'regret': regret,
    'pretending': pretending,
    'flow': flow,
    'not_tolerate': notTolerate,
    'custom_json': customJson,
    'folder': folder,
    'archived': boolToInt(archived),
    'created_at': createdAt.toUtc().toIso8601String(),
    'client_updated_at': updatedAt.toUtc().toIso8601String(),
    'revision': revision,
    'device_id': deviceId,
    'deleted_at': deletedAt?.toUtc().toIso8601String(),
  };

  factory JournalEntry.fromMap(Map<String, Object?> map) => JournalEntry(
    id: map['id']! as String,
    ownerId: map['owner_id'] as String?,
    entryDate: map['entry_date'] as String? ?? '',
    winBig: map['win_big'] as String? ?? '',
    feel: map['feel'] as String? ?? '',
    grateful: map['grateful'] as String? ?? '',
    body: map['body'] as String? ?? '',
    regret: map['regret'] as String? ?? '',
    pretending: map['pretending'] as String? ?? '',
    flow: map['flow'] as String? ?? '',
    notTolerate: map['not_tolerate'] as String? ?? '',
    customJson: map['custom_json'] as String? ?? '{}',
    folder: map['folder'] as String? ?? '',
    archived: intToBool(map['archived']),
    createdAt: parseDateTime(map['created_at']) ?? DateTime.now().toUtc(),
    updatedAt:
        parseDateTime(map['client_updated_at']) ??
        parseDateTime(map['updated_at']) ??
        DateTime.now().toUtc(),
    revision: (map['revision'] as num?)?.toInt() ?? 1,
    deviceId: map['device_id'] as String? ?? 'unknown',
    deletedAt: parseDateTime(map['deleted_at']),
  );
}

class TimeSession {
  const TimeSession({
    required this.id,
    required this.mode,
    required this.title,
    required this.plannedSeconds,
    required this.elapsedSeconds,
    required this.startedAt,
    required this.endedAt,
    required this.completed,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
    required this.deviceId,
    this.ownerId,
    this.workItemId,
    this.notes = '',
    this.deletedAt,
  });

  final String id;
  final String? ownerId;
  final TimerMode mode;
  final String? workItemId;
  final String title;
  final int plannedSeconds;
  final int elapsedSeconds;
  final DateTime startedAt;
  final DateTime endedAt;
  final bool completed;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;
  final String deviceId;
  final DateTime? deletedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'owner_id': ownerId,
    'mode': mode.name,
    'work_item_id': workItemId,
    'title': title,
    'planned_seconds': plannedSeconds,
    'elapsed_seconds': elapsedSeconds,
    'started_at': startedAt.toUtc().toIso8601String(),
    'ended_at': endedAt.toUtc().toIso8601String(),
    'completed': boolToInt(completed),
    'notes': notes,
    'created_at': createdAt.toUtc().toIso8601String(),
    'client_updated_at': updatedAt.toUtc().toIso8601String(),
    'revision': revision,
    'device_id': deviceId,
    'deleted_at': deletedAt?.toUtc().toIso8601String(),
  };

  Map<String, Object?> toCloudMap() {
    final map = toMap();
    map['completed'] = completed;
    return map;
  }

  factory TimeSession.fromMap(Map<String, Object?> map) => TimeSession(
    id: map['id']! as String,
    ownerId: map['owner_id'] as String?,
    mode: (map['mode'] as String? ?? 'general').asTimerMode(),
    workItemId: map['work_item_id'] as String?,
    title: map['title'] as String? ?? 'Session',
    plannedSeconds: (map['planned_seconds'] as num?)?.toInt() ?? 0,
    elapsedSeconds: (map['elapsed_seconds'] as num?)?.toInt() ?? 0,
    startedAt: parseDateTime(map['started_at']) ?? DateTime.now().toUtc(),
    endedAt: parseDateTime(map['ended_at']) ?? DateTime.now().toUtc(),
    completed: intToBool(map['completed']),
    notes: map['notes'] as String? ?? '',
    createdAt: parseDateTime(map['created_at']) ?? DateTime.now().toUtc(),
    updatedAt:
        parseDateTime(map['client_updated_at']) ??
        parseDateTime(map['updated_at']) ??
        DateTime.now().toUtc(),
    revision: (map['revision'] as num?)?.toInt() ?? 1,
    deviceId: map['device_id'] as String? ?? 'unknown',
    deletedAt: parseDateTime(map['deleted_at']),
  );
}

class TimerStateRecord {
  const TimerStateRecord({
    required this.mode,
    required this.owner,
    required this.title,
    required this.durationSeconds,
    required this.remainingSeconds,
    required this.elapsedSeconds,
    required this.running,
    required this.paused,
    required this.updatedAt,
    required this.completionToken,
    this.workItemId,
    this.startedAt,
    this.endAt,
    this.autoRepeat = false,
  });

  final TimerMode mode;
  final TimerOwner owner;
  final String? workItemId;
  final String title;
  final int durationSeconds;
  final int remainingSeconds;
  final int elapsedSeconds;
  final bool running;
  final bool paused;
  final bool autoRepeat;
  final DateTime? startedAt;
  final DateTime? endAt;
  final DateTime updatedAt;
  final String completionToken;

  static TimerStateRecord idle() => TimerStateRecord(
    mode: TimerMode.general,
    owner: TimerOwner.main,
    title: 'General focus',
    durationSeconds: 25 * 60,
    remainingSeconds: 25 * 60,
    elapsedSeconds: 0,
    running: false,
    paused: false,
    updatedAt: DateTime.now().toUtc(),
    completionToken: '',
  );

  TimerStateRecord copyWith({
    TimerMode? mode,
    TimerOwner? owner,
    Object? workItemId = _sentinel,
    String? title,
    int? durationSeconds,
    int? remainingSeconds,
    int? elapsedSeconds,
    bool? running,
    bool? paused,
    bool? autoRepeat,
    Object? startedAt = _sentinel,
    Object? endAt = _sentinel,
    DateTime? updatedAt,
    String? completionToken,
  }) {
    return TimerStateRecord(
      mode: mode ?? this.mode,
      owner: owner ?? this.owner,
      workItemId: identical(workItemId, _sentinel)
          ? this.workItemId
          : workItemId as String?,
      title: title ?? this.title,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      running: running ?? this.running,
      paused: paused ?? this.paused,
      autoRepeat: autoRepeat ?? this.autoRepeat,
      startedAt: identical(startedAt, _sentinel)
          ? this.startedAt
          : startedAt as DateTime?,
      endAt: identical(endAt, _sentinel) ? this.endAt : endAt as DateTime?,
      updatedAt: updatedAt ?? this.updatedAt,
      completionToken: completionToken ?? this.completionToken,
    );
  }

  Map<String, Object?> toMap() => {
    'id': 1,
    'mode': mode.name,
    'owner': owner.name,
    'work_item_id': workItemId,
    'title': title,
    'duration_seconds': durationSeconds,
    'remaining_seconds': remainingSeconds,
    'elapsed_seconds': elapsedSeconds,
    'running': boolToInt(running),
    'paused': boolToInt(paused),
    'auto_repeat': boolToInt(autoRepeat),
    'started_at': startedAt?.toUtc().toIso8601String(),
    'end_at': endAt?.toUtc().toIso8601String(),
    'client_updated_at': updatedAt.toUtc().toIso8601String(),
    'completion_token': completionToken,
  };

  factory TimerStateRecord.fromMap(Map<String, Object?> map) =>
      TimerStateRecord(
        mode: (map['mode'] as String? ?? 'general').asTimerMode(),
        owner: (map['owner'] as String? ?? 'main').asTimerOwner(),
        workItemId: map['work_item_id'] as String?,
        title: map['title'] as String? ?? 'General focus',
        durationSeconds: (map['duration_seconds'] as num?)?.toInt() ?? 1500,
        remainingSeconds: (map['remaining_seconds'] as num?)?.toInt() ?? 1500,
        elapsedSeconds: (map['elapsed_seconds'] as num?)?.toInt() ?? 0,
        running: intToBool(map['running']),
        paused: intToBool(map['paused']),
        autoRepeat: intToBool(map['auto_repeat']),
        startedAt: parseDateTime(map['started_at']),
        endAt: parseDateTime(map['end_at']),
        updatedAt:
            parseDateTime(map['client_updated_at']) ?? DateTime.now().toUtc(),
        completionToken: map['completion_token'] as String? ?? '',
      );
}

class SyncQueueEntry {
  const SyncQueueEntry({
    required this.queueId,
    required this.entityType,
    required this.entityId,
    required this.createdAt,
    required this.attempts,
  });

  final int queueId;
  final String entityType;
  final String entityId;
  final DateTime createdAt;
  final int attempts;

  factory SyncQueueEntry.fromMap(Map<String, Object?> map) => SyncQueueEntry(
    queueId: (map['queue_id'] as num).toInt(),
    entityType: map['entity_type'] as String,
    entityId: map['entity_id'] as String,
    createdAt: parseDateTime(map['created_at']) ?? DateTime.now().toUtc(),
    attempts: (map['attempts'] as num?)?.toInt() ?? 0,
  );
}

class JournalVersion {
  const JournalVersion({
    required this.id,
    required this.journalId,
    required this.snapshotJson,
    required this.createdAt,
  });

  final String id;
  final String journalId;
  final String snapshotJson;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'journal_id': journalId,
    'snapshot_json': snapshotJson,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  JournalEntry decodeEntry() => JournalEntry.fromMap(
    (jsonDecode(snapshotJson) as Map).cast<String, Object?>(),
  );
}

class Habit {
  const Habit({
    required this.id,
    required this.title,
    required this.kind,
    required this.monthGoal,
    required this.sortKey,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
    required this.deviceId,
    this.ownerId,
    this.unit = '',
    this.notes = '',
    this.colorHex,
    this.textColorHex,
    this.deletedAt,
  });

  final String id;
  final String? ownerId;
  final String title;
  final HabitKind kind;
  final double monthGoal;
  final double sortKey;
  final String unit;
  final String notes;
  final String? colorHex;
  final String? textColorHex;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;
  final String deviceId;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Habit copyWith({
    String? ownerId,
    String? title,
    HabitKind? kind,
    double? monthGoal,
    double? sortKey,
    String? unit,
    String? notes,
    Object? colorHex = _sentinel,
    Object? textColorHex = _sentinel,
    DateTime? updatedAt,
    int? revision,
    String? deviceId,
    Object? deletedAt = _sentinel,
  }) {
    return Habit(
      id: id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      monthGoal: monthGoal ?? this.monthGoal,
      sortKey: sortKey ?? this.sortKey,
      unit: unit ?? this.unit,
      notes: notes ?? this.notes,
      colorHex: identical(colorHex, _sentinel)
          ? this.colorHex
          : colorHex as String?,
      textColorHex: identical(textColorHex, _sentinel)
          ? this.textColorHex
          : textColorHex as String?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      revision: revision ?? this.revision,
      deviceId: deviceId ?? this.deviceId,
      deletedAt: identical(deletedAt, _sentinel)
          ? this.deletedAt
          : deletedAt as DateTime?,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'owner_id': ownerId,
    'title': title,
    'kind': kind.name,
    'month_goal': monthGoal,
    'sort_key': sortKey,
    'unit': unit,
    'notes': notes,
    'color_hex': colorHex,
    'text_color_hex': textColorHex,
    'created_at': createdAt.toUtc().toIso8601String(),
    'client_updated_at': updatedAt.toUtc().toIso8601String(),
    'revision': revision,
    'device_id': deviceId,
    'deleted_at': deletedAt?.toUtc().toIso8601String(),
  };

  factory Habit.fromMap(Map<String, Object?> map) => Habit(
    id: map['id']! as String,
    ownerId: map['owner_id'] as String?,
    title: map['title'] as String? ?? 'Habit',
    kind: HabitKind.values.firstWhere(
      (value) => value.name == (map['kind'] as String? ?? 'checkbox'),
      orElse: () => HabitKind.checkbox,
    ),
    monthGoal: (map['month_goal'] as num?)?.toDouble() ?? 0,
    sortKey: (map['sort_key'] as num?)?.toDouble() ?? 0,
    unit: map['unit'] as String? ?? '',
    notes: map['notes'] as String? ?? '',
    colorHex: map['color_hex'] as String?,
    textColorHex: map['text_color_hex'] as String?,
    createdAt: parseDateTime(map['created_at']) ?? DateTime.now().toUtc(),
    updatedAt:
        parseDateTime(map['client_updated_at']) ??
        parseDateTime(map['updated_at']) ??
        DateTime.now().toUtc(),
    revision: (map['revision'] as num?)?.toInt() ?? 1,
    deviceId: map['device_id'] as String? ?? 'unknown',
    deletedAt: parseDateTime(map['deleted_at']),
  );
}

class HabitEntry {
  const HabitEntry({
    required this.id,
    required this.habitId,
    required this.entryDate,
    required this.value,
    required this.updatedAt,
    required this.revision,
    required this.deviceId,
    this.ownerId,
    this.deletedAt,
  });

  final String id;
  final String? ownerId;
  final String habitId;
  final String entryDate;
  final double value;
  final DateTime updatedAt;
  final int revision;
  final String deviceId;
  final DateTime? deletedAt;

  HabitEntry copyWith({
    double? value,
    DateTime? updatedAt,
    int? revision,
    String? deviceId,
    Object? deletedAt = _sentinel,
  }) {
    return HabitEntry(
      id: id,
      ownerId: ownerId,
      habitId: habitId,
      entryDate: entryDate,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      revision: revision ?? this.revision,
      deviceId: deviceId ?? this.deviceId,
      deletedAt: identical(deletedAt, _sentinel)
          ? this.deletedAt
          : deletedAt as DateTime?,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'owner_id': ownerId,
    'habit_id': habitId,
    'entry_date': entryDate,
    'value': value,
    'client_updated_at': updatedAt.toUtc().toIso8601String(),
    'revision': revision,
    'device_id': deviceId,
    'deleted_at': deletedAt?.toUtc().toIso8601String(),
  };

  factory HabitEntry.fromMap(Map<String, Object?> map) => HabitEntry(
    id: map['id']! as String,
    ownerId: map['owner_id'] as String?,
    habitId: map['habit_id']! as String,
    entryDate: map['entry_date'] as String? ?? '',
    value: (map['value'] as num?)?.toDouble() ?? 0,
    updatedAt:
        parseDateTime(map['client_updated_at']) ??
        parseDateTime(map['updated_at']) ??
        DateTime.now().toUtc(),
    revision: (map['revision'] as num?)?.toInt() ?? 1,
    deviceId: map['device_id'] as String? ?? 'unknown',
    deletedAt: parseDateTime(map['deleted_at']),
  );
}

class NorthStarNote {
  const NorthStarNote({
    required this.id,
    required this.title,
    required this.body,
    required this.sortKey,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
    required this.deviceId,
    this.ownerId,
    this.pinned = false,
    this.hidden = false,
    this.archived = false,
    this.colorHex,
    this.textColorHex,
    this.checklistJson = '[]',
    this.link = '',
    this.imageBase64 = '',
    this.x = 80,
    this.y = 80,
    this.width = 320,
    this.height = 260,
    this.fontWeightValue = 600,
    this.folder = '',
    this.deletedAt,
  });

  final String id;
  final String? ownerId;
  final String title;
  final String body;
  final double sortKey;
  final bool pinned;
  final bool hidden;
  final bool archived;
  final String? colorHex;
  final String? textColorHex;
  final String checklistJson;
  final String link;
  final String imageBase64;
  final double x;
  final double y;
  final double width;
  final double height;
  final int fontWeightValue;
  final String folder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;
  final String deviceId;
  final DateTime? deletedAt;

  NorthStarNote copyWith({
    String? title,
    String? body,
    double? sortKey,
    bool? pinned,
    bool? hidden,
    bool? archived,
    Object? colorHex = _sentinel,
    Object? textColorHex = _sentinel,
    String? checklistJson,
    String? link,
    String? imageBase64,
    double? x,
    double? y,
    double? width,
    double? height,
    int? fontWeightValue,
    String? folder,
    DateTime? updatedAt,
    int? revision,
    String? deviceId,
    Object? deletedAt = _sentinel,
  }) {
    return NorthStarNote(
      id: id,
      ownerId: ownerId,
      title: title ?? this.title,
      body: body ?? this.body,
      sortKey: sortKey ?? this.sortKey,
      pinned: pinned ?? this.pinned,
      hidden: hidden ?? this.hidden,
      archived: archived ?? this.archived,
      colorHex: identical(colorHex, _sentinel)
          ? this.colorHex
          : colorHex as String?,
      textColorHex: identical(textColorHex, _sentinel)
          ? this.textColorHex
          : textColorHex as String?,
      checklistJson: checklistJson ?? this.checklistJson,
      link: link ?? this.link,
      imageBase64: imageBase64 ?? this.imageBase64,
      x: x ?? this.x,
      y: y ?? this.y,
      width: (width ?? this.width).clamp(220, 900).toDouble(),
      height: (height ?? this.height).clamp(160, 760).toDouble(),
      fontWeightValue: (fontWeightValue ?? this.fontWeightValue)
          .clamp(100, 900)
          .toInt(),
      folder: folder ?? this.folder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      revision: revision ?? this.revision,
      deviceId: deviceId ?? this.deviceId,
      deletedAt: identical(deletedAt, _sentinel)
          ? this.deletedAt
          : deletedAt as DateTime?,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'owner_id': ownerId,
    'title': title,
    'body': body,
    'sort_key': sortKey,
    'pinned': boolToInt(pinned),
    'hidden': boolToInt(hidden),
    'archived': boolToInt(archived),
    'color_hex': colorHex,
    'text_color_hex': textColorHex,
    'checklist_json': checklistJson,
    'link': link,
    'image_base64': imageBase64,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'font_weight': fontWeightValue,
    'folder': folder,
    'created_at': createdAt.toUtc().toIso8601String(),
    'client_updated_at': updatedAt.toUtc().toIso8601String(),
    'revision': revision,
    'device_id': deviceId,
    'deleted_at': deletedAt?.toUtc().toIso8601String(),
  };

  Map<String, Object?> toCloudMap() {
    final map = toMap();
    map['pinned'] = pinned;
    map['hidden'] = hidden;
    map['archived'] = archived;
    return map;
  }

  factory NorthStarNote.fromMap(Map<String, Object?> map) => NorthStarNote(
    id: map['id']! as String,
    ownerId: map['owner_id'] as String?,
    title: map['title'] as String? ?? 'Note',
    body: map['body'] as String? ?? '',
    sortKey: (map['sort_key'] as num?)?.toDouble() ?? 0,
    pinned: intToBool(map['pinned']),
    hidden: intToBool(map['hidden']),
    archived: intToBool(map['archived']),
    colorHex: map['color_hex'] as String?,
    textColorHex: map['text_color_hex'] as String?,
    checklistJson: map['checklist_json'] as String? ?? '[]',
    link: map['link'] as String? ?? '',
    imageBase64: map['image_base64'] as String? ?? '',
    x: (map['x'] as num?)?.toDouble() ?? 80,
    y: (map['y'] as num?)?.toDouble() ?? 80,
    width: (map['width'] as num?)?.toDouble() ?? 320,
    height: (map['height'] as num?)?.toDouble() ?? 260,
    fontWeightValue: (map['font_weight'] as num?)?.toInt() ?? 600,
    folder: map['folder'] as String? ?? '',
    createdAt: parseDateTime(map['created_at']) ?? DateTime.now().toUtc(),
    updatedAt:
        parseDateTime(map['client_updated_at']) ??
        parseDateTime(map['updated_at']) ??
        DateTime.now().toUtc(),
    revision: (map['revision'] as num?)?.toInt() ?? 1,
    deviceId: map['device_id'] as String? ?? 'unknown',
    deletedAt: parseDateTime(map['deleted_at']),
  );
}

class RewardRank {
  const RewardRank({
    required this.id,
    required this.name,
    required this.minimumPoints,
    required this.sortKey,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
    required this.deviceId,
    this.ownerId,
    this.icon = '⭐',
    this.colorHex = '#6750A4',
    this.deletedAt,
  });

  final String id;
  final String? ownerId;
  final String name;
  final int minimumPoints;
  final double sortKey;
  final String icon;
  final String colorHex;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;
  final String deviceId;
  final DateTime? deletedAt;

  RewardRank copyWith({
    String? name,
    int? minimumPoints,
    double? sortKey,
    String? icon,
    String? colorHex,
    DateTime? updatedAt,
    int? revision,
    String? deviceId,
    Object? deletedAt = _sentinel,
  }) {
    return RewardRank(
      id: id,
      ownerId: ownerId,
      name: name ?? this.name,
      minimumPoints: (minimumPoints ?? this.minimumPoints)
          .clamp(0, 99999999)
          .toInt(),
      sortKey: sortKey ?? this.sortKey,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      revision: revision ?? this.revision,
      deviceId: deviceId ?? this.deviceId,
      deletedAt: identical(deletedAt, _sentinel)
          ? this.deletedAt
          : deletedAt as DateTime?,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'owner_id': ownerId,
    'name': name,
    'minimum_points': minimumPoints,
    'sort_key': sortKey,
    'icon': icon,
    'color_hex': colorHex,
    'created_at': createdAt.toUtc().toIso8601String(),
    'client_updated_at': updatedAt.toUtc().toIso8601String(),
    'revision': revision,
    'device_id': deviceId,
    'deleted_at': deletedAt?.toUtc().toIso8601String(),
  };

  factory RewardRank.fromMap(Map<String, Object?> map) => RewardRank(
    id: map['id']! as String,
    ownerId: map['owner_id'] as String?,
    name: map['name'] as String? ?? 'Rank',
    minimumPoints: (map['minimum_points'] as num?)?.toInt() ?? 0,
    sortKey: (map['sort_key'] as num?)?.toDouble() ?? 0,
    icon: map['icon'] as String? ?? '⭐',
    colorHex: map['color_hex'] as String? ?? '#6750A4',
    createdAt: parseDateTime(map['created_at']) ?? DateTime.now().toUtc(),
    updatedAt:
        parseDateTime(map['client_updated_at']) ??
        parseDateTime(map['updated_at']) ??
        DateTime.now().toUtc(),
    revision: (map['revision'] as num?)?.toInt() ?? 1,
    deviceId: map['device_id'] as String? ?? 'unknown',
    deletedAt: parseDateTime(map['deleted_at']),
  );
}

class StudyTable {
  const StudyTable({
    required this.id,
    required this.title,
    required this.columnsJson,
    required this.rowsJson,
    required this.sortKey,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
    required this.deviceId,
    this.ownerId,
    this.archived = false,
    this.deletedAt,
  });

  final String id;
  final String? ownerId;
  final String title;
  final String columnsJson;
  final String rowsJson;
  final double sortKey;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;
  final String deviceId;
  final DateTime? deletedAt;

  List<String> get columns {
    try {
      final value = jsonDecode(columnsJson);
      if (value is List) return value.map((item) => item.toString()).toList();
    } catch (_) {}
    return <String>['Topic', 'Status'];
  }

  List<List<String>> get rows {
    try {
      final value = jsonDecode(rowsJson);
      if (value is List) {
        return value
            .whereType<List>()
            .map((row) => row.map((cell) => cell.toString()).toList())
            .toList();
      }
    } catch (_) {}
    return <List<String>>[];
  }

  StudyTable copyWith({
    String? title,
    String? columnsJson,
    String? rowsJson,
    double? sortKey,
    bool? archived,
    DateTime? updatedAt,
    int? revision,
    String? deviceId,
    Object? deletedAt = _sentinel,
  }) {
    return StudyTable(
      id: id,
      ownerId: ownerId,
      title: title ?? this.title,
      columnsJson: columnsJson ?? this.columnsJson,
      rowsJson: rowsJson ?? this.rowsJson,
      sortKey: sortKey ?? this.sortKey,
      archived: archived ?? this.archived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      revision: revision ?? this.revision,
      deviceId: deviceId ?? this.deviceId,
      deletedAt: identical(deletedAt, _sentinel)
          ? this.deletedAt
          : deletedAt as DateTime?,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'owner_id': ownerId,
    'title': title,
    'columns_json': columnsJson,
    'rows_json': rowsJson,
    'sort_key': sortKey,
    'archived': boolToInt(archived),
    'created_at': createdAt.toUtc().toIso8601String(),
    'client_updated_at': updatedAt.toUtc().toIso8601String(),
    'revision': revision,
    'device_id': deviceId,
    'deleted_at': deletedAt?.toUtc().toIso8601String(),
  };

  factory StudyTable.fromMap(Map<String, Object?> map) => StudyTable(
    id: map['id']! as String,
    ownerId: map['owner_id'] as String?,
    title: map['title'] as String? ?? 'Study table',
    columnsJson: map['columns_json'] as String? ?? '["Topic","Status"]',
    rowsJson: map['rows_json'] as String? ?? '[]',
    sortKey: (map['sort_key'] as num?)?.toDouble() ?? 0,
    archived: intToBool(map['archived']),
    createdAt: parseDateTime(map['created_at']) ?? DateTime.now().toUtc(),
    updatedAt:
        parseDateTime(map['client_updated_at']) ??
        parseDateTime(map['updated_at']) ??
        DateTime.now().toUtc(),
    revision: (map['revision'] as num?)?.toInt() ?? 1,
    deviceId: map['device_id'] as String? ?? 'unknown',
    deletedAt: parseDateTime(map['deleted_at']),
  );
}

class TabPreference {
  const TabPreference({
    required this.section,
    required this.label,
    required this.colorValue,
    required this.iconKey,
  });

  final AppSection section;
  final String label;
  final int colorValue;
  final String iconKey;

  Map<String, Object?> toMap() => {
    'section': section.name,
    'label': label,
    'color': colorValue,
    'icon': iconKey,
  };

  factory TabPreference.fromMap(Map<String, dynamic> map) {
    final sectionName = map['section']?.toString() ?? 'overview';
    return TabPreference(
      section: AppSection.values.firstWhere(
        (value) => value.name == sectionName,
        orElse: () => AppSection.overview,
      ),
      label: map['label']?.toString() ?? sectionName,
      colorValue: (map['color'] as num?)?.toInt() ?? 0xFF6750A4,
      iconKey: map['icon']?.toString() ?? 'circle',
    );
  }
}

const Object _sentinel = Object();
