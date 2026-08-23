import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:supeslam/src/migration/migration_models.dart';

void main() {
  Map<String, dynamic> validPayload() {
    final entities = <String, dynamic>{
      for (final table in MigrationPayload.entityTables) table: <dynamic>[],
    };
    final counts = <String, dynamic>{
      for (final table in MigrationPayload.entityTables) table: 0,
      'app_settings': 0,
      'timer_state': 0,
    };
    return {
      'format': MigrationPayload.formatName,
      'formatVersion': 1,
      'source': {
        'sha256': 'a' * 64,
      },
      'exportedAt': '2026-08-23T07:01:37Z',
      'entities': entities,
      'settings': <String, dynamic>{},
      'timer_state': <String, dynamic>{},
      'validation': {'sourceCounts': counts},
    };
  }

  test('accepts the supported complete migration format', () {
    final payload = MigrationPayload.fromJson(jsonEncode(validPayload()));
    expect(payload.sourceSha256, 'a' * 64);
    expect(payload.sourceCounts['work_items'], 0);
  });

  test('rejects unsupported migration format versions', () {
    final raw = validPayload()..['formatVersion'] = 99;
    expect(
      () => MigrationPayload.fromJson(jsonEncode(raw)),
      throwsFormatException,
    );
  });

  test('rejects source count mismatches before database writes', () {
    final raw = validPayload();
    (raw['validation']['sourceCounts'] as Map<String, dynamic>)['work_items'] = 1;
    expect(
      () => MigrationPayload.fromJson(jsonEncode(raw)),
      throwsFormatException,
    );
  });
}
