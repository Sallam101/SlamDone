from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneSupportContractTest(unittest.TestCase):
    def test_optional_patreon_support_is_link_only_and_visible_in_settings_and_drawer(self):
        pubspec = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
        settings = (ROOT / 'lib/src/screens/settings_screen.dart').read_text(encoding='utf-8')
        home = (ROOT / 'lib/src/screens/home_shell.dart').read_text(encoding='utf-8')
        bridge = (ROOT / 'lib/src/services/support_links.dart').read_text(encoding='utf-8')
        support_web = (ROOT / 'lib/src/services/support_links_web.dart').read_text(encoding='utf-8')
        brand = (ROOT / 'tools/brand_web.py').read_text(encoding='utf-8')

        self.assertNotIn('url_launcher:', pubspec)
        self.assertIn("if (dart.library.js_interop) 'support_links_web.dart'", bridge)
        self.assertIn("@JS('slamDoneOpenPatreonSupport')", support_web)
        self.assertIn('https://www.patreon.com/Sallam101/posts/buy-sallam-167511433?utm_medium=clipboard_copy&utm_source=copyLink&utm_campaign=postshare_creator&utm_content=join_link', brand)
        self.assertIn("window.open(patreonUrl, '_blank', 'noopener,noreferrer')", brand)
        self.assertIn('Support SlamDone', settings)
        self.assertIn('SlamDone got you productive?', settings)
        self.assertIn('Buy me a coffee', settings)
        self.assertIn('one-time $5', settings)
        self.assertIn('Completely optional', settings)
        self.assertIn('Support SlamDone', home)
        self.assertIn('One-time $5 thank-you', home)
        self.assertIn('SupportLinks.openPatreon', home)
        self.assertNotIn('patreon.com/api', brand.lower())


if __name__ == '__main__':
    unittest.main()
