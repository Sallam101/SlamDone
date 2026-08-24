from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneV713ContractTest(unittest.TestCase):
    def test_release_version_is_713(self):
        self.assertIn('version: 7.13.0+230', (ROOT / 'pubspec.yaml').read_text())

    def test_native_windows_companion_is_removed(self):
        self.assertFalse((ROOT / 'windows_timer_companion').exists())
        workflow = (ROOT / '.github/workflows/pages.yml').read_text()
        for forbidden in ('windows-latest', 'setup-dotnet', 'dotnet publish', 'SlamDoneTimerCompanion.zip', 'slamdone-timer-companion'):
            self.assertNotIn(forbidden, workflow)
        self.assertIn('rm -f test/widget_test.dart', workflow)

    def test_desktop_pin_is_back_to_browser_picture_in_picture_only(self):
        bridge = (ROOT / 'tools/brand_web.py').read_text()
        self.assertIn('documentPictureInPicture.requestWindow', bridge)
        self.assertIn('soft_chime.wav', bridge)
        for forbidden in ('127.0.0.1:37110', 'nativeBase', 'loopbackFetch', 'nativePost', 'slamDoneDesktopTimerPrepare'):
            self.assertNotIn(forbidden, bridge)

    def test_timer_runtime_matches_pre_companion_browser_architecture(self):
        shell = (ROOT / 'lib/src/screens/home_shell.dart').read_text()
        overlay = (ROOT / 'lib/src/widgets/floating_timer_overlay.dart').read_text()
        web_bridge = (ROOT / 'lib/src/services/desktop_timer_bridge_web.dart').read_text()
        self.assertNotIn('_desktopTimerPrepared', shell)
        self.assertIn('clamp(0, 7)', shell)
        self.assertIn('static const _timerColors = <Color>[', overlay)
        self.assertIn('min: .25', overlay)
        self.assertNotIn('_TimerThemeChoice', overlay)
        self.assertNotIn('void prepare()', web_bridge)


if __name__ == '__main__':
    unittest.main()
