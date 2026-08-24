import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneV714ContractTest(unittest.TestCase):
    def read(self, relative):
        return (ROOT / relative).read_text(encoding='utf-8')

    def test_shared_uncategorized_predicate_is_used_by_all_three_views(self):
        util_path = ROOT / 'lib/src/utils/work_item_filters.dart'
        self.assertTrue(util_path.exists())
        util = util_path.read_text(encoding='utf-8')
        tasks = self.read('lib/src/screens/tasks_screen.dart')
        big = self.read('lib/src/screens/big_picture_screen.dart')
        mind = self.read('lib/src/screens/mind_map_screen.dart')
        self.assertIn('bool isUncategorizedTask(WorkItem item)', util)
        self.assertIn('item.type == WorkItemType.task', util)
        self.assertIn('item.parentId == null', util)
        self.assertIn("item.folder == 'Uncategorized'", util)
        self.assertIn('isUncategorizedTask(item)', tasks)
        self.assertIn('isUncategorizedTask(item)', big)
        self.assertIn('isUncategorizedTask(item)', mind)

    def test_big_picture_and_mind_map_have_default_on_uncategorized_chips(self):
        big = self.read('lib/src/screens/big_picture_screen.dart')
        mind = self.read('lib/src/screens/mind_map_screen.dart')
        self.assertIn('_showUncategorized = true', big)
        self.assertIn("Text('Uncategorized')", big)
        self.assertIn('_showUncategorized = true', mind)
        self.assertIn("Text('Uncategorized')", mind)
        self.assertRegex(big, r'!_showUncategorized\s*&&\s*isUncategorizedTask\(item\)')
        self.assertRegex(mind, r'!_showUncategorized\s*&&\s*isUncategorizedTask\(item\)')

    def test_reversible_time_session_ledger_interfaces_exist(self):
        repo = self.read('lib/src/repositories/app_repository.dart')
        controller = self.read('lib/src/controllers/app_controller.dart')
        self.assertIn('Future<TimeSession> createManualFocusSession', repo)
        self.assertIn("notes: '[slamdone:manual-focus]'", repo)
        self.assertIn('Future<TimeSession?> softDeleteTimeSession', repo)
        self.assertIn('Future<TimeSession?> restoreTimeSession', repo)
        self.assertIn('deletedAt: now', repo)
        self.assertIn('TimeSession _copyTimeSessionForLedger', repo)
        self.assertIn('revision: current.revision + 1', repo)
        self.assertIn('List<TimeSession> get todayFocusSessions', controller)
        self.assertIn('Future<TimeSession> addManualFocusSession()', controller)
        self.assertIn('Future<TimeSession?> removeFocusSession(String id)', controller)
        self.assertIn('Future<TimeSession?> restoreFocusSession(String id)', controller)
        self.assertIn('_scheduleCloudPush();', controller)

    def test_today_metrics_are_completed_non_stopwatch_only(self):
        controller = self.read('lib/src/controllers/app_controller.dart')
        start = controller.index('List<TimeSession> get todayFocusSessions')
        block = controller[start:start + 1400]
        self.assertIn('session.completed', block)
        self.assertIn('session.mode != TimerMode.stopwatch', block)
        self.assertIn('int get todayMinutes => todayFocusSessions.fold<int>', block)

    def test_today_squares_are_exact_session_ledger_controls(self):
        focus = self.read('lib/src/screens/focus_screen.dart')
        self.assertIn('final todaySessions = controller.todayFocusSessions;', focus)
        self.assertIn('total > todaySessions.length', focus)
        self.assertIn(': todaySessions.length;', focus)
        self.assertIn('session.id', focus)
        self.assertIn('controller.addManualFocusSession()', focus)
        self.assertIn('controller.removeFocusSession(session.id)', focus)
        self.assertIn('controller.restoreFocusSession(session.id)', focus)
        self.assertIn('session.elapsedSeconds', focus)
        self.assertIn('Tooltip(', focus)
        self.assertIn("label: 'Undo'", focus)

    def test_timer_freezes_running_state_on_restart_and_long_gap(self):
        timer = self.read('lib/src/services/timer_engine.dart')
        self.assertIn('suspensionGapThreshold = Duration(seconds: 5)', timer)
        self.assertIn('Future<void> _freezeForInterruption', timer)
        self.assertIn('if (_state.running && !_state.paused)', timer)
        self.assertIn('now.difference(_state.updatedAt)', timer)
        self.assertIn('gap > suspensionGapThreshold', timer)
        freeze_start = timer.index('Future<void> _freezeForInterruption')
        freeze_end = timer.index('TimerStateRecord _calculateCurrent', freeze_start)
        freeze = timer[freeze_start:freeze_end]
        self.assertIn('running: false', freeze)
        self.assertIn('paused: true', freeze)
        self.assertIn('startedAt: null', freeze)
        self.assertIn('endAt: null', freeze)
        self.assertNotIn('_calculateCurrent', freeze)

    def test_explicit_pause_still_accounts_for_short_legitimate_interval(self):
        timer = self.read('lib/src/services/timer_engine.dart')
        pause_start = timer.index('Future<void> pause()')
        pause = timer[pause_start:pause_start + 700]
        self.assertIn('_calculateCurrent(_state, now)', pause)
        self.assertIn('paused: true', pause)

    def test_release_version_is_7140_and_protected_integrations_remain(self):
        pubspec = self.read('pubspec.yaml')
        workflow = self.read('.github/workflows/pages.yml')
        support = self.read('lib/src/services/support_links_web.dart')
        self.assertIn('version: 7.14.2+242', pubspec)
        self.assertNotIn('windows-latest', workflow)
        self.assertNotIn('companion:', workflow)
        self.assertIn('flutter build web --release --base-href /SlamDone/', workflow)
        self.assertIn('slamDoneOpenPatreonSupport', support)


if __name__ == '__main__':
    unittest.main()
