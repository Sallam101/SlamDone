from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneV711ContractTest(unittest.TestCase):
    def read(self, rel: str) -> str:
        return (ROOT / rel).read_text(encoding='utf-8')

    def test_release_version_is_711_or_newer(self):
        pubspec = self.read('pubspec.yaml')
        self.assertRegex(pubspec, r'(?m)^version:\s*7\.(?:1[1-9]|[2-9]\d)\.\d+\+\d+\s*$')

    def test_brand_web_injects_document_pip_bridge_and_real_chime(self):
        source = self.read('tools/brand_web.py')
        for marker in (
            'slamdone-desktop-timer-bridge',
            'documentPictureInPicture',
            'slamDoneDesktopTimer',
            'soft_chime.wav',
            'lastChimeToken',
            'requestWindow',
            'deadline',
        ):
            self.assertIn(marker, source)
        self.assertIn('opacity', source)
        self.assertRegex(source, r'0\.(?:20|25)|\.(?:20|25)')

    def test_conditional_desktop_timer_bridge_is_web_only(self):
        common = self.read('lib/src/services/desktop_timer_bridge.dart')
        stub = self.read('lib/src/services/desktop_timer_bridge_stub.dart')
        web = self.read('lib/src/services/desktop_timer_bridge_web.dart')
        self.assertIn("if (dart.library.js_interop)", common)
        self.assertNotIn('dart:js_interop', common)
        self.assertNotIn('dart:js_interop', stub)
        self.assertIn("import 'dart:js_interop';", web)
        self.assertIn('slamDoneDesktopTimer', web)
        self.assertIn('slamDoneTimerPipAction', web)
        self.assertIn('slamDoneTimerPipClosed', web)
        self.assertIn('Future<bool> open', web)

    def test_timer_engine_uses_token_deduped_asset_chime_and_deadline_reconcile(self):
        engine = self.read('lib/src/services/timer_engine.dart')
        common = self.read('lib/src/services/timer_completion_chime.dart')
        web = self.read('lib/src/services/timer_completion_chime_web.dart')
        self.assertNotIn('SystemSoundType.alert', engine)
        self.assertNotIn("package:flutter/services.dart", engine)
        self.assertIn('playTimerCompletionChime', engine)
        self.assertIn('completedState.completionToken', engine)
        self.assertIn('primeTimerCompletionChime', engine)
        self.assertIn('Future<void> reconcileNow()', engine)
        self.assertIn("if (dart.library.js_interop)", common)
        self.assertIn('slamDoneDesktopTimerPlayChime', web)
        self.assertIn('slamDoneDesktopTimerPrimeChime', web)

    def test_home_shell_routes_desktop_pin_to_pip_and_keeps_fallback(self):
        source = self.read('lib/src/screens/home_shell.dart')
        for marker in (
            'DesktopTimerBridge',
            '_desktopTimerOpen',
            '_floatingTimerOpacity',
            '_floatingTimerColorIndex',
            '_pushDesktopTimerSnapshot',
            '_handleDesktopTimerAction',
            "case 'deadline':",
            'reconcileNow()',
            'bridge.supported',
            'bridge.open(',
        ):
            self.assertIn(marker, source)
        # The old in-app pinned state remains as fallback rather than being deleted.
        self.assertIn('_floatingTimerPinned', source)
        self.assertIn('SlamDoneFloatingTimerOverlay', source)

    def test_floating_timer_opacity_is_optional_and_does_not_resize_layout(self):
        source = self.read('lib/src/widgets/floating_timer_overlay.dart')
        for marker in (
            'final double opacity;',
            'onOpacityChanged',
            '_showOpacity',
            'Icons.opacity',
            'Slider(',
            'max: 1',
            'AnimatedOpacity',
        ):
            self.assertIn(marker, source)
        self.assertRegex(source, r'min:\s*\.(?:20|25)')
        self.assertIn('onColorChanged', source)
        self.assertIn('colorIndex', source)

    def test_pip_actions_use_existing_timer_engine_instead_of_second_engine(self):
        source = self.read('lib/src/screens/home_shell.dart')
        self.assertIn("case 'toggle':", source)
        self.assertIn('controller.timerEngine.pause()', source)
        self.assertIn('controller.timerEngine.resume()', source)
        self.assertIn('controller.timerEngine.reset()', source)
        self.assertIn('controller.timerEngine.stop(saveSession: true)', source)
        self.assertIn('TimerMode.stopwatch', source)
        self.assertNotIn('TimerEngine(', source)


if __name__ == '__main__':
    unittest.main()
