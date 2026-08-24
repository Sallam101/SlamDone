from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneV713ContractTest(unittest.TestCase):
    def read(self, rel: str) -> str:
        return (ROOT / rel).read_text(encoding='utf-8')

    def test_release_version_is_7131_or_newer(self):
        pubspec = self.read('pubspec.yaml')
        match = re.search(r'(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$', pubspec)
        self.assertIsNotNone(match)
        version = tuple(int(value) for value in match.groups())
        self.assertGreaterEqual(version[:3], (7, 13, 1))

    def test_browser_only_rollback_is_upload_safe_even_if_stale_companion_files_remain(self):
        # GitHub's web "Upload files" flow cannot delete a directory that already
        # exists in the repository.  V7.13.1 therefore verifies runtime isolation,
        # not physical deletion of the old V7.12 source folder.
        bridge = self.read('tools/brand_web.py')
        shell = self.read('lib/src/screens/home_shell.dart')
        web_bridge = self.read('lib/src/services/desktop_timer_bridge_web.dart')

        self.assertIn('documentPictureInPicture.requestWindow', bridge)
        self.assertIn('soft_chime.wav', bridge)
        for forbidden in (
            '127.0.0.1:37110',
            'nativeBase',
            'loopbackFetch',
            'nativePost',
            'slamDoneDesktopTimerPrepare',
            '_desktopTimerPrepared',
        ):
            self.assertNotIn(forbidden, bridge + shell + web_bridge)

    def test_browser_timer_runtime_matches_pre_companion_architecture(self):
        shell = self.read('lib/src/screens/home_shell.dart')
        overlay = self.read('lib/src/widgets/floating_timer_overlay.dart')
        web_bridge = self.read('lib/src/services/desktop_timer_bridge_web.dart')
        self.assertIn('clamp(0, 7)', shell)
        self.assertIn('static const _timerColors = <Color>[', overlay)
        self.assertIn('min: .25', overlay)
        self.assertNotIn('_TimerThemeChoice', overlay)
        self.assertNotIn('void prepare()', web_bridge)

    def test_ci_does_not_require_physical_deletion_of_v712_companion_folder(self):
        workflow = self.read('.github/workflows/pages.yml')
        self.assertIn('rm -f test/widget_test.dart', workflow)
        # The browser-only app must build successfully whether an old V7.12
        # companion job/folder is still present in the repo or has been cleaned.
        self.assertNotIn('windows_timer_companion', self.read('tools/brand_web.py'))

    def test_one_time_cleanup_utility_removes_installed_background_companion(self):
        cleanup = self.read('Remove-Old-SlamDone-Timer-Companion.cmd')
        self.assertIn('taskkill /IM SlamDoneTimerCompanion.exe', cleanup)
        self.assertIn('reg delete "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run"', cleanup)
        self.assertIn('rmdir /S /Q "%LOCALAPPDATA%\\SlamDone\\TimerCompanion"', cleanup)


if __name__ == '__main__':
    unittest.main()
