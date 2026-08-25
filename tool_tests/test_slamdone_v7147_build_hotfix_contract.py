from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneV7147BuildHotfixContract(unittest.TestCase):
    def test_do_first_text_button_icon_uses_only_supported_named_parameters(self):
        source = (ROOT / 'lib/src/screens/do_first_screen.dart').read_text(encoding='utf-8')
        match = re.search(
            r"TextButton\.icon\(\s*tooltip:\s*'Do First filters',",
            source,
        )
        self.assertIsNone(
            match,
            "TextButton.icon has no tooltip named parameter; this stops Flutter web compilation.",
        )


if __name__ == '__main__':
    unittest.main()
