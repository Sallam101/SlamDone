#!/usr/bin/env python3
"""Generate a private, complete SlamDone migration JSON from an Autivra SQLite DB."""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

ENTITY_TABLES = (
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
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def fetch_rows(connection: sqlite3.Connection, table: str) -> list[dict]:
    return [dict(row) for row in connection.execute(f'SELECT * FROM "{table}"')]


def generate(source: Path) -> dict:
    if not source.is_file():
        raise FileNotFoundError(source)

    connection = sqlite3.connect(source)
    connection.row_factory = sqlite3.Row
    try:
        integrity = connection.execute('PRAGMA integrity_check').fetchone()[0]
        if integrity != 'ok':
            raise RuntimeError(f'SQLite integrity check failed: {integrity}')
        schema = int(connection.execute('PRAGMA user_version').fetchone()[0])

        entities = {table: fetch_rows(connection, table) for table in ENTITY_TABLES}
        setting_rows = fetch_rows(connection, 'app_settings')
        settings = {
            str(row['setting_key']): str(row['setting_value']) for row in setting_rows
        }
        timer_rows = fetch_rows(connection, 'timer_state')
        timer_state = timer_rows[0] if timer_rows else {}

        source_counts = {table: len(rows) for table, rows in entities.items()}
        source_counts['app_settings'] = len(setting_rows)
        source_counts['timer_state'] = len(timer_rows)

        return {
            'format': 'supeslam-autivra-migration',
            'formatVersion': 1,
            'source': {
                'application': 'Autivra4',
                'version': '6.4.1',
                'databaseSchema': schema,
                'sha256': sha256_file(source),
            },
            'exportedAt': datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
            'entities': entities,
            'timer_state': timer_state,
            'settings': settings,
            'validation': {
                'integrityCheck': integrity,
                'sourceCounts': source_counts,
            },
        }
    finally:
        connection.close()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('source_db', type=Path)
    parser.add_argument('output_json', type=Path)
    args = parser.parse_args()

    payload = generate(args.source_db)
    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    args.output_json.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False),
        encoding='utf-8',
    )
    print(json.dumps(payload['validation']['sourceCounts'], sort_keys=True))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
