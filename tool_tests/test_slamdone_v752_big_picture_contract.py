from pathlib import Path
import hashlib
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneV752BigPictureContractTest(unittest.TestCase):
    def read(self, rel):
        return (ROOT / rel).read_text(encoding='utf-8')

    def sha256(self, rel):
        return hashlib.sha256((ROOT / rel).read_bytes()).hexdigest()

    def test_big_picture_header_tucks_secondary_controls_only(self):
        big = self.read('lib/src/screens/big_picture_screen.dart')
        self.assertIn('bool _controlsExpanded = false;', big)
        self.assertIn("readUiSetting('big_picture_controls_expanded')", big)
        self.assertIn('writeUiSetting(', big)
        self.assertIn("'big_picture_controls_expanded'", big)
        self.assertIn("'Tuck Big Picture controls'", big)
        self.assertIn("'Show Big Picture controls'", big)
        self.assertIn("label: const Text('Active')", big)
        self.assertIn("label: const Text('Completed')", big)
        self.assertIn("label: const Text('Archived')", big)
        self.assertIn("label: const Text('Goal')", big)
        self.assertIn('child: !_controlsExpanded', big)
        self.assertNotIn('Clean hierarchy by default.', big)
        self.assertNotIn('Wheel pan • Middle drag 4-way • Ctrl+wheel zoom', big)

    def test_card_tags_wrap_instead_of_horizontal_scrolling(self):
        structured = self.read('lib/src/widgets/structured_hierarchy_view.dart')
        canvas = self.read('lib/src/widgets/canvas_workspace.dart')
        self.assertIn('Wrap(\n              alignment: WrapAlignment.center,\n              spacing: 4,\n              runSpacing: 3,', structured)
        self.assertNotIn('scrollDirection: Axis.horizontal,\n                child: Row(\n                  mainAxisAlignment: MainAxisAlignment.center,\n                  children: tagWidgets,', structured)
        self.assertIn('Wrap(\n      spacing: 5,\n      runSpacing: 4,\n      children: chips,', canvas)
        self.assertNotIn('scrollDirection: Axis.horizontal,\n        child: Row(children: chips)', canvas)

    def test_title_size_controls_are_directly_available_on_both_card_kinds(self):
        structured = self.read('lib/src/widgets/structured_hierarchy_view.dart')
        canvas = self.read('lib/src/widgets/canvas_workspace.dart')
        for source in (structured, canvas):
            self.assertIn("value: 'titleSmaller'", source)
            self.assertIn("value: 'titleLarger'", source)
            self.assertIn("Title smaller", source)
            self.assertIn("Title larger", source)
        self.assertIn('titleScale: (item.titleScale - 0.1)', structured)
        self.assertIn('.clamp(0.75, 2.0)', structured)
        self.assertIn('titleScale: (item.titleScale + 0.1)', structured)
        self.assertIn('fontSize: (18 * item.titleScale).clamp(10.0, 40.0).toDouble()', canvas)

    def test_hierarchy_data_and_layout_core_are_unchanged(self):
        expected = {
            'lib/src/widgets/hierarchy_layout.dart': 'df4d27494ed3c6f4d48dd9f793a00d92a7eb28ff3e1094f73ac9cbd59855f792',
            'lib/src/models/models.dart': '57da60fdb179c2716bd270b81e53d9463b38ac1edb55ace8ad323bc839bdb025',
        }
        for path, digest in expected.items():
            self.assertEqual(self.sha256(path), digest, path)

    def test_version_is_v752_or_later(self):
        self.assertRegex(self.read('pubspec.yaml'), r'version: 7\.(?:[6-9]|5\.[2-9])\.[0-9]+\+[0-9]+')


if __name__ == '__main__':
    unittest.main()
