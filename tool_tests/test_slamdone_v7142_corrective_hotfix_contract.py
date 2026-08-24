from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneV7142CorrectiveHotfixContractTest(unittest.TestCase):
    def read(self, rel: str) -> str:
        return (ROOT / rel).read_text(encoding='utf-8')

    def test_journal_editor_rebuilds_after_async_load(self):
        src = self.read('lib/src/screens/journal_editor_screen.dart')
        load = src[src.index('Future<void> _load() async'):src.index('String _valueFor')]
        self.assertIn('if (mounted) {', load)
        self.assertRegex(load, r'setState\(\(\)\s*\{?\s*\}?\);')

    def test_journal_has_delete_action_and_soft_delete_controller_api(self):
        screen = self.read('lib/src/screens/journal_screen.dart')
        controller = self.read('lib/src/controllers/app_controller.dart')
        repo = self.read('lib/src/repositories/app_repository.dart')
        self.assertIn("value == 'delete'", screen)
        self.assertIn("PopupMenuItem(value: 'delete'", screen)
        self.assertIn('deleteJournal(entry)', screen)
        self.assertIn('Future<void> deleteJournal(JournalEntry entry)', controller)
        self.assertIn('Future<void> deleteJournal(JournalEntry entry)', repo)
        self.assertIn('deletedAt: DateTime.now().toUtc()', repo)

    def test_habit_scrollbar_has_reserved_header_strip_not_first_row_overlay(self):
        src = self.read('lib/src/screens/habits_screen.dart')
        self.assertIn('static const double _dayLabelHeight = 60.0;', src)
        self.assertRegex(src, r'static const double _dayHeaderHeight\s*=\s*_dayLabelHeight\s*\+\s*16\.0;')
        self.assertIn('crossAxisMargin: _dayLabelHeight,', src)
        self.assertIn('final contentHeight =\n        _dayHeaderHeight +', src)
        self.assertIn('onChanged: (checked) =>', src)
        self.assertIn('onSet(habit, key, checked == true ? 1 : 0)', src)
        totals = src[src.index('class _HabitTotalsColumn'):src.index('class _HabitTotalCell')]
        self.assertIn('height: _HabitsScreenState._dayHeaderHeight,', totals)

    def test_tables_have_safe_fixed_header_height_and_simple_add_controls(self):
        src = self.read('lib/src/screens/study_tables_screen.dart')
        repo = self.read('lib/src/repositories/app_repository.dart')
        self.assertIn('static const double _tableHeaderHeight = 58.0;', src)
        self.assertNotIn('return IntrinsicHeight(', src)
        self.assertIn('height: _tableHeaderHeight,', src)
        self.assertIn("label: const Text('Add row')", src)
        self.assertIn("label: const Text('Add column')", src)
        self.assertIn("rowsJson: jsonEncode([['', '']]),", repo)

    def test_action_messages_hard_close_after_exactly_five_seconds(self):
        shell = self.read('lib/src/screens/home_shell.dart')
        controller = self.read('lib/src/controllers/app_controller.dart')
        self.assertIn('const _actionMessageLifetime = Duration(seconds: 5);', shell)
        self.assertIn('duration: _actionMessageLifetime,', shell)
        self.assertIn('Timer(_actionMessageLifetime, snackController.close);', shell)
        self.assertIn('Timer? _messageClearTimer;', controller)
        self.assertIn('const Duration(seconds: 5)', controller)
        self.assertIn("void _setMessage(String value)", controller)
        self.assertNotRegex(controller, r"\bmessage\s*=\s*'Floating timer opened inside SlamDone\.'")
        schedule = controller[controller.index('void _scheduleAutoArchiveIfNeeded'):controller.index('Future<void> undoAutoArchive')]
        self.assertIn('Timer(const Duration(seconds: 5)', schedule)
        self.assertIn('autoArchiveNotice = null;', schedule)

    def test_focus_and_tables_are_renamed_for_defaults_existing_tabs_and_titles(self):
        controller = self.read('lib/src/controllers/app_controller.dart')
        focus = self.read('lib/src/screens/focus_screen.dart')
        tables = self.read('lib/src/screens/study_tables_screen.dart')
        self.assertNotIn("label: 'Focus To Win'", controller)
        self.assertNotIn("label: 'Study Tables'", controller)
        self.assertIn("label: 'Focus'", controller)
        self.assertIn("label: 'Tables'", controller)
        self.assertIn("item.label == 'Focus To Win' ? 'Focus'", controller)
        self.assertIn("item.label == 'Study Tables' ? 'Tables'", controller)
        self.assertNotIn("'Focus To Win'", focus)
        self.assertIn("'Focus'", focus)
        self.assertNotIn("'Study Tables'", tables)
        self.assertIn("'Tables'", tables)

    def test_release_version_is_7142_or_later(self):
        pubspec = self.read('pubspec.yaml')
        self.assertRegex(pubspec, r'(?m)^version:\s*7\.14\.(?:2\+242|3\+243|4\+244)\s*$')


if __name__ == '__main__':
    unittest.main()
