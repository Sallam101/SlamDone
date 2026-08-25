from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneV7147ResponsivePatchContractTest(unittest.TestCase):
    def read(self, rel: str) -> str:
        return (ROOT / rel).read_text(encoding='utf-8')

    def test_tasks_filters_wrap_and_are_visible_by_default_with_collapse_toggle(self):
        src = self.read('lib/src/screens/tasks_screen.dart')
        self.assertIn('bool _filtersVisible = true;', src)
        start = src.index('Widget _filterStrip(')
        end = src.index('Widget _smartChip(', start)
        strip = src[start:end]
        self.assertIn('Wrap(', strip)
        self.assertNotIn('SingleChildScrollView(', strip)
        self.assertIn("'Hide filters'", src)
        self.assertIn("'Show filters'", src)

    def test_do_first_filters_start_collapsed_and_include_category_energy_recurrence(self):
        src = self.read('lib/src/screens/do_first_screen.dart')
        self.assertIn('bool _filtersVisible = false;', src)
        self.assertIn("String _category = 'all';", src)
        self.assertIn("String _energy = 'all';", src)
        self.assertIn("String _recurrence = 'all';", src)
        self.assertIn("'Uncategorized only'", src)
        self.assertIn("'High energy'", src)
        self.assertIn("'Recurring only'", src)
        self.assertIn('_matchesCategory(item)', src)
        self.assertIn('_matchesEnergy(item)', src)
        self.assertIn('_matchesRecurrence(item)', src)

    def test_do_first_default_priority_buckets_match_requested_order(self):
        src = self.read('lib/src/screens/do_first_screen.dart')
        method_start = src.index('int _priorityBucket(')
        method_end = src.index('bool _matchesStatus(', method_start)
        method = src[method_start:method_end]
        requested_order = [
            'if (overdue && urgent) return 0;',
            'if (overdue) return 1;',
            'if (due && urgent) return 2;',
            'if (due) return 3;',
        ]
        positions = [method.index(token) for token in requested_order]
        self.assertEqual(positions, sorted(positions))

    def test_default_appearance_is_light_green_and_top_bar_is_configurable(self):
        controller = self.read('lib/src/controllers/app_controller.dart')
        settings = self.read('lib/src/screens/settings_screen.dart')
        home = self.read('lib/src/screens/home_shell.dart')
        self.assertIn('ThemeMode themeMode = ThemeMode.light;', controller)
        self.assertIn('int topBarColorValue = 0;', controller)
        self.assertIn("database.getSetting('top_bar_color')", controller)
        self.assertIn('Future<void> setTopBarColor(int value)', controller)
        self.assertIn("'Top bar'", settings)
        self.assertIn('controller.topBarColorValue', settings)
        self.assertIn('controller.setTopBarColor', settings)
        self.assertIn('controller.topBarColorValue == 0', home)
        self.assertTrue((ROOT / 'lib/src/services/top_bar_theme_bridge.dart').exists())
        self.assertTrue((ROOT / 'lib/src/services/top_bar_theme_bridge_stub.dart').exists())
        self.assertTrue((ROOT / 'lib/src/services/top_bar_theme_bridge_web.dart').exists())

    def test_floating_timer_can_shrink_and_task_title_is_inside_dial(self):
        home = self.read('lib/src/screens/home_shell.dart')
        overlay = self.read('lib/src/widgets/floating_timer_overlay.dart')
        self.assertRegex(home, r'final minTimerWidth = desktop \? 12[0-9]\.0 : 11[0-9]\.0;')
        self.assertRegex(home, r'final minTimerHeight = desktop \? 12[0-9]\.0 : 12[0-9]\.0;')
        self.assertIn('title: title,', overlay)
        clock_start = overlay.index('Widget _buildClockFirstBody(')
        clock_end = overlay.index('Widget _buildIconControls(', clock_start)
        clock = overlay[clock_start:clock_end]
        self.assertIn('required String title,', clock)
        self.assertIn('title,', clock)
        self.assertIn('maxLines: 1', clock)
        self.assertIn('available.clamp(50.0, dialMax)', clock)
        self.assertIn('if (dialSize >= 50)', clock)

    def test_table_mutations_are_serialized_and_grid_shape_is_repaired_before_build(self):
        src = self.read('lib/src/screens/study_tables_screen.dart')
        self.assertIn('bool _gridMutationInFlight = false;', src)
        self.assertIn('Future<void> _mutateGrid(', src)
        self.assertIn('_normalizeGridShape();', src[src.index('Future<void> _mutateGrid('):])
        self.assertIn('onPressed: _gridMutationInFlight', src)
        canvas_start = src.index('Widget _buildTableCanvas(')
        canvas_end = src.index('Widget _buildHeaderRow(', canvas_start)
        canvas = src[canvas_start:canvas_end]
        self.assertIn('final safeWidth =', canvas)
        self.assertIn('ConstrainedBox(', canvas)
        self.assertIn('_buildSpreadsheetGrid(controller)', canvas)

    def test_release_version_is_7147(self):
        self.assertRegex(self.read('pubspec.yaml'), r'version: 7\.14\.(?:7\+247|8\+248)')


if __name__ == '__main__':
    unittest.main()
