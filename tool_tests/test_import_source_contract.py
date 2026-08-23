import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class ImportSourceContractTest(unittest.TestCase):
    def test_migration_model_validates_format_version_and_counts(self):
        text = (ROOT / 'lib/src/migration/migration_models.dart').read_text(encoding='utf-8')
        self.assertIn("supeslam-autivra-migration", text)
        self.assertIn('formatVersion', text)
        self.assertIn('sourceCounts', text)
        self.assertIn('sourceSha256', text)

    def test_database_imports_complete_state_and_is_stable_id_based(self):
        text = (ROOT / 'lib/src/database/local_database.dart').read_text(encoding='utf-8')
        self.assertIn('applyMigrationPayload', text)
        self.assertIn("'journal_versions'", text)
        self.assertIn("'timer_state'", text)
        self.assertIn("where: 'id = ?'", text)
        self.assertIn('incomingRecordIsNewer', text)
        self.assertIn("enqueueEntity(table, id)", text)

    def test_repository_records_checksum_metadata(self):
        text = (ROOT / 'lib/src/repositories/app_repository.dart').read_text(encoding='utf-8')
        self.assertIn('importMigrationJson', text)
        self.assertIn('migration_last_sha256', text)
        self.assertIn('migration_completed_at', text)

    def test_controller_reload_and_cloud_sync_follow_import(self):
        text = (ROOT / 'lib/src/controllers/app_controller.dart').read_text(encoding='utf-8')
        self.assertIn('importMigration', text)
        self.assertIn('timerEngine.reloadFromDatabase', text)
        self.assertIn('syncService.syncNow', text)

    def test_settings_uses_explicit_migration_action(self):
        text = (ROOT / 'lib/src/screens/settings_screen.dart').read_text(encoding='utf-8')
        self.assertIn('Import Existing Autivra4 Progress', text)
        self.assertIn('_importMigration', text)


if __name__ == '__main__':
    unittest.main()
