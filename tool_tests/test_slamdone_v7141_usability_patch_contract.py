from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneV7141UsabilityPatchContractTest(unittest.TestCase):
    def read(self, rel: str) -> str:
        return (ROOT / rel).read_text(encoding='utf-8')

    def test_year_weeks_auto_scrolls_current_year_to_current_week_row(self):
        calendar = self.read('lib/src/screens/calendar_screen.dart')
        self.assertIn('final ScrollController _scrollController = ScrollController();', calendar)
        self.assertIn('void _scheduleCurrentWeekScroll(', calendar)
        self.assertIn('final currentWeekIndex = isoWeekNumber(now) - 1;', calendar)
        self.assertIn('final currentWeekRow = currentWeekIndex ~/ crossAxisCount;', calendar)
        self.assertIn('controller: _scrollController,', calendar)
        self.assertIn('_scheduleCurrentWeekScroll(', calendar)

    def test_habit_horizontal_scrollbar_is_under_day_header_and_today_is_auto_positioned(self):
        habits = self.read('lib/src/screens/habits_screen.dart')
        self.assertIn('static const double _dayLabelHeight = 60.0;', habits)
        self.assertIn('static const double _dayHeaderHeight = _dayLabelHeight + 16.0;', habits)
        self.assertRegex(
            habits,
            r'scrollbarOrientation:\s*ScrollbarOrientation\.top,',
        )
        self.assertIn('ScrollbarTheme.of(context).copyWith(', habits)
        self.assertIn('crossAxisMargin: _dayLabelHeight,', habits)
        self.assertNotRegex(
            habits,
            r'Scrollbar\(\s*controller: _horizontal,[\s\S]{0,240}?crossAxisMargin:',
        )
        self.assertIn('void _queueScrollToToday()', habits)
        self.assertIn('final viewport = _horizontal.position.viewportDimension;', habits)
        self.assertIn('final todayCenter = (now.day - .5) * 58.0;', habits)
        self.assertIn('_queueScrollToToday();', habits)

    def test_focus_undo_snackbars_have_a_hard_five_second_lifetime(self):
        focus = self.read('lib/src/screens/focus_screen.dart')
        self.assertIn('const _focusUndoLifetime = Duration(seconds: 5);', focus)
        self.assertNotIn('Duration(minutes: 5)', focus)
        self.assertIn('void _showFocusUndoSnackBar(', focus)
        self.assertIn('duration: _focusUndoLifetime,', focus)
        self.assertIn('Timer(_focusUndoLifetime, snackController.close);', focus)
        self.assertGreaterEqual(focus.count('_showFocusUndoSnackBar('), 3)

    def test_floating_timer_keeps_existing_colors_and_adds_light_background_themes(self):
        overlay = self.read('lib/src/widgets/floating_timer_overlay.dart')
        shell = self.read('lib/src/screens/home_shell.dart')
        web = self.read('web/index.html')
        brand_web = self.read('tools/brand_web.py')
        self.assertIn('static const _timerBackgrounds = <Color?>[', overlay)
        for label in ('White', 'Soft gray', 'Cream', 'Mint', 'Ice blue', 'Lavender', 'Blush', 'Pale yellow'):
            self.assertIn(f"'{label}'", overlay)
        self.assertIn('_timerBackgrounds[safeColorIndex]', overlay)
        self.assertIn('background.computeLuminance()', overlay)
        self.assertEqual(shell.count('clamp(0, 15)'), 2)
        self.assertIn("name: 'White'", web)
        self.assertIn("name: 'Pale yellow'", web)
        self.assertIn("root.style.setProperty('--timer-bg'", web)
        self.assertIn("root.style.setProperty('--timer-fg'", web)
        self.assertIn('themes.forEach((theme, index) => {', web)
        self.assertIn("name: 'White'", brand_web)
        self.assertIn("name: 'Pale yellow'", brand_web)
        self.assertIn("root.style.setProperty('--timer-bg'", brand_web)
        self.assertIn('themes.forEach((theme, index) => {', brand_web)

    def test_web_index_keeps_flutter_base_href_placeholder_for_github_pages_build(self):
        web = self.read('web/index.html')
        self.assertIn('<base href="$FLUTTER_BASE_HREF">', web)

    def test_release_version_is_7142(self):
        pubspec = self.read('pubspec.yaml')
        self.assertRegex(pubspec, r'(?m)^version:\s*7\.14\.(?:2\+242|3\+243|4\+244|5\+245)\s*$')


if __name__ == '__main__':
    unittest.main()
