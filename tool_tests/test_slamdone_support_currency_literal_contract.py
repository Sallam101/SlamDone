from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneSupportCurrencyLiteralContractTest(unittest.TestCase):
    def test_dollar_amounts_in_dart_support_copy_are_escaped(self):
        for rel in (
            'lib/src/screens/home_shell.dart',
            'lib/src/screens/settings_screen.dart',
        ):
            text = (ROOT / rel).read_text(encoding='utf-8')
            self.assertNotIn("$5", text.replace(r"\$5", ""), rel)
            self.assertIn(r"\$5", text, rel)


if __name__ == '__main__':
    unittest.main()
