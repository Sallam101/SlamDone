import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

class SlamDoneV76MobileContractTest(unittest.TestCase):
    def read(self, rel):
        return (ROOT / rel).read_text(encoding='utf-8')

    def test_sync_has_debounced_push_and_resume_reconciliation(self):
        sync = self.read('lib/src/services/sync_service.dart')
        home = self.read('lib/src/screens/home_shell.dart')
        controller = self.read('lib/src/controllers/app_controller.dart')
        self.assertIn('void schedulePush(', sync)
        self.assertIn('_scheduledPushTimer', sync)
        self.assertIn('Future<void> handleAppResumed()', sync)
        self.assertIn('AppLifecycleState.resumed', home)
        self.assertIn('WidgetsBindingObserver', home)
        self.assertIn('syncService.schedulePush()', controller)

    def test_habits_have_phone_first_daily_cards(self):
        habits = self.read('lib/src/screens/habits_screen.dart')
        self.assertIn('width < 700', habits)
        self.assertIn('_buildMobileHabits', habits)
        self.assertIn('Log for this day', habits)
        self.assertIn("Icons.remove_rounded", habits)
        self.assertIn("Icons.add_rounded", habits)
        self.assertIn('_mobileDate', habits)

    def test_tasks_have_compact_mobile_toolbar_and_actions(self):
        tasks = self.read('lib/src/screens/tasks_screen.dart')
        tree = self.read('lib/src/widgets/work_item_tree_list.dart')
        self.assertIn('_mobileFiltersVisible', tasks)
        self.assertIn('_buildMobileToolbar', tasks)
        self.assertIn("Icons.filter_alt_outlined", tasks)
        self.assertIn('PopupMenuButton<String>', tree)
        self.assertIn("value: 'focus'", tree)
        self.assertIn("value: 'edit'", tree)

    def test_big_picture_defaults_to_mobile_hierarchy_without_touching_desktop_view(self):
        big = self.read('lib/src/screens/big_picture_screen.dart')
        structured = self.read('lib/src/widgets/structured_hierarchy_view.dart')
        self.assertIn('final mobile = MediaQuery.sizeOf(context).width < 700;', big)
        self.assertIn("label: Text('Hierarchy')", big)
        self.assertIn('WorkItemTreeList(', big)
        self.assertIn('StructuredHierarchyView(', big)
        self.assertIn('math.max(720.0, viewport.maxWidth - 86)', structured)

    def test_big_picture_mobile_flag_is_declared_in_build_scope(self):
        big = self.read('lib/src/screens/big_picture_screen.dart')
        build_start = big.index('Widget build(BuildContext context)')
        return_start = big.index('return Padding(', build_start)
        build_prefix = big[build_start:return_start]
        self.assertIn('final mobile = MediaQuery.sizeOf(context).width < 700;', build_prefix)

    def test_version_is_761(self):
        pubspec = self.read('pubspec.yaml')
        self.assertRegex(pubspec, r'version:\s*7\.6\.1\+')

if __name__ == '__main__':
    unittest.main()
