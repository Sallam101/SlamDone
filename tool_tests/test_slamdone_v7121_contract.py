from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skip('V7.12.1 native companion intentionally retired in V7.13 browser-only rollback')
class SlamDoneV7121ContractTest(unittest.TestCase):
    def read(self, rel: str) -> str:
        return (ROOT / rel).read_text(encoding='utf-8')

    def test_release_version_is_7121(self):
        self.assertIn('version: 7.12.1+221', self.read('pubspec.yaml'))

    def test_bridge_exposes_native_status_and_companion_download(self):
        web = self.read('lib/src/services/desktop_timer_bridge_web.dart')
        stub = self.read('lib/src/services/desktop_timer_bridge_stub.dart')
        brand = self.read('tools/brand_web.py')
        for marker in ('nativeAvailable', 'usingNative', 'downloadCompanion', 'openBrowserFallback'):
            self.assertIn(marker, web)
            self.assertIn(marker, stub)
        for marker in (
            'slamDoneDesktopTimerNativeAvailable',
            'slamDoneDesktopTimerUsingNative',
            'slamDoneDesktopTimerDownloadCompanion',
            'slamDoneDesktopTimerOpenBrowserFallback',
            'downloads/SlamDoneTimerCompanion.zip',
        ):
            self.assertIn(marker, brand)

    def test_pin_does_not_silently_fallback_when_native_missing(self):
        source = self.read('lib/src/screens/home_shell.dart')
        for marker in (
            'True transparent timer companion',
            'Download companion',
            'Use browser fallback',
            'nativeAvailable',
            'downloadCompanion',
            'openBrowserFallback',
        ):
            self.assertIn(marker, source)

    def test_browser_fallback_no_longer_pretends_to_offer_transparency(self):
        brand = self.read('tools/brand_web.py')
        self.assertNotIn('id="sd-opacity"', brand)
        self.assertNotIn('id="sd-opacity-range"', brand)
        self.assertNotIn('Fade browser fallback', brand)
        self.assertIn('Browser fallback', brand)

    def test_sixteen_timer_themes_remain_in_browser_and_native_companion(self):
        brand = self.read('tools/brand_web.py')
        themes = self.read('windows_timer_companion/SlamDoneTimerCompanion/TimerTheme.cs')
        for name in ('White', 'Soft gray', 'Cream', 'Mint', 'Ice blue', 'Lavender', 'Blush', 'Pale yellow'):
            self.assertIn(name, brand)
            self.assertIn(name, themes)

    def test_workflow_still_builds_native_companion_and_pages_download(self):
        workflow = self.read('.github/workflows/pages.yml')
        for marker in ('windows-latest', 'SlamDoneTimerCompanion.zip', 'build/web/downloads', 'rm -f test/widget_test.dart'):
            self.assertIn(marker, workflow)


if __name__ == '__main__':
    unittest.main()
