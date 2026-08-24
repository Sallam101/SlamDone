from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneBaseHrefHotfixContractTest(unittest.TestCase):
    def test_web_index_keeps_flutter_base_href_placeholder_for_github_pages_build(self):
        web = (ROOT / 'web' / 'index.html').read_text(encoding='utf-8')
        self.assertEqual(web.count('<base href="$FLUTTER_BASE_HREF">'), 1)
        self.assertIn('flutter_bootstrap.js', web)


if __name__ == '__main__':
    unittest.main()
