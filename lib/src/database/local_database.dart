import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/models.dart';
import '../migration/migration_models.dart';
import '../sync/conflict_resolver.dart';

class LocalDatabase {
  Database? _database;
  late final String databasePath;

  Database get db {
    final value = _database;
    if (value == null) throw StateError('Database has not been opened.');
    return value;
  }

  Future<void> open() async {
    final factory = databaseFactoryFfiWeb;
    databasePath = 'supeslam.db';

    _database = await factory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 6,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
          try {
            await database.rawQuery('PRAGMA journal_mode = WAL');
          } catch (_) {
            // Browser SQLite VFS implementations may choose their own journal mode.
          }
          try {
            await database.execute('PRAGMA synchronous = NORMAL');
          } catch (_) {}
        },
        onCreate: _createSchema,
        onUpgrade: _upgradeSchema,
      ),
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<void> _upgradeSchema(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) await _createExtendedSchema(database);
    if (oldVersion < 3) {
      await _addColumnIfMissing(
        database,
        'work_items',
        'urgent',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        database,
        'work_items',
        'gtd_status',
        "TEXT NOT NULL DEFAULT 'inbox'",
      );
      await _addColumnIfMissing(
        database,
        'work_items',
        'para_category',
        "TEXT NOT NULL DEFAULT 'Projects'",
      );
      await _addColumnIfMissing(
        database,
        'work_items',
        'session_goal',
        'INTEGER NOT NULL DEFAULT 1',
      );
      await _addColumnIfMissing(
        database,
        'work_items',
        'recurring',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        database,
        'work_items',
        'title_scale',
        'REAL NOT NULL DEFAULT 1.0',
      );
      await _addColumnIfMissing(
        database,
        'work_items',
        'title_bold',
        'INTEGER NOT NULL DEFAULT 1',
      );
      await _addColumnIfMissing(
        database,
        'work_items',
        'text_color_hex',
        'TEXT',
      );
      await _addColumnIfMissing(
        database,
        'work_items',
        'folder',
        "TEXT NOT NULL DEFAULT ''",
      );

      await _addColumnIfMissing(
        database,
        'journal_entries',
        'custom_json',
        "TEXT NOT NULL DEFAULT '{}'",
      );
      await _addColumnIfMissing(
        database,
        'journal_entries',
        'folder',
        "TEXT NOT NULL DEFAULT ''",
      );
      await _addColumnIfMissing(
        database,
        'journal_entries',
        'archived',
        'INTEGER NOT NULL DEFAULT 0',
      );

      await _addColumnIfMissing(
        database,
        'northstar_notes',
        'hidden',
        'INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        database,
        'northstar_notes',
        'text_color_hex',
        'TEXT',
      );
      await _addColumnIfMissing(
        database,
        'northstar_notes',
        'image_base64',
        "TEXT NOT NULL DEFAULT ''",
      );
      await _addColumnIfMissing(
        database,
        'northstar_notes',
        'x',
        'REAL NOT NULL DEFAULT 80',
      );
      await _addColumnIfMissing(
        database,
        'northstar_notes',
        'y',
        'REAL NOT NULL DEFAULT 80',
      );
      await _addColumnIfMissing(
        database,
        'northstar_notes',
        'width',
        'REAL NOT NULL DEFAULT 320',
      );
      await _addColumnIfMissing(
        database,
        'northstar_notes',
        'height',
        'REAL NOT NULL DEFAULT 260',
      );
      await _addColumnIfMissing(
        database,
        'northstar_notes',
        'font_weight',
        'INTEGER NOT NULL DEFAULT 600',
      );
      await _addColumnIfMissing(
        database,
        'northstar_notes',
        'folder',
        "TEXT NOT NULL DEFAULT ''",
      );
      await _createAutivraTables(database);
    }
    if (oldVersion < 4) {
      await _createAutivraTables(database);
    }
    if (oldVersion < 5) {
      await _addColumnIfMissing(database, 'habits', 'text_color_hex', 'TEXT');
    }
    if (oldVersion < 6) {
      await _addColumnIfMissing(
        database,
        'work_items',
        'recurrence_days',
        'INTEGER NOT NULL DEFAULT 1',
      );
      await _addColumnIfMissing(
        database,
        'work_items',
        'energy_level',
        "TEXT NOT NULL DEFAULT 'none'",
      );
      await _addColumnIfMissing(
        database,
        'work_items',
        'child_columns',
        'INTEGER NOT NULL DEFAULT 4',
      );
      await _addColumnIfMissing(
        database,
        'northstar_notes',
        'archived',
        'INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  Future<void> _addColumnIfMissing(
    Database database,
    String table,
    String column,
    String definition,
  ) async {
    final rows = await database.rawQuery('PRAGMA table_info($table)');
    final exists = rows.any((row) => row['name'] == column);
    if (!exists) {
      await database.execute(
        'ALTER TABLE $table ADD COLUMN $column $definition',
      );
    }
  }

  Future<void> _createExtendedSchema(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS habits (
        id TEXT PRIMARY KEY, owner_id TEXT, title TEXT NOT NULL, kind TEXT NOT NULL,
        month_goal REAL NOT NULL DEFAULT 0, sort_key REAL NOT NULL, unit TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '', color_hex TEXT, text_color_hex TEXT, created_at TEXT NOT NULL,
        client_updated_at TEXT NOT NULL, revision INTEGER NOT NULL DEFAULT 1,
        device_id TEXT NOT NULL, deleted_at TEXT
      )
    ''');
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_habits_sort ON habits(sort_key)',
    );
    await database.execute('''
      CREATE TABLE IF NOT EXISTS habit_entries (
        id TEXT PRIMARY KEY, owner_id TEXT, habit_id TEXT NOT NULL, entry_date TEXT NOT NULL,
        value REAL NOT NULL DEFAULT 0, client_updated_at TEXT NOT NULL,
        revision INTEGER NOT NULL DEFAULT 1, device_id TEXT NOT NULL, deleted_at TEXT,
        UNIQUE(habit_id, entry_date), FOREIGN KEY(habit_id) REFERENCES habits(id) ON DELETE CASCADE
      )
    ''');
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_habit_entries_date ON habit_entries(entry_date)',
    );
    await database.execute('''
      CREATE TABLE IF NOT EXISTS northstar_notes (
        id TEXT PRIMARY KEY, owner_id TEXT, title TEXT NOT NULL, body TEXT NOT NULL DEFAULT '',
        sort_key REAL NOT NULL, pinned INTEGER NOT NULL DEFAULT 0, hidden INTEGER NOT NULL DEFAULT 0,
        archived INTEGER NOT NULL DEFAULT 0,
        color_hex TEXT, text_color_hex TEXT, checklist_json TEXT NOT NULL DEFAULT '[]',
        link TEXT NOT NULL DEFAULT '', image_base64 TEXT NOT NULL DEFAULT '',
        x REAL NOT NULL DEFAULT 80, y REAL NOT NULL DEFAULT 80,
        width REAL NOT NULL DEFAULT 320, height REAL NOT NULL DEFAULT 260,
        font_weight INTEGER NOT NULL DEFAULT 600, folder TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL, client_updated_at TEXT NOT NULL,
        revision INTEGER NOT NULL DEFAULT 1, device_id TEXT NOT NULL, deleted_at TEXT
      )
    ''');
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_northstar_sort ON northstar_notes(pinned DESC, sort_key)',
    );
  }

  Future<void> _createAutivraTables(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS reward_ranks (
        id TEXT PRIMARY KEY, owner_id TEXT, name TEXT NOT NULL,
        minimum_points INTEGER NOT NULL DEFAULT 0, sort_key REAL NOT NULL,
        icon TEXT NOT NULL DEFAULT '⭐', color_hex TEXT NOT NULL DEFAULT '#6750A4',
        created_at TEXT NOT NULL, client_updated_at TEXT NOT NULL,
        revision INTEGER NOT NULL DEFAULT 1, device_id TEXT NOT NULL, deleted_at TEXT
      )
    ''');
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_reward_ranks_sort ON reward_ranks(sort_key)',
    );
    await database.execute('''
      CREATE TABLE IF NOT EXISTS study_tables (
        id TEXT PRIMARY KEY, owner_id TEXT, title TEXT NOT NULL,
        columns_json TEXT NOT NULL DEFAULT '["Topic","Status"]',
        rows_json TEXT NOT NULL DEFAULT '[]', sort_key REAL NOT NULL,
        archived INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL,
        client_updated_at TEXT NOT NULL, revision INTEGER NOT NULL DEFAULT 1,
        device_id TEXT NOT NULL, deleted_at TEXT
      )
    ''');
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_study_tables_sort ON study_tables(sort_key)',
    );
  }

  Future<void> _createSchema(Database database, int version) async {
    await database.execute('''
      CREATE TABLE work_items (
        id TEXT PRIMARY KEY, owner_id TEXT, title TEXT NOT NULL, type TEXT NOT NULL,
        parent_id TEXT, sort_key REAL NOT NULL, notes TEXT NOT NULL DEFAULT '', due_date TEXT,
        priority TEXT NOT NULL DEFAULT 'normal', urgent INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active', gtd_status TEXT NOT NULL DEFAULT 'inbox',
        para_category TEXT NOT NULL DEFAULT 'Projects', checklist_total INTEGER NOT NULL DEFAULT 0,
        checklist_done INTEGER NOT NULL DEFAULT 0, timer_minutes INTEGER NOT NULL DEFAULT 25,
        session_goal INTEGER NOT NULL DEFAULT 1, recurring INTEGER NOT NULL DEFAULT 0,
        recurrence_days INTEGER NOT NULL DEFAULT 1,
        energy_level TEXT NOT NULL DEFAULT 'none', child_columns INTEGER NOT NULL DEFAULT 4,
        title_scale REAL NOT NULL DEFAULT 1.0, title_bold INTEGER NOT NULL DEFAULT 1,
        text_color_hex TEXT, folder TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL,
        client_updated_at TEXT NOT NULL, revision INTEGER NOT NULL DEFAULT 1,
        device_id TEXT NOT NULL, deleted_at TEXT,
        FOREIGN KEY(parent_id) REFERENCES work_items(id) ON DELETE SET NULL
      )
    ''');
    await database.execute(
      'CREATE INDEX idx_work_items_parent_sort ON work_items(parent_id, sort_key)',
    );
    await database.execute(
      'CREATE INDEX idx_work_items_updated ON work_items(client_updated_at)',
    );

    await database.execute('''
      CREATE TABLE canvas_layouts (
        id TEXT PRIMARY KEY, owner_id TEXT, item_id TEXT NOT NULL,
        view_kind TEXT NOT NULL, device_class TEXT NOT NULL,
        x REAL NOT NULL, y REAL NOT NULL, width REAL NOT NULL, height REAL NOT NULL,
        collapsed INTEGER NOT NULL DEFAULT 0, locked INTEGER NOT NULL DEFAULT 0,
        color_hex TEXT, client_updated_at TEXT NOT NULL,
        revision INTEGER NOT NULL DEFAULT 1, device_id TEXT NOT NULL, deleted_at TEXT,
        UNIQUE(item_id, view_kind, device_class),
        FOREIGN KEY(item_id) REFERENCES work_items(id) ON DELETE CASCADE
      )
    ''');

    await database.execute('''
      CREATE TABLE journal_entries (
        id TEXT PRIMARY KEY, owner_id TEXT, entry_date TEXT NOT NULL UNIQUE,
        win_big TEXT NOT NULL DEFAULT '', feel TEXT NOT NULL DEFAULT '',
        grateful TEXT NOT NULL DEFAULT '', body TEXT NOT NULL DEFAULT '',
        regret TEXT NOT NULL DEFAULT '', pretending TEXT NOT NULL DEFAULT '',
        flow TEXT NOT NULL DEFAULT '', not_tolerate TEXT NOT NULL DEFAULT '',
        custom_json TEXT NOT NULL DEFAULT '{}', folder TEXT NOT NULL DEFAULT '',
        archived INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL,
        client_updated_at TEXT NOT NULL, revision INTEGER NOT NULL DEFAULT 1,
        device_id TEXT NOT NULL, deleted_at TEXT
      )
    ''');

    await database.execute('''
      CREATE TABLE journal_versions (
        id TEXT PRIMARY KEY, journal_id TEXT NOT NULL,
        snapshot_json TEXT NOT NULL, created_at TEXT NOT NULL,
        FOREIGN KEY(journal_id) REFERENCES journal_entries(id) ON DELETE CASCADE
      )
    ''');
    await database.execute(
      'CREATE INDEX idx_journal_versions_entry ON journal_versions(journal_id, created_at DESC)',
    );

    await database.execute('''
      CREATE TABLE time_sessions (
        id TEXT PRIMARY KEY, owner_id TEXT, mode TEXT NOT NULL, work_item_id TEXT,
        title TEXT NOT NULL, planned_seconds INTEGER NOT NULL DEFAULT 0,
        elapsed_seconds INTEGER NOT NULL DEFAULT 0, started_at TEXT NOT NULL,
        ended_at TEXT NOT NULL, completed INTEGER NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL,
        client_updated_at TEXT NOT NULL, revision INTEGER NOT NULL DEFAULT 1,
        device_id TEXT NOT NULL, deleted_at TEXT,
        FOREIGN KEY(work_item_id) REFERENCES work_items(id) ON DELETE SET NULL
      )
    ''');
    await database.execute(
      'CREATE INDEX idx_time_sessions_started ON time_sessions(started_at DESC)',
    );

    await database.execute('''
      CREATE TABLE timer_state (
        id INTEGER PRIMARY KEY CHECK(id = 1), mode TEXT NOT NULL,
        owner TEXT NOT NULL, work_item_id TEXT, title TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL, remaining_seconds INTEGER NOT NULL,
        elapsed_seconds INTEGER NOT NULL, running INTEGER NOT NULL DEFAULT 0,
        paused INTEGER NOT NULL DEFAULT 0, auto_repeat INTEGER NOT NULL DEFAULT 0,
        started_at TEXT, end_at TEXT, client_updated_at TEXT NOT NULL,
        completion_token TEXT NOT NULL DEFAULT ''
      )
    ''');
    await database.insert(
      'timer_state',
      TimerStateRecord.idle().toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await database.execute('''
      CREATE TABLE sync_queue (
        queue_id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL, entity_id TEXT NOT NULL,
        created_at TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT, UNIQUE(entity_type, entity_id)
      )
    ''');

    await _createExtendedSchema(database);
    await _createAutivraTables(database);

    await database.execute('''
      CREATE TABLE app_settings (
        setting_key TEXT PRIMARY KEY, setting_value TEXT NOT NULL, updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upsertRow(
    DatabaseExecutor executor,
    String table,
    Map<String, Object?> values,
  ) async {
    final id = values['id'];
    if (id == null) throw ArgumentError('Upsert requires an id.');
    final updated = await executor.update(
      table,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated == 0) {
      await executor.insert(
        table,
        values,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
  }

  Future<List<WorkItem>> loadWorkItems({bool includeDeleted = false}) async {
    final rows = await db.query(
      'work_items',
      where: includeDeleted ? null : 'deleted_at IS NULL',
      orderBy: 'parent_id, sort_key, title COLLATE NOCASE',
    );
    return rows.map(WorkItem.fromMap).toList(growable: false);
  }

  Future<WorkItem?> getWorkItem(String id) async {
    final rows = await db.query(
      'work_items',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : WorkItem.fromMap(rows.first);
  }

  Future<void> saveWorkItem(WorkItem item, {bool enqueue = true}) async {
    await _upsertRow(db, 'work_items', item.toMap());
    if (enqueue) await enqueueEntity('work_items', item.id);
  }

  Future<List<CanvasLayout>> loadLayouts({
    required CanvasViewKind viewKind,
    required DeviceClass deviceClass,
    bool includeDeleted = false,
  }) async {
    final conditions = <String>[
      'view_kind = ?',
      'device_class = ?',
      if (!includeDeleted) 'deleted_at IS NULL',
    ];
    final rows = await db.query(
      'canvas_layouts',
      where: conditions.join(' AND '),
      whereArgs: [viewKind.name, deviceClass.name],
    );
    return rows.map(CanvasLayout.fromMap).toList(growable: false);
  }

  Future<CanvasLayout?> getLayout(String id) async {
    final rows = await db.query(
      'canvas_layouts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : CanvasLayout.fromMap(rows.first);
  }

  Future<void> saveLayout(CanvasLayout layout, {bool enqueue = true}) async {
    await _upsertRow(db, 'canvas_layouts', layout.toMap());
    if (enqueue) await enqueueEntity('canvas_layouts', layout.id);
  }

  Future<List<JournalEntry>> loadJournalEntries({
    bool includeDeleted = false,
  }) async {
    final rows = await db.query(
      'journal_entries',
      where: includeDeleted ? null : 'deleted_at IS NULL',
      orderBy: 'entry_date DESC',
    );
    return rows.map(JournalEntry.fromMap).toList(growable: false);
  }

  Future<JournalEntry?> getJournalByDate(String entryDate) async {
    final rows = await db.query(
      'journal_entries',
      where: 'entry_date = ? AND deleted_at IS NULL',
      whereArgs: [entryDate],
      limit: 1,
    );
    return rows.isEmpty ? null : JournalEntry.fromMap(rows.first);
  }

  Future<JournalEntry?> getJournalById(String id) async {
    final rows = await db.query(
      'journal_entries',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : JournalEntry.fromMap(rows.first);
  }

  Future<void> saveJournal(JournalEntry entry, {bool enqueue = true}) async {
    await _upsertRow(db, 'journal_entries', entry.toMap());
    if (enqueue) await enqueueEntity('journal_entries', entry.id);
  }

  Future<void> saveJournalVersion(
    JournalVersion version, {
    bool enqueue = true,
  }) async {
    await db.insert(
      'journal_versions',
      version.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    if (enqueue) await enqueueEntity('journal_versions', version.id);
  }

  Future<List<JournalVersion>> loadJournalVersions(String journalId) async {
    final rows = await db.query(
      'journal_versions',
      where: 'journal_id = ?',
      whereArgs: [journalId],
      orderBy: 'created_at DESC',
      limit: 30,
    );
    return rows
        .map(
          (row) => JournalVersion(
            id: row['id']! as String,
            journalId: row['journal_id']! as String,
            snapshotJson: row['snapshot_json']! as String,
            createdAt: parseDateTime(row['created_at'])!,
          ),
        )
        .toList(growable: false);
  }

  Future<List<TimeSession>> loadTimeSessions({int? limit}) async {
    final rows = await db.query(
      'time_sessions',
      where: 'deleted_at IS NULL',
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return rows.map(TimeSession.fromMap).toList(growable: false);
  }

  Future<TimeSession?> getTimeSession(String id) async {
    final rows = await db.query(
      'time_sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : TimeSession.fromMap(rows.first);
  }

  Future<void> saveTimeSession(
    TimeSession session, {
    bool enqueue = true,
  }) async {
    await _upsertRow(db, 'time_sessions', session.toMap());
    if (enqueue) await enqueueEntity('time_sessions', session.id);
  }

  Future<TimerStateRecord> loadTimerState() async {
    final rows = await db.query('timer_state', where: 'id = 1', limit: 1);
    if (rows.isEmpty) {
      final idle = TimerStateRecord.idle();
      await saveTimerState(idle);
      return idle;
    }
    return TimerStateRecord.fromMap(rows.first);
  }

  Future<void> saveTimerState(
    TimerStateRecord state, {
    bool enqueue = true,
  }) async {
    await db.insert(
      'timer_state',
      state.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (enqueue) await enqueueEntity('timer_state', '1');
  }

  Future<List<Habit>> loadHabits({bool includeDeleted = false}) async {
    final rows = await db.query(
      'habits',
      where: includeDeleted ? null : 'deleted_at IS NULL',
      orderBy: 'sort_key, title COLLATE NOCASE',
    );
    return rows.map(Habit.fromMap).toList(growable: false);
  }

  Future<Habit?> getHabit(String id) async {
    final rows = await db.query(
      'habits',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Habit.fromMap(rows.first);
  }

  Future<void> saveHabit(Habit habit, {bool enqueue = true}) async {
    await _upsertRow(db, 'habits', habit.toMap());
    if (enqueue) await enqueueEntity('habits', habit.id);
  }

  Future<List<HabitEntry>> loadHabitEntries({
    String? monthPrefix,
    bool includeDeleted = false,
  }) async {
    final conditions = <String>[];
    final args = <Object?>[];
    if (!includeDeleted) conditions.add('deleted_at IS NULL');
    if (monthPrefix != null) {
      conditions.add('entry_date LIKE ?');
      args.add('$monthPrefix%');
    }
    final rows = await db.query(
      'habit_entries',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'entry_date',
    );
    return rows.map(HabitEntry.fromMap).toList(growable: false);
  }

  Future<HabitEntry?> getHabitEntry(String habitId, String entryDate) async {
    final rows = await db.query(
      'habit_entries',
      where: 'habit_id = ? AND entry_date = ?',
      whereArgs: [habitId, entryDate],
      limit: 1,
    );
    return rows.isEmpty ? null : HabitEntry.fromMap(rows.first);
  }

  Future<HabitEntry?> getHabitEntryById(String id) async {
    final rows = await db.query(
      'habit_entries',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : HabitEntry.fromMap(rows.first);
  }

  Future<void> saveHabitEntry(HabitEntry entry, {bool enqueue = true}) async {
    await _upsertRow(db, 'habit_entries', entry.toMap());
    if (enqueue) await enqueueEntity('habit_entries', entry.id);
  }

  Future<List<NorthStarNote>> loadNorthStarNotes({
    bool includeDeleted = false,
  }) async {
    final rows = await db.query(
      'northstar_notes',
      where: includeDeleted ? null : 'deleted_at IS NULL',
      orderBy: 'pinned DESC, sort_key, title COLLATE NOCASE',
    );
    return rows.map(NorthStarNote.fromMap).toList(growable: false);
  }

  Future<NorthStarNote?> getNorthStarNote(String id) async {
    final rows = await db.query(
      'northstar_notes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : NorthStarNote.fromMap(rows.first);
  }

  Future<void> saveNorthStarNote(
    NorthStarNote note, {
    bool enqueue = true,
  }) async {
    await _upsertRow(db, 'northstar_notes', note.toMap());
    if (enqueue) await enqueueEntity('northstar_notes', note.id);
  }

  Future<List<RewardRank>> loadRewardRanks({
    bool includeDeleted = false,
  }) async {
    final rows = await db.query(
      'reward_ranks',
      where: includeDeleted ? null : 'deleted_at IS NULL',
      orderBy: 'sort_key, minimum_points',
    );
    return rows.map(RewardRank.fromMap).toList(growable: false);
  }

  Future<RewardRank?> getRewardRank(String id) async {
    final rows = await db.query(
      'reward_ranks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : RewardRank.fromMap(rows.first);
  }

  Future<void> saveRewardRank(RewardRank rank, {bool enqueue = true}) async {
    await _upsertRow(db, 'reward_ranks', rank.toMap());
    if (enqueue) await enqueueEntity('reward_ranks', rank.id);
  }

  Future<List<StudyTable>> loadStudyTables({
    bool includeDeleted = false,
  }) async {
    final rows = await db.query(
      'study_tables',
      where: includeDeleted ? null : 'deleted_at IS NULL',
      orderBy: 'sort_key, title COLLATE NOCASE',
    );
    return rows.map(StudyTable.fromMap).toList(growable: false);
  }

  Future<StudyTable?> getStudyTable(String id) async {
    final rows = await db.query(
      'study_tables',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : StudyTable.fromMap(rows.first);
  }

  Future<void> saveStudyTable(StudyTable table, {bool enqueue = true}) async {
    await _upsertRow(db, 'study_tables', table.toMap());
    if (enqueue) await enqueueEntity('study_tables', table.id);
  }

  Future<void> enqueueEntity(String entityType, String entityId) async {
    await db.insert('sync_queue', {
      'entity_type': entityType,
      'entity_id': entityId,
      'created_at': isoNow(),
      'attempts': 0,
      'last_error': null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SyncQueueEntry>> loadSyncQueue({int limit = 200}) async {
    final rows = await db.query(
      'sync_queue',
      orderBy: 'queue_id',
      limit: limit,
    );
    return rows.map(SyncQueueEntry.fromMap).toList(growable: false);
  }

  Future<void> markQueueSuccess(int queueId) async {
    await db.delete('sync_queue', where: 'queue_id = ?', whereArgs: [queueId]);
  }

  Future<void> markQueueFailure(int queueId, Object error) async {
    await db.rawUpdate(
      'UPDATE sync_queue SET attempts = attempts + 1, last_error = ? WHERE queue_id = ?',
      [error.toString(), queueId],
    );
  }

  Future<int> pendingSyncCount() async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS count FROM sync_queue');
    return (rows.first['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> setSetting(
    String key,
    String value, {
    bool enqueue = true,
  }) async {
    await db.insert('app_settings', {
      'setting_key': key,
      'setting_value': value,
      'updated_at': isoNow(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (enqueue) await enqueueEntity('app_settings', key);
  }

  Future<Map<String, Object?>?> loadSettingRow(String key) async {
    final rows = await db.query(
      'app_settings',
      where: 'setting_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : Map<String, Object?>.from(rows.first);
  }

  Future<String?> getSetting(String key) async {
    final rows = await db.query(
      'app_settings',
      columns: ['setting_value'],
      where: 'setting_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['setting_value'] as String?;
  }

  Future<Map<String, String>> loadAllSettings() async {
    final rows = await db.query('app_settings');
    return {
      for (final row in rows)
        row['setting_key'] as String: row['setting_value'] as String,
    };
  }

  Future<Map<String, Object?>?> cloudPayload(
    String entityType,
    String entityId,
    String ownerId,
  ) async {
    final rows = await db.query(
      entityType,
      where: 'id = ?',
      whereArgs: [entityId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final map = Map<String, Object?>.from(rows.first);
    map['owner_id'] = ownerId;
    _convertLocalBoolsToCloud(entityType, map);
    return map;
  }

  void _convertLocalBoolsToCloud(String entityType, Map<String, Object?> map) {
    if (entityType == 'canvas_layouts') {
      map['collapsed'] = intToBool(map['collapsed']);
      map['locked'] = intToBool(map['locked']);
    } else if (entityType == 'time_sessions') {
      map['completed'] = intToBool(map['completed']);
    } else if (entityType == 'northstar_notes') {
      map['pinned'] = intToBool(map['pinned']);
      map['hidden'] = intToBool(map['hidden']);
      map['archived'] = intToBool(map['archived']);
    } else if (entityType == 'work_items') {
      map['urgent'] = intToBool(map['urgent']);
      map['recurring'] = intToBool(map['recurring']);
      map['title_bold'] = intToBool(map['title_bold']);
    } else if (entityType == 'journal_entries') {
      map['archived'] = intToBool(map['archived']);
    } else if (entityType == 'study_tables') {
      map['archived'] = intToBool(map['archived']);
    }
  }

  void _convertCloudBoolsToLocal(String entityType, Map<String, Object?> map) {
    if (entityType == 'canvas_layouts') {
      map['collapsed'] = boolToInt(intToBool(map['collapsed']));
      map['locked'] = boolToInt(intToBool(map['locked']));
    } else if (entityType == 'time_sessions') {
      map['completed'] = boolToInt(intToBool(map['completed']));
    } else if (entityType == 'northstar_notes') {
      map['pinned'] = boolToInt(intToBool(map['pinned']));
      map['hidden'] = boolToInt(intToBool(map['hidden']));
      map['archived'] = boolToInt(intToBool(map['archived']));
    } else if (entityType == 'work_items') {
      map['urgent'] = boolToInt(intToBool(map['urgent']));
      map['recurring'] = boolToInt(intToBool(map['recurring']));
      map['title_bold'] = boolToInt(intToBool(map['title_bold']));
    } else if (entityType == 'journal_entries') {
      map['archived'] = boolToInt(intToBool(map['archived']));
    } else if (entityType == 'study_tables') {
      map['archived'] = boolToInt(intToBool(map['archived']));
    }
  }

  Future<void> mergeRemoteRows(
    String entityType,
    List<Map<String, dynamic>> rows, {
    bool Function(String entityId)? shouldDefer,
  }) async {
    await db.transaction((transaction) async {
      for (final raw in rows) {
        final row = raw.cast<String, Object?>();
        final id = row['id'] as String?;
        if (id == null || (shouldDefer?.call(id) ?? false)) continue;
        row.remove('owner_id');

        if (entityType == 'journal_versions') {
          await transaction.insert(
            'journal_versions',
            row,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          continue;
        }

        final existingRows = await transaction.query(
          entityType,
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (existingRows.isNotEmpty &&
            !incomingRecordIsNewer(row, existingRows.first)) {
          continue;
        }
        _convertCloudBoolsToLocal(entityType, row);
        await _upsertRow(transaction, entityType, row);
      }
    });
  }

  Future<List<Map<String, Object?>>> loadAllSettingRows() async =>
      (await db.query('app_settings'))
          .map((row) => Map<String, Object?>.from(row))
          .toList(growable: false);

  Future<void> mergeRemoteSettingRows(
    List<Map<String, dynamic>> rows, {
    required String localDeviceId,
  }) async {
    await db.transaction((transaction) async {
      for (final raw in rows) {
        final row = raw.cast<String, Object?>();
        final key = row['setting_key']?.toString();
        if (key == null || key.isEmpty) continue;
        final localRows = await transaction.query(
          'app_settings',
          where: 'setting_key = ?',
          whereArgs: [key],
          limit: 1,
        );
        var accept = localRows.isEmpty;
        if (!accept) {
          final remoteTime = DateTime.tryParse(
                row['updated_at']?.toString() ?? '',
              )?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
          final localTime = DateTime.tryParse(
                localRows.first['updated_at']?.toString() ?? '',
              )?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
          final cmp = remoteTime.compareTo(localTime);
          accept = cmp > 0 ||
              (cmp == 0 &&
                  (row['device_id']?.toString() ?? '').compareTo(localDeviceId) >
                      0);
        }
        if (!accept) continue;
        await transaction.insert(
          'app_settings',
          {
            'setting_key': key,
            'setting_value': row['setting_value']?.toString() ?? '',
            'updated_at': row['updated_at']?.toString() ?? isoNow(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<Map<String, Object?>> loadTimerStateMap() async {
    final rows = await db.query('timer_state', where: 'id = 1', limit: 1);
    return rows.isEmpty
        ? Map<String, Object?>.from(TimerStateRecord.idle().toMap())
        : Map<String, Object?>.from(rows.first);
  }

  Future<void> mergeRemoteTimerState(
    Map<String, dynamic> raw, {
    required String localDeviceId,
  }) async {
    final remote = raw.cast<String, Object?>();
    final remoteDeviceId = remote.remove('device_id')?.toString() ?? '';
    remote.remove('owner_id');
    final local = await loadTimerStateMap();
    final remoteTime = DateTime.tryParse(
          remote['client_updated_at']?.toString() ?? '',
        )?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final localTime = DateTime.tryParse(
          local['client_updated_at']?.toString() ?? '',
        )?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final cmp = remoteTime.compareTo(localTime);
    if (cmp < 0 || (cmp == 0 && remoteDeviceId.compareTo(localDeviceId) <= 0)) {
      return;
    }
    await db.insert(
      'timer_state',
      remote,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, int>> applyMigrationPayload(
    MigrationPayload payload,
  ) async {
    const excludedSettings = {
      'device_id',
      'drive_sync_folder',
      'sync_mode',
      'floating_timer_command',
      'floating_timer_heartbeat',
    };
    final changed = <String, int>{};
    final existingMigrationSha = await getSetting('migration_last_sha256');
    final sameMigration = existingMigrationSha == payload.sourceSha256;

    await db.transaction((transaction) async {
      for (final table in MigrationPayload.entityTables) {
        var tableChanged = 0;
        for (final sourceRow in payload.entities[table] ?? const []) {
          final row = Map<String, Object?>.from(sourceRow)..remove('owner_id');
          final id = row['id']?.toString();
          if (id == null || id.isEmpty) continue;
          final existing = await transaction.query(
            table,
            where: 'id = ?',
            whereArgs: [id],
            limit: 1,
          );

          if (table == 'journal_versions') {
            if (existing.isEmpty) {
              await transaction.insert(
                table,
                row,
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
              tableChanged++;
            }
            continue;
          }

          if (existing.isEmpty || incomingRecordIsNewer(row, existing.first)) {
            _convertCloudBoolsToLocal(table, row);
            await _upsertRow(transaction, table, row);
            tableChanged++;
          }
        }
        changed[table] = tableChanged;
      }

      var settingsChanged = 0;
      if (!sameMigration) {
        final now = isoNow();
        for (final entry in payload.settings.entries) {
          if (excludedSettings.contains(entry.key)) continue;
          await transaction.insert(
            'app_settings',
            {
              'setting_key': entry.key,
              'setting_value': entry.value,
              'updated_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          settingsChanged++;
        }

        if (payload.timerState.isNotEmpty) {
          final timer = Map<String, Object?>.from(payload.timerState);
          timer['id'] = 1;
          timer['owner'] = 'main';
          await transaction.insert(
            'timer_state',
            timer,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          changed['timer_state'] = 1;
        } else {
          changed['timer_state'] = 0;
        }
      } else {
        changed['timer_state'] = 0;
      }
      changed['app_settings'] = settingsChanged;
    });

    // Queue every migrated stable ID. If a local row was already newer, the
    // queue uploads that newer local row instead of the older migration copy.
    for (final table in MigrationPayload.entityTables) {
      for (final row in payload.entities[table] ?? const []) {
        final id = row['id']?.toString();
        if (id != null && id.isNotEmpty) await enqueueEntity(table, id);
      }
    }
    if (!sameMigration) {
      for (final key in payload.settings.keys) {
        if (!excludedSettings.contains(key)) {
          await enqueueEntity('app_settings', key);
        }
      }
      if (payload.timerState.isNotEmpty) {
        await enqueueEntity('timer_state', '1');
      }
    }
    return changed;
  }

  Future<Map<String, int>> migrationCounts() async {
    final counts = <String, int>{};
    for (final table in MigrationPayload.entityTables) {
      final rows = await db.rawQuery('SELECT COUNT(*) AS count FROM $table');
      counts[table] = (rows.first['count'] as num?)?.toInt() ?? 0;
    }
    final settingRows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM app_settings',
    );
    counts['app_settings'] =
        (settingRows.first['count'] as num?)?.toInt() ?? 0;
    final timerRows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM timer_state',
    );
    counts['timer_state'] = (timerRows.first['count'] as num?)?.toInt() ?? 0;
    return counts;
  }

  Future<Map<String, List<Map<String, Object?>>>> exportAllEntities() async {
    const tables = [
      'work_items',
      'canvas_layouts',
      'journal_entries',
      'time_sessions',
      'habits',
      'habit_entries',
      'northstar_notes',
      'reward_ranks',
      'study_tables',
    ];
    final result = <String, List<Map<String, Object?>>>{};
    for (final table in tables) {
      result[table] = (await db.query(
        table,
      )).map((row) => Map<String, Object?>.from(row)).toList(growable: false);
    }
    return result;
  }

  Future<void> clearAllUserData() async {
    await db.transaction((transaction) async {
      for (final table in [
        'sync_queue',
        'journal_versions',
        'study_tables',
        'reward_ranks',
        'northstar_notes',
        'habit_entries',
        'habits',
        'time_sessions',
        'journal_entries',
        'canvas_layouts',
        'work_items',
      ]) {
        await transaction.delete(table);
      }
      await transaction.delete('timer_state');
      await transaction.insert('timer_state', TimerStateRecord.idle().toMap());
    });
  }
}
