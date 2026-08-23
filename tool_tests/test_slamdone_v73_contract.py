from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneV73ContractTest(unittest.TestCase):
    def read(self, relative):
        return (ROOT / relative).read_text(encoding='utf-8')

    def test_brand_mark_and_slogan_are_visible(self):
        brand = self.read('lib/src/widgets/slamdone_brand.dart')
        home = self.read('lib/src/screens/home_shell.dart')
        web = self.read('tools/brand_web.py')
        self.assertIn('class SlamDoneBrand', brand)
        self.assertIn('STOP PLANNING. START FINISHING.', brand)
        self.assertIn('SlamDoneBrand(', home)
        self.assertIn('slamdone-mark.svg', web)

    def test_settings_hides_legacy_database_filename_from_product_copy(self):
        settings = self.read('lib/src/screens/settings_screen.dart')
        self.assertIn('SlamDone browser database', settings)
        self.assertNotIn("SelectableText('Database: ${controller.database.databasePath}')", settings)

    def test_big_picture_uses_independent_status_toggle_chips(self):
        big = self.read('lib/src/screens/big_picture_screen.dart')
        self.assertIn('Set<WorkStatus> _visibleStatuses', big)
        self.assertIn("label: const Text('Active')", big)
        self.assertIn("label: const Text('Completed')", big)
        self.assertIn("label: const Text('Archived')", big)
        self.assertIn('_toggleStatus', big)

    def test_journal_has_period_filters_and_view_modes(self):
        journal = self.read('lib/src/screens/journal_screen.dart')
        self.assertIn('enum JournalPeriodFilter', journal)
        self.assertIn('enum JournalViewMode', journal)
        for label in ('Week', 'Month', 'Year', 'All'):
            self.assertIn(f"Text('{label}')", journal)
        for mode in ('large', 'medium', 'small', 'list'):
            self.assertIn(f'JournalViewMode.{mode}', journal)

    def test_floating_timer_can_resize(self):
        home = self.read('lib/src/screens/home_shell.dart')
        overlay = self.read('lib/src/widgets/floating_timer_overlay.dart')
        self.assertIn('_floatingTimerSize', home)
        self.assertIn('onResizeDelta:', home)
        self.assertIn('required this.onResizeDelta', overlay)
        self.assertTrue("tooltip: 'Resize timer'" in overlay or "message: 'Resize timer'" in overlay)

    def test_spatial_views_show_middle_pan_navigation_contract(self):
        structured = self.read('lib/src/widgets/structured_hierarchy_view.dart')
        canvas = self.read('lib/src/widgets/canvas_workspace.dart')
        northstar = self.read('lib/src/screens/northstar_screen.dart')
        for source in (structured, canvas, northstar):
            self.assertIn('Middle drag', source)
            self.assertIn('SystemMouseCursors.move', source)
            self.assertIn('HardwareKeyboard.instance.isControlPressed', source)

    def test_mobile_has_explicit_hamburger_and_branded_drawer(self):
        home = self.read('lib/src/screens/home_shell.dart')
        self.assertIn("tooltip: 'Open SlamDone navigation'", home)
        self.assertIn('openDrawer()', home)
        self.assertIn('SlamDoneBrand(', home)


if __name__ == '__main__':
    unittest.main()
