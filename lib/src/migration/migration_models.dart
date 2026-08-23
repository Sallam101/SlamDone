import 'dart:convert';

class MigrationPayload {
  const MigrationPayload({
    required this.entities,
    required this.settings,
    required this.timerState,
    required this.sourceCounts,
    required this.sourceSha256,
    required this.exportedAt,
  });

  static const formatName = 'supeslam-autivra-migration';
  static const supportedFormatVersion = 1;
  static const entityTables = <String>[
    'work_items',
    'canvas_layouts',
    'journal_entries',
    'journal_versions',
    'time_sessions',
    'habits',
    'habit_entries',
    'northstar_notes',
    'reward_ranks',
    'study_tables',
  ];

  final Map<String, List<Map<String, Object?>>> entities;
  final Map<String, String> settings;
  final Map<String, Object?> timerState;
  final Map<String, int> sourceCounts;
  final String sourceSha256;
  final DateTime? exportedAt;

  factory MigrationPayload.fromJson(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      throw const FormatException('Migration file must contain a JSON object.');
    }
    final root = decoded.cast<String, dynamic>();
    if (root['format'] != formatName) {
      throw const FormatException('This is not a SlamDone Autivra migration file.');
    }
    final formatVersion = (root['formatVersion'] as num?)?.toInt();
    if (formatVersion != supportedFormatVersion) {
      throw FormatException('Unsupported migration formatVersion: $formatVersion');
    }

    final source = root['source'];
    if (source is! Map) {
      throw const FormatException('Migration source metadata is missing.');
    }
    final sourceMap = source.cast<String, dynamic>();
    final sourceSha256 = sourceMap['sha256']?.toString() ?? '';
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sourceSha256)) {
      throw const FormatException('Migration source checksum is invalid.');
    }

    final rawEntities = root['entities'];
    if (rawEntities is! Map) {
      throw const FormatException('Migration entities are missing.');
    }
    final entityMap = rawEntities.cast<String, dynamic>();
    final entities = <String, List<Map<String, Object?>>>{};
    for (final table in entityTables) {
      final rows = entityMap[table];
      if (rows is! List) {
        throw FormatException('Migration entity list is missing: $table');
      }
      entities[table] = rows.map((raw) {
        if (raw is! Map) {
          throw FormatException('Invalid row in $table.');
        }
        return raw.cast<String, Object?>();
      }).toList(growable: false);
    }

    final rawSettings = root['settings'];
    if (rawSettings is! Map) {
      throw const FormatException('Migration settings are missing.');
    }
    final settings = <String, String>{
      for (final entry in rawSettings.entries)
        entry.key.toString(): entry.value?.toString() ?? '',
    };

    final rawTimer = root['timer_state'];
    if (rawTimer is! Map) {
      throw const FormatException('Migration timer_state is missing.');
    }
    final timerState = rawTimer.cast<String, Object?>();

    final validation = root['validation'];
    if (validation is! Map || validation['sourceCounts'] is! Map) {
      throw const FormatException('Migration validation.sourceCounts is missing.');
    }
    final sourceCounts = <String, int>{};
    for (final entry in (validation['sourceCounts'] as Map).entries) {
      final value = entry.value;
      if (value is! num) {
        throw FormatException('Invalid source count for ${entry.key}.');
      }
      sourceCounts[entry.key.toString()] = value.toInt();
    }

    for (final table in entityTables) {
      final expected = sourceCounts[table];
      if (expected == null || expected != entities[table]!.length) {
        throw FormatException('Source count mismatch for $table.');
      }
    }
    if (sourceCounts['app_settings'] != settings.length) {
      throw const FormatException('Source count mismatch for app_settings.');
    }
    final timerCount = timerState.isEmpty ? 0 : 1;
    if (sourceCounts['timer_state'] != timerCount) {
      throw const FormatException('Source count mismatch for timer_state.');
    }

    return MigrationPayload(
      entities: entities,
      settings: settings,
      timerState: timerState,
      sourceCounts: sourceCounts,
      sourceSha256: sourceSha256,
      exportedAt: DateTime.tryParse(root['exportedAt']?.toString() ?? ''),
    );
  }
}

class MigrationImportResult {
  const MigrationImportResult({
    required this.changedByTable,
    required this.sourceCounts,
    required this.localCounts,
    required this.sourceSha256,
  });

  final Map<String, int> changedByTable;
  final Map<String, int> sourceCounts;
  final Map<String, int> localCounts;
  final String sourceSha256;

  int get totalChanged => changedByTable.values.fold(0, (a, b) => a + b);
}
