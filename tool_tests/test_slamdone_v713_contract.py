from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneV713ContractTest(unittest.TestCase):
    def read(self, rel: str) -> str:
        return (ROOT / rel).read_text(encoding='utf-8')

    def test_release_version_is_7130(self):
        self.assertIn('version: 7.13.0+230', self.read('pubspec.yaml'))

    def test_native_windows_companion_is_not_part_of_runtime_or_deploy(self):
        workflow = self.read('.github/workflows/pages.yml')
        brand = self.read('tools/brand_web.py')
        combined = workflow + '\n' + brand
        for forbidden in ('windows_timer_companion', 'SlamDoneTimerCompanion', '127.0.0.1:37110', 'targetAddressSpace'):
            self.assertNotIn(forbidden, combined)

    def test_pages_workflow_is_browser_only_and_keeps_flutter_cleanup(self):
        workflow = self.read('.github/workflows/pages.yml')
        self.assertIn('rm -f test/widget_test.dart', workflow)
        for forbidden in ('windows-latest', 'dotnet publish', 'SlamDoneTimerCompanion.zip', 'slamdone-timer-companion', 'needs: companion'):
            self.assertNotIn(forbidden, workflow)
        workflows = list((ROOT / '.github' / 'workflows').glob('*.yml')) + list((ROOT / '.github' / 'workflows').glob('*.yaml'))
        self.assertEqual(1, len(workflows))

    def test_browser_timer_has_no_native_loopback_or_background_process_probe(self):
        source = self.read('tools/brand_web.py')
        for forbidden in ('127.0.0.1:37110', 'targetAddressSpace', 'nativeAvailable', 'nativeActive', 'probeNative', 'nativePost'):
            self.assertNotIn(forbidden, source)
        self.assertIn('documentPictureInPicture.requestWindow', source)
        self.assertIn('soft_chime.wav', source)
        self.assertNotIn('id="sd-close"', source)
        self.assertIn('title="Fade timer"', source)

    def test_browser_timer_restores_previous_eight_color_and_fade_behavior(self):
        source = self.read('tools/brand_web.py')
        self.assertIn("const colors = ['#78D12F', '#2457D6', '#00897B', '#7B1FA2', '#C62828', '#EF6C00', '#455A64', '#AD1457'];", source)
        self.assertIn('min="0.25"', source)
        self.assertIn('clamp(snapshot.opacity ?? 1, 0.25, 1)', source)

    def test_flutter_timer_restores_previous_color_and_fade_contract(self):
        overlay = self.read('lib/src/widgets/floating_timer_overlay.dart')
        home = self.read('lib/src/screens/home_shell.dart')
        self.assertIn('static const _timerColors = <Color>[', overlay)
        self.assertIn('widget.opacity.clamp(.25, 1)', overlay)
        self.assertIn('value.clamp(.25, 1)', home)
        self.assertIn('value.clamp(0, 7)', home)
        self.assertNotIn('_TimerThemeChoice', overlay)


if __name__ == '__main__':
    unittest.main()
