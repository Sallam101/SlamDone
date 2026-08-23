import json
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GENERATOR = ROOT / 'tools' / 'generate_autivra_migration.py'
ENTITY_TABLES = [
    'work_items', 'canvas_layouts', 'journal_entries', 'journal_versions',
    'time_sessions', 'habits', 'habit_entries', 'northstar_notes',
    'reward_ranks', 'study_tables',
]


class MigrationGeneratorTest(unittest.TestCase):
    def test_exports_complete_migration_without_sync_queue(self):
        with tempfile.TemporaryDirectory() as tmp:
            db = Path(tmp) / 'source.db'
            out = Path(tmp) / 'migration.json'
            con = sqlite3.connect(db)
            for table in ENTITY_TABLES:
                con.execute(f'CREATE TABLE {table} (id TEXT PRIMARY KEY, value TEXT)')
                con.execute(f'INSERT INTO {table} VALUES (?, ?)', (f'{table}-1', 'x'))
            con.execute('CREATE TABLE app_settings (setting_key TEXT PRIMARY KEY, setting_value TEXT, updated_at TEXT)')
            con.execute("INSERT INTO app_settings VALUES ('theme_mode','dark','2026-08-23T07:00:00Z')")
            con.execute('CREATE TABLE timer_state (id INTEGER PRIMARY KEY, title TEXT, client_updated_at TEXT)')
            con.execute("INSERT INTO timer_state VALUES (1,'General focus','2026-08-23T07:00:00Z')")
            con.execute('CREATE TABLE sync_queue (queue_id INTEGER PRIMARY KEY, entity_type TEXT)')
            con.execute("INSERT INTO sync_queue VALUES (1,'work_items')")
            con.execute('PRAGMA user_version = 6')
            con.commit()
            con.close()

            subprocess.run([sys.executable, str(GENERATOR), str(db), str(out)], check=True)
            payload = json.loads(out.read_text(encoding='utf-8'))

            self.assertEqual(payload['format'], 'supeslam-autivra-migration')
            self.assertEqual(payload['formatVersion'], 1)
            self.assertEqual(payload['source']['databaseSchema'], 6)
            for table in ENTITY_TABLES:
                self.assertEqual(len(payload['entities'][table]), 1)
                self.assertEqual(payload['validation']['sourceCounts'][table], 1)
            self.assertEqual(payload['settings']['theme_mode'], 'dark')
            self.assertEqual(payload['timer_state']['title'], 'General focus')
            self.assertNotIn('sync_queue', payload)
            self.assertRegex(payload['source']['sha256'], r'^[0-9a-f]{64}$')


if __name__ == '__main__':
    unittest.main()
