from pathlib import Path
import hashlib
import unittest
import re

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneV751FilterContractTest(unittest.TestCase):
    def read(self, rel):
        return (ROOT / rel).read_text(encoding='utf-8')

    def sha256(self, rel):
        return hashlib.sha256((ROOT / rel).read_bytes()).hexdigest()

    def test_big_picture_status_filters_remain_independent_in_new_tucked_header(self):
        big = self.read('lib/src/screens/big_picture_screen.dart')
        self.assertIn('bool _controlsExpanded = false;', big)
        self.assertIn("readUiSetting('big_picture_controls_expanded')", big)
        self.assertIn('writeUiSetting(', big)
        self.assertIn("'big_picture_controls_expanded'", big)
        self.assertIn("label: const Text('More filters')", big)

    def test_all_is_a_show_all_shortcut_and_statuses_remain_independent(self):
        big = self.read('lib/src/screens/big_picture_screen.dart')
        self.assertIn('_toggleStatus(status)', big)
        self.assertIn('_visibleStatuses = WorkStatus.values.toSet();', big)
        self.assertNotIn("selected: _visibleStatuses.length == WorkStatus.values.length", big)


    def test_version_is_v751_or_later(self):
        pubspec = self.read('pubspec.yaml')
        match = re.search(r'version:\s*(\d+)\.(\d+)\.(\d+)\+', pubspec)
        self.assertIsNotNone(match)
        self.assertGreaterEqual(tuple(map(int, match.groups())), (7, 5, 1))


if __name__ == '__main__':
    unittest.main()
