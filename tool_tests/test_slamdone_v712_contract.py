from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneV712ContractTest(unittest.TestCase):
    def read(self, rel: str) -> str:
        return (ROOT / rel).read_text(encoding='utf-8')

    def test_release_version_is_7120(self):
        self.assertIn('version: 7.12.0+220', self.read('pubspec.yaml'))

    def test_flutter_timer_has_named_background_themes_including_light_choices(self):
        source = self.read('lib/src/widgets/floating_timer_overlay.dart')
        for marker in (
            '_TimerThemeChoice',
            'background',
            'foreground',
            "'White'",
            "'Soft gray'",
            "'Cream'",
            "'Mint'",
            "'Ice blue'",
            "'Lavender'",
            "'Blush'",
            "'Pale yellow'",
        ):
            self.assertIn(marker, source)
        self.assertNotIn('static const _timerColors = <Color>[', source)

    def test_home_shell_accepts_sixteen_timer_themes(self):
        source = self.read('lib/src/screens/home_shell.dart')
        self.assertIn('clamp(0, 15)', source)

    def test_native_companion_is_borderless_topmost_and_uses_real_window_opacity(self):
        project = self.read('windows_timer_companion/SlamDoneTimerCompanion/SlamDoneTimerCompanion.csproj')
        form = self.read('windows_timer_companion/SlamDoneTimerCompanion/TimerForm.cs')
        self.assertIn('<UseWindowsForms>true</UseWindowsForms>', project)
        self.assertIn('<RuntimeIdentifier>win-x64</RuntimeIdentifier>', project)
        self.assertIn('FormBorderStyle.None', form)
        self.assertIn('TopMost = true', form)
        self.assertIn('Opacity =', form)
        self.assertIn('TrackBar', form)
        self.assertIn('Transparency', form)
        self.assertIn('Timer themes', form)
        self.assertIn('Resize timer', form)

    def test_companion_loopback_bridge_is_restricted_and_timer_only(self):
        server = self.read('windows_timer_companion/SlamDoneTimerCompanion/LocalBridgeServer.cs')
        for marker in (
            '127.0.0.1:37110',
            '/health',
            '/state',
            '/hide',
            '/chime',
            '/actions',
            'https://sallam101.github.io',
            'Access-Control-Allow-Origin',
        ):
            self.assertIn(marker, server)
        self.assertNotIn('firestore', server.lower())
        self.assertNotIn('planner', server.lower())

    def test_native_companion_has_sixteen_matching_themes_and_embedded_chime(self):
        themes = self.read('windows_timer_companion/SlamDoneTimerCompanion/TimerTheme.cs')
        project = self.read('windows_timer_companion/SlamDoneTimerCompanion/SlamDoneTimerCompanion.csproj')
        for name in ('White', 'Soft gray', 'Cream', 'Mint', 'Ice blue', 'Lavender', 'Blush', 'Pale yellow'):
            self.assertIn(name, themes)
        self.assertIn('soft_chime.wav', project)
        self.assertIn('EmbeddedResource', project)

    def test_browser_bridge_prefers_native_loopback_but_keeps_immediate_pip_fallback(self):
        source = self.read('tools/brand_web.py')
        for marker in (
            '127.0.0.1:37110',
            'targetAddressSpace',
            'loopback',
            '/health',
            '/state',
            '/actions',
            '/hide',
            '/chime',
            'nativeAvailable',
            'nativeActive',
            'documentPictureInPicture.requestWindow',
        ):
            self.assertIn(marker, source)
        # Browser PiP owns its own X; fallback must not duplicate that close control.
        self.assertNotIn('id="sd-close"', source)

    def test_companion_install_is_per_user_and_workflow_builds_it_without_second_workflow(self):
        install = self.read('windows_timer_companion/Install-SlamDoneTimer.cmd')
        workflow = self.read('.github/workflows/pages.yml')
        self.assertIn('%LOCALAPPDATA%', install)
        self.assertIn('HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run', install)
        self.assertIn('windows-latest', workflow)
        self.assertIn('dotnet publish', workflow)
        self.assertIn('SlamDoneTimerCompanion.zip', workflow)
        self.assertIn('build/web/downloads', workflow)
        workflows = list((ROOT / '.github' / 'workflows').glob('*.yml')) + list((ROOT / '.github' / 'workflows').glob('*.yaml'))
        self.assertEqual(1, len(workflows))


if __name__ == '__main__':
    unittest.main()
