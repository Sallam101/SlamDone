from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneV75ContractTest(unittest.TestCase):
    def read(self, rel):
        return (ROOT / rel).read_text(encoding='utf-8')

    def test_timer_is_clock_first_thin_pinnable_and_smoother_to_resize(self):
        timer = self.read('lib/src/widgets/floating_timer_overlay.dart')
        shell = self.read('lib/src/screens/home_shell.dart')
        self.assertIn('required this.pinned', timer)
        self.assertIn('required this.onPinnedChanged', timer)
        self.assertNotIn("'SlamDone Timer'", timer)
        self.assertIn("pinned ? 'Unpin timer' : 'Pin timer'", timer)
        self.assertIn('_TimerResizeAxis.horizontal', timer)
        self.assertIn('_TimerResizeAxis.vertical', timer)
        self.assertIn('_TimerResizeAxis.both', timer)
        self.assertIn('height: mini ? 28 : 32', timer)
        self.assertIn('BoxConstraints.tightFor(height: 30)', timer)
        self.assertIn('bool _floatingTimerPinned = true', shell)
        self.assertIn('ScrollUpdateNotification', shell)
        self.assertIn('minTimerWidth = desktop ? 156.0 : 148.0', shell)
        self.assertIn('minTimerHeight = desktop ? 150.0 : 144.0', shell)

    def test_web_brand_uses_approved_png_icon_and_in_app_wordmark_adapts(self):
        brand = self.read('lib/src/widgets/slamdone_brand.dart')
        shell = self.read('lib/src/screens/home_shell.dart')
        web = self.read('tools/brand_web.py')
        pubspec = self.read('pubspec.yaml')
        self.assertIn('this.backgroundColor', brand)
        self.assertIn('ThemeData.estimateBrightnessForColor', brand)
        self.assertIn('backgroundColor: appBarBackground', shell)
        self.assertIn("slamdone_app_icon.png", web)
        self.assertIn("favicon.png", web)
        self.assertIn("assets/branding/slamdone_app_icon.png", pubspec)
        self.assertTrue((ROOT / 'assets/branding/slamdone_app_icon.png').exists())

    def test_trend_hover_includes_weekday_date_and_value(self):
        overview = self.read('lib/src/screens/overview_screen.dart')
        self.assertIn('_trendHoverDate', overview)
        self.assertIn("DateFormat('EEE • MMM d, y')", overview)
        self.assertIn("${_trendHoverDate(widget.points[_hoverIndex!].day)} • $label", overview)

    def test_northstar_has_dedicated_move_grip_and_three_resize_zones(self):
        northstar = self.read('lib/src/screens/northstar_screen.dart')
        self.assertIn('_NorthStarResizeAxis.horizontal', northstar)
        self.assertIn('_NorthStarResizeAxis.vertical', northstar)
        self.assertIn('_NorthStarResizeAxis.both', northstar)
        self.assertIn("message: 'Drag to move note'", northstar)
        self.assertIn('width: widget.selected ? 16 : 12', northstar)
        self.assertIn('height: widget.selected ? 16 : 12', northstar)

    def test_version_is_v75(self):
        pubspec = self.read('pubspec.yaml')
        self.assertIn('version: 7.5.0+150', pubspec)


if __name__ == '__main__':
    unittest.main()
