from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneSupportCompileSafeContractTest(unittest.TestCase):
    def read(self, rel: str) -> str:
        return (ROOT / rel).read_text(encoding='utf-8')

    def test_support_uses_existing_js_interop_pattern_without_new_flutter_plugin(self):
        pubspec = self.read('pubspec.yaml')
        bridge = self.read('lib/src/services/support_links.dart')
        web = self.read('lib/src/services/support_links_web.dart')
        stub = self.read('lib/src/services/support_links_stub.dart')
        brand = self.read('tools/brand_web.py')

        self.assertNotIn('url_launcher:', pubspec)
        self.assertIn("if (dart.library.js_interop) 'support_links_web.dart'", bridge)
        self.assertIn("@JS('slamDoneOpenPatreonSupport')", web)
        self.assertIn('JSBoolean', web)
        self.assertIn('class SupportLinks', stub)
        self.assertIn('slamDoneOpenPatreonSupport', brand)
        self.assertIn('buy-sallam-167511433', brand)

    def test_active_github_workflow_is_browser_only_v713(self):
        workflow = self.read('.github/workflows/pages.yml')
        self.assertIn('name: Build and deploy SlamDone PWA', workflow)
        self.assertIn('flutter build web', workflow)
        self.assertNotIn('windows-latest', workflow)
        self.assertNotIn('SlamDoneTimerCompanion.zip', workflow)
        self.assertNotIn('build/web/downloads', workflow)


if __name__ == '__main__':
    unittest.main()
