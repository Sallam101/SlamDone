from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneV74ContractTest(unittest.TestCase):
    def read(self, rel):
        return (ROOT / rel).read_text(encoding='utf-8')

    def test_reference_brand_identity_is_used(self):
        brand = self.read('lib/src/widgets/slamdone_brand.dart')
        web = self.read('tools/brand_web.py')
        self.assertIn('STOP PLANNING. START FINISHING.', brand)
        self.assertIn('0xFF78D12F', brand)
        self.assertIn('SlamDoneMark', brand)
        self.assertIn('STOP PLANNING.', web)
        self.assertIn('START FINISHING.', web)
        self.assertIn('#78D12F', web)
        self.assertNotIn('Plan • Focus • Finish', brand)

    def test_timer_has_true_mini_and_large_resize_range(self):
        shell = self.read('lib/src/screens/home_shell.dart')
        timer = self.read('lib/src/widgets/floating_timer_overlay.dart')
        self.assertIn('minTimerWidth', shell)
        self.assertIn('minTimerHeight', shell)
        self.assertIn('760.0', shell)
        self.assertIn('840.0', shell)
        self.assertIn('_TimerDensity.mini', timer)
        self.assertIn('resizeDownRight', timer)
        self.assertIn('Resize timer', timer)
        self.assertIn('_buildIconControls', timer)

    def test_overview_has_clickable_drilldowns_trends_and_project_focus(self):
        overview = self.read('lib/src/screens/overview_screen.dart')
        self.assertIn('_showMetricDrillDown', overview)
        self.assertIn('_DailyTrendChart', overview)
        self.assertIn('_ProjectFocusBreakdown', overview)
        self.assertIn('workItemId', overview)
        self.assertIn('Current vs previous', overview)

    def test_gtd_archive_cards_can_be_restored_without_dragging(self):
        gtd = self.read('lib/src/screens/gtd_para_screen.dart')
        self.assertIn('Unarchive', gtd)
        self.assertIn('unarchiveWorkItem', gtd)
        self.assertIn('Restore to active', gtd)

    def test_tables_support_excel_import_row_resize_and_cell_formatting(self):
        tables = self.read('lib/src/screens/study_tables_screen.dart')
        pubspec = self.read('pubspec.yaml')
        self.assertIn("package:excel_community/excel_community.dart", tables)
        self.assertIn("allowedExtensions: const ['csv', 'tsv', 'xlsx']", tables)
        self.assertIn('Import Excel', tables)
        self.assertIn('rowHeights', tables)
        self.assertIn('resizeRow', tables)
        self.assertIn('cellFormats', tables)
        self.assertIn('Bold', tables)
        self.assertIn('Cell color', tables)
        self.assertIn('Text color', tables)
        self.assertIn('excel_community: ^2.2.1', pubspec)
        self.assertNotRegex(pubspec, r'\n\s*excel:\s*\^')

    def test_version_is_at_least_v74(self):
        pubspec = self.read('pubspec.yaml')
        match = re.search(r'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)', pubspec)
        self.assertIsNotNone(match)
        major, minor = int(match.group(1)), int(match.group(2))
        self.assertGreaterEqual((major, minor), (7, 4))


if __name__ == '__main__':
    unittest.main()
