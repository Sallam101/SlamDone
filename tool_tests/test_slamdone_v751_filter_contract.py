from pathlib import Path
import hashlib
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneV751FilterContractTest(unittest.TestCase):
    def read(self, rel):
        return (ROOT / rel).read_text(encoding='utf-8')

    def sha256(self, rel):
        return hashlib.sha256((ROOT / rel).read_bytes()).hexdigest()

    def test_big_picture_filter_toolbar_can_be_hidden_independently(self):
        big = self.read('lib/src/screens/big_picture_screen.dart')
        self.assertIn('bool _filterBarVisible = false;', big)
        self.assertIn('bool _advancedFiltersVisible = false;', big)
        self.assertIn("readUiSetting('big_picture_filters_visible')", big)
        self.assertIn("writeUiSetting('big_picture_filters_visible'", big)
        self.assertIn("label: Text(_filterBarVisible ? 'Hide filters' : 'Filters')", big)
        self.assertIn('_filterBarVisible\n', big)
        self.assertIn("label: const Text('More filters')", big)

    def test_all_is_a_show_all_shortcut_and_statuses_remain_independent(self):
        big = self.read('lib/src/screens/big_picture_screen.dart')
        self.assertIn('_toggleStatus(status)', big)
        self.assertIn('_visibleStatuses = WorkStatus.values.toSet();', big)
        self.assertNotIn("selected: _visibleStatuses.length == WorkStatus.values.length", big)

    def test_card_structure_files_are_byte_for_byte_unchanged_from_v750(self):
        expected = {
            'lib/src/widgets/structured_hierarchy_view.dart': '260ccc1f962793afd18509e0da1795ab405953e581cfc486dc07ae9f9ea3acdd',
            'lib/src/widgets/canvas_workspace.dart': '2c8a0c26f0804d6b30e65e5ee56f41659367373584d7f4f394a7bd1c92f7bcde',
            'lib/src/widgets/hierarchy_layout.dart': 'df4d27494ed3c6f4d48dd9f793a00d92a7eb28ff3e1094f73ac9cbd59855f792',
            'lib/src/widgets/work_item_tree_list.dart': 'caab8da4f0a3964a9ce700b6c31bba5a1651fc06a22eda990f8ec3453fa760fd',
        }
        for path, digest in expected.items():
            self.assertEqual(self.sha256(path), digest, path)

    def test_version_is_v751(self):
        self.assertIn('version: 7.5.1+151', self.read('pubspec.yaml'))


if __name__ == '__main__':
    unittest.main()
