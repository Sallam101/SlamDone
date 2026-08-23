import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


class SlamDoneV710ContractTest(unittest.TestCase):
    def test_overview_supports_week_month_quarter_year_periods(self):
        overview = read('lib/src/screens/overview_screen.dart')
        self.assertIn('enum _OverviewPeriod { week, month, quarter, year }', overview)
        for label in ['Week', 'Month', 'Quarter', 'Year']:
            self.assertIn("label: Text('%s')" % label, overview)
        self.assertIn('_sessionGoalForPeriod', overview)
        self.assertIn('_sessionMinutesForPeriod', overview)
        self.assertIn('_shiftAnchor', overview)
        self.assertIn('_previousAnchor', overview)

    def test_six_hierarchy_completion_metric_cards_are_clickable(self):
        overview = read('lib/src/screens/overview_screen.dart')
        for label in [
            'Goals completed', 'Milestones completed', 'Projects completed',
            'Subprojects completed', 'Modules completed', 'Tasks completed',
        ]:
            self.assertIn(label, overview)
        for kind in ['goal', 'milestone', 'project', 'subproject', 'module', 'task']:
            self.assertIn('WorkItemType.%s' % kind, overview)
        self.assertIn('_completedHierarchyItems', overview)
        self.assertIn('_showHierarchyDrillDown', overview)

    def test_hierarchy_trends_exist_for_all_six_levels_and_are_period_aware(self):
        overview = read('lib/src/screens/overview_screen.dart')
        self.assertIn('_HierarchyCompletionTrends', overview)
        self.assertIn('_HierarchyTrendCard', overview)
        self.assertIn('_buildHierarchyTrend', overview)
        self.assertIn('_trendBucketRange', overview)
        self.assertIn('_OverviewPeriod.quarter', overview)
        self.assertIn('_OverviewPeriod.year', overview)
        self.assertIn('onTap', overview)

    def test_dashboard_palettes_expand_to_twelve_colors(self):
        overview = read('lib/src/screens/overview_screen.dart')
        palette_blocks = re.findall(r'\[\s*((?:Color\(0x[0-9A-F]+\),?\s*){12})\]', overview)
        self.assertGreaterEqual(len(palette_blocks), 5)
        self.assertIn('Color(0xFF6750A4)', overview)
        self.assertIn('Color(0xFFE53935)', overview)

    def test_overview_excel_export_has_multiple_analytics_sheets(self):
        overview = read('lib/src/screens/overview_screen.dart')
        service = read('lib/src/services/overview_export_service.dart')
        self.assertIn('Export Overview', overview)
        self.assertIn('OverviewExportService.export', overview)
        for sheet in [
            'Summary', 'Period Comparison', 'Hierarchy Completed', 'Hierarchy Trend',
            'Daily Trend', 'Focus by Project',
        ]:
            self.assertIn(sheet, service)
        self.assertIn('FilePicker.saveFile', service)
        self.assertIn("allowedExtensions: const ['xlsx']", service)

    def test_release_version_is_7100(self):
        pubspec = read('pubspec.yaml')
        changelog = read('CHANGELOG.md')
        match = re.search(r'version:\s*(\d+)\.(\d+)\.(\d+)\+', pubspec)
        self.assertIsNotNone(match)
        self.assertGreaterEqual(tuple(map(int, match.groups())), (7, 10, 0))
        self.assertIn('7.10.0', changelog)


if __name__ == '__main__':
    unittest.main()
