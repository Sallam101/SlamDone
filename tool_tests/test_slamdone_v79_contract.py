import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


class SlamDoneV79ContractTest(unittest.TestCase):
    def test_work_items_reconcile_parent_first_and_report_orphans(self):
        db = read('lib/src/database/local_database.dart')
        sync = read('lib/src/services/sync_service.dart')
        self.assertIn('class WorkItemMergeReport', db)
        self.assertIn('mergeRemoteWorkItemsParentFirst', db)
        self.assertIn('pending', db)
        self.assertIn('knownIds', db)
        self.assertIn('orphanIds', db)
        self.assertIn("entityType == 'work_items'", sync)
        self.assertIn('mergeRemoteWorkItemsParentFirst', sync)
        self.assertIn('authoritativeUploadIds', sync)

    def test_primary_pc_is_explicit_and_persisted(self):
        sync = read('lib/src/services/sync_service.dart')
        settings = read('lib/src/screens/settings_screen.dart')
        self.assertIn("'primary_device_id'", sync)
        self.assertIn('primaryDeviceId', sync)
        self.assertIn('isPrimaryDevice', sync)
        self.assertIn('makeThisPrimaryDevice', sync)
        self.assertIn('Make this my Primary PC', settings)
        self.assertIn('Primary PC', settings)

    def test_primary_metadata_is_loaded_before_structural_reconciliation(self):
        sync = read('lib/src/services/sync_service.dart')
        settings_pos = sync.index('await _reconcileSettings(user);')
        entities_pos = sync.index('await _reconcileAllEntities(user);')
        self.assertLess(settings_pos, entities_pos)

    def test_primary_pc_claims_existing_migrated_structure(self):
        db = read('lib/src/database/local_database.dart')
        sync = read('lib/src/services/sync_service.dart')
        self.assertIn('claimPrimaryStructuralAuthority', db)
        self.assertIn("['work_items', 'canvas_layouts', 'northstar_notes']", db)
        self.assertIn('database.claimPrimaryStructuralAuthority(_localDeviceId)', sync)

    def test_primary_authority_preserves_structure_but_accepts_progress(self):
        db = read('lib/src/database/local_database.dart')
        sync = read('lib/src/services/sync_service.dart')
        for key in ['title', 'parent_id', 'due_date', 'priority', 'notes', 'folder']:
            self.assertIn(key, db)
        for key in ['status', 'gtd_status', 'checklist_done']:
            self.assertIn(key, db)
        self.assertIn('_mergeWorkItemWithPrimaryAuthority', db)
        self.assertIn('_localShouldUpload', sync)
        self.assertIn('primaryDeviceId', sync)

    def test_dependent_rows_skip_missing_work_item_foreign_keys(self):
        db = read('lib/src/database/local_database.dart')
        self.assertIn('_remoteForeignKeysExist', db)
        self.assertIn("entityType == 'canvas_layouts'", db)
        self.assertIn("entityType == 'time_sessions'", db)

    def test_tasks_command_center_has_requested_toggle_filters(self):
        tasks = read('lib/src/screens/tasks_screen.dart')
        for label in [
            'Active', 'Uncategorized', 'Completed', 'Archived', 'Urgent',
            'Overdue', 'Due Today', 'This Week', 'Undated', 'All active',
            'Clear filters',
        ]:
            self.assertIn(label, tasks)
        self.assertIn('_showActive = true', tasks)
        self.assertIn('_showCompleted = false', tasks)
        self.assertIn('_showArchived = false', tasks)
        self.assertIn('_showUncategorized = false', tasks)
        self.assertIn('_smartFilterMatches', tasks)
        self.assertIn('SingleChildScrollView', tasks)
        self.assertIn('scrollDirection: Axis.horizontal', tasks)

    def test_task_filter_preferences_are_local_per_device(self):
        tasks = read('lib/src/screens/tasks_screen.dart')
        controller = read('lib/src/controllers/app_controller.dart')
        self.assertIn('writeLocalUiSetting', controller)
        self.assertIn('writeLocalUiSetting', tasks)
        self.assertNotIn("writeUiSetting('tasks_filter'", tasks)

    def test_quick_task_remains_uncategorized_and_full_editor_remains(self):
        repo = read('lib/src/repositories/app_repository.dart')
        tasks = read('lib/src/screens/tasks_screen.dart')
        self.assertIn("folder: 'Uncategorized'", repo)
        self.assertIn('showWorkItemEditor', tasks)
        self.assertIn('Quick task', tasks)

    def test_release_version_is_790(self):
        pubspec = read('pubspec.yaml')
        changelog = read('CHANGELOG.md')
        self.assertRegex(pubspec, r'version:\s*7\.(?:10\.0|9\.0)\+')
        self.assertIn('7.9.0', changelog)


if __name__ == '__main__':
    unittest.main()
