import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class SlamDoneV77ContractTest(unittest.TestCase):
    def read(self, rel):
        return (ROOT / rel).read_text(encoding='utf-8')

    def test_sync_full_reconciliation_repairs_missing_cloud_rows(self):
        sync = self.read('lib/src/services/sync_service.dart')
        db = self.read('lib/src/database/local_database.dart')
        self.assertIn('Future<void> _reconcileAllEntities(User user)', sync)
        self.assertIn('await database.loadRowsForSync(entityType)', sync)
        self.assertIn('incomingRecordIsNewer(localRow, remoteRow)', sync)
        self.assertIn('await _pushEntityPayload(', sync)
        self.assertIn('Future<List<Map<String, Object?>>> loadRowsForSync(', db)

    def test_google_sign_in_releases_busy_gate_before_first_full_sync(self):
        sync = self.read('lib/src/services/sync_service.dart')
        start = sync.index('Future<String> signInWithGoogle()')
        end = sync.index('Future<void> signOut()', start)
        block = sync[start:end]
        self.assertIn('_busy = false;', block)
        self.assertLess(block.index('_busy = false;'), block.index('await syncNow();'))
        self.assertNotIn("isSignedIn ? 'SlamDone Firestore synced'", block)

    def test_sync_status_only_claims_verified_after_full_audit(self):
        sync = self.read('lib/src/services/sync_service.dart')
        settings = self.read('lib/src/screens/settings_screen.dart')
        self.assertIn('bool _verified = false;', sync)
        self.assertIn('Map<String, int> get localAuditCounts', sync)
        self.assertIn('Map<String, int> get cloudAuditCounts', sync)
        self.assertIn("_status = 'Realtime connected — verifying planner data…';", sync)
        self.assertIn("_status = _verifiedStatus();", sync)
        self.assertIn('Verify & repair sync', settings)
        self.assertIn('Sync audit', settings)

    def test_realtime_changes_keep_audit_current_and_local_pushes_reverify(self):
        sync = self.read('lib/src/services/sync_service.dart')
        self.assertIn('_verificationTimer', sync)
        self.assertIn('void _scheduleVerificationAudit(', sync)
        self.assertIn("_status = 'Realtime connected — verifying planner data…';", sync)
        self.assertIn('entityType: snapshot.docs.length', sync)
        self.assertIn('_auditCountsMatch()', sync)
        self.assertIn('_scheduleVerificationAudit(delay:', sync)

    def test_mobile_big_picture_controls_are_compact_and_collapsible(self):
        big = self.read('lib/src/screens/big_picture_screen.dart')
        self.assertIn('_mobileControlsVisible', big)
        self.assertIn('mobile ? _buildMobileHeader', big)
        self.assertIn("tooltip: 'Big Picture filters'", big)
        self.assertIn('AnimatedSize(', big)

    def test_mobile_journal_do_first_and_northstar_controls_collapse(self):
        journal = self.read('lib/src/screens/journal_screen.dart')
        do_first = self.read('lib/src/screens/do_first_screen.dart')
        northstar = self.read('lib/src/screens/northstar_screen.dart')
        self.assertIn('_mobileControlsVisible', journal)
        self.assertIn("tooltip: 'Journal controls'", journal)
        self.assertIn('_mobileFiltersVisible', do_first)
        self.assertIn("tooltip: 'Do First filters'", do_first)
        self.assertIn('_mobileControlsVisible', northstar)
        self.assertIn("tooltip: 'NorthStar controls'", northstar)

    def test_mobile_focus_goal_panels_collapse_by_default(self):
        focus = self.read('lib/src/screens/focus_screen.dart')
        self.assertIn('_mobileGoalsVisible', focus)
        self.assertIn("title: const Text('Focus goals')", focus)
        self.assertIn('if (!mobile || _mobileGoalsVisible) ...[', focus)

    def test_autivra_reverse_export_matches_native_v6_shape(self):
        repo = self.read('lib/src/repositories/app_repository.dart')
        controller = self.read('lib/src/controllers/app_controller.dart')
        settings = self.read('lib/src/screens/settings_screen.dart')
        self.assertIn('Future<String?> exportForAutivra4()', repo)
        self.assertIn("'version': 6", repo)
        self.assertIn("'application': 'Autivra4'", repo)
        self.assertIn('autivraCompatibleSettingKeys', repo)
        for table in (
            'work_items', 'canvas_layouts', 'journal_entries', 'time_sessions',
            'habits', 'habit_entries', 'northstar_notes', 'reward_ranks',
            'study_tables',
        ):
            self.assertIn(f"'{table}'", repo)
        export_start = repo.index('Future<String?> exportForAutivra4()')
        export_end = repo.index('Future<String?> exportBackup()', export_start)
        export_block = repo[export_start:export_end]
        self.assertNotIn("'journal_versions'", export_block)
        self.assertNotIn("'timer_state'", export_block)
        self.assertIn("'device_id'", repo)
        self.assertIn('autivraTransportSettingKeys.contains', repo)
        self.assertIn('Future<void> exportForAutivra4()', controller)
        export_block = controller[controller.index('Future<void> exportForAutivra4()'):]
        self.assertIn('await syncService.syncNow();', export_block)
        self.assertIn('Export for Autivra4', settings)

    def test_version_is_770_or_later(self):
        import re
        pubspec = self.read('pubspec.yaml')
        match = re.search(r'version:\s*(\d+)\.(\d+)\.(\d+)\+', pubspec)
        self.assertIsNotNone(match)
        self.assertGreaterEqual(tuple(map(int, match.groups())), (7, 7, 0))


if __name__ == '__main__':
    unittest.main()
