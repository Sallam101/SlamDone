from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneV7143TableJournalContractTest(unittest.TestCase):
    def read(self, rel: str) -> str:
        return (ROOT / rel).read_text(encoding='utf-8')

    def test_table_editor_uses_simple_content_sized_two_axis_canvas(self):
        src = self.read('lib/src/screens/study_tables_screen.dart')
        self.assertIn('_buildTableCanvas(controller, totalWidth)', src)
        start = src.index('Widget _buildTableCanvas(')
        end = src.index('Widget _buildHeaderRow(', start)
        canvas = src[start:end]
        self.assertGreaterEqual(canvas.count('SingleChildScrollView('), 2)
        self.assertIn('scrollDirection: Axis.horizontal', canvas)
        self.assertIn('scrollDirection: Axis.vertical', canvas)
        self.assertIn('child: Column(', canvas)
        self.assertIn('constraints.maxWidth.isFinite', canvas)
        self.assertIn('constraints.maxHeight.isFinite', canvas)
        self.assertNotIn('ListView(', canvas)
        self.assertNotIn('IntrinsicHeight(', canvas)

    def test_new_table_copy_uses_tables_naming_and_has_initial_editable_row(self):
        screen = self.read('lib/src/screens/study_tables_screen.dart')
        repo = self.read('lib/src/repositories/app_repository.dart')
        self.assertIn("TextEditingController(text: 'New table')", screen)
        self.assertIn("columnsJson: jsonEncode(['Topic', 'Status'])", repo)
        self.assertIn("rowsJson: jsonEncode([['', '']])", repo)
        self.assertIn("label: const Text('Add row')", screen)
        self.assertIn("label: const Text('Add column')", screen)

    def test_journal_card_has_direct_delete_button_and_menu_delete(self):
        src = self.read('lib/src/screens/journal_screen.dart')
        self.assertIn("tooltip: 'Delete journal page'", src)
        self.assertIn('onPressed: () => _confirmDeleteJournal(entry)', src)
        self.assertIn('Future<void> _confirmDeleteJournal(JournalEntry entry) async', src)
        self.assertIn("PopupMenuItem(value: 'delete'", src)
        menu_start = src.index('Widget _entryMenu(')
        menu_end = src.index('bool _matchesPeriod(', menu_start)
        menu = src[menu_start:menu_end]
        self.assertIn("await _confirmDeleteJournal(entry);", menu)

    def test_journal_delete_remains_soft_delete_and_refreshes_view(self):
        controller = self.read('lib/src/controllers/app_controller.dart')
        repo = self.read('lib/src/repositories/app_repository.dart')
        self.assertIn('Future<void> deleteJournal(JournalEntry entry)', controller)
        delete_controller = controller[controller.index('Future<void> deleteJournal(JournalEntry entry)'):]
        delete_controller = delete_controller[:delete_controller.index('Future<void> snapshotJournal')]
        self.assertIn('await repository.deleteJournal(entry);', delete_controller)
        self.assertIn('await refreshJournals();', delete_controller)
        delete_repo = repo[repo.index('Future<void> deleteJournal(JournalEntry entry)'):]
        delete_repo = delete_repo[:delete_repo.index('Future<void> snapshotJournal')]
        self.assertIn('deletedAt: now', delete_repo)

    def test_release_version_is_7143(self):
        pubspec = self.read('pubspec.yaml')
        self.assertRegex(pubspec, r'(?m)^version:\s*7\.14\.3\+243\s*$')


if __name__ == '__main__':
    unittest.main()
