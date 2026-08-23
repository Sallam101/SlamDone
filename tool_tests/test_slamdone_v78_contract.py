from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]

class SlamDoneV78ContractTest(unittest.TestCase):
    def read(self, rel):
        return (ROOT / rel).read_text(encoding='utf-8')

    def test_version_is_780_or_later(self):
        pubspec = self.read('pubspec.yaml')
        match = re.search(r'version:\s*(\d+)\.(\d+)\.(\d+)\+', pubspec)
        self.assertIsNotNone(match)
        self.assertGreaterEqual(tuple(map(int, match.groups())), (7, 8, 0))

    def test_manual_sync_repair_is_isolated_and_reports_real_table_failures(self):
        src = self.read('lib/src/services/sync_service.dart')
        self.assertIn('Future<void> verifyAndRepair()', src)
        self.assertIn('_auditErrors', src)
        self.assertIn('_verificationStep', src)
        self.assertIn('await _cancelRealtime();', src)
        self.assertIn("'Sync incomplete", src)
        self.assertIn('verificationDetail', src)
        # Full verification must re-read Firestore after repair writes instead of
        # using a synthetic local/remote union count.
        self.assertRegex(src, r'final verifySnapshot = await root\.collection\(entityType\)\.get\(\);')
        self.assertNotIn("cloudCounts[entityType] = {...remoteById.keys, ...localIds}.length", src)
        self.assertIn('FirebaseFirestore.instance.batch()', src)
        self.assertIn('batchedGroups', src)

    def test_push_only_timer_cannot_hide_a_full_repair_error(self):
        src = self.read('lib/src/services/sync_service.dart')
        # Push-only runs should not overwrite verification/error state.
        self.assertIn('if (pullRemote) {', src)
        self.assertIn('else if (_verified)', src)
        self.assertIn('else if (_auditErrors.isNotEmpty)', src)

    def test_settings_uses_verify_and_repair_and_shows_diagnostics(self):
        src = self.read('lib/src/screens/settings_screen.dart')
        self.assertGreaterEqual(src.count('sync.verifyAndRepair()'), 2)
        self.assertIn('sync.verificationDetail', src)
        self.assertIn('sync.auditErrors', src)

    def test_journal_typing_does_not_rebuild_whole_editor_per_keystroke(self):
        src = self.read('lib/src/screens/journal_editor_screen.dart')
        self.assertIn('ValueNotifier<String>', src)
        self.assertIn('const Duration(milliseconds: 900)', src)
        self.assertIn('notifyGlobal: false', src)
        queue = src[src.index('void _queueSave()'):src.index('JournalEntry _draft()')]
        self.assertNotIn('setState(', queue)
        self.assertIn('_dirty = true;', queue)

    def test_controller_supports_silent_journal_autosave(self):
        src = self.read('lib/src/controllers/app_controller.dart')
        self.assertIn('bool notifyGlobal = true', src)
        self.assertIn('if (notifyGlobal) notifyListeners();', src)

    def test_tasks_have_quick_uncategorized_capture_on_phone_and_pc(self):
        screen = self.read('lib/src/screens/tasks_screen.dart')
        controller = self.read('lib/src/controllers/app_controller.dart')
        repo = self.read('lib/src/repositories/app_repository.dart')
        self.assertIn("hintText: 'Quick task…'", screen)
        self.assertIn('_addQuickTask', screen)
        self.assertIn('controller.createQuickTask', screen)
        self.assertIn('Future<WorkItem> createQuickTask', controller)
        self.assertIn('Future<WorkItem> createQuickTask', repo)
        self.assertIn("folder: 'Uncategorized'", repo)
        self.assertIn('gtdStatus: GtdStatus.inbox', repo)
        # Existing detailed editor remains available.
        self.assertGreaterEqual(screen.count('showWorkItemEditor('), 2)

if __name__ == '__main__':
    unittest.main()
