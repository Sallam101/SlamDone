from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneV7148AnalyticsContract(unittest.TestCase):
    def read(self, rel):
        return (ROOT / rel).read_text(encoding='utf-8')

    def test_pubspec_adds_flutterfire_analytics(self):
        pubspec = self.read('pubspec.yaml')
        self.assertRegex(pubspec, r'(?m)^\s*firebase_analytics:\s*\^12\.5\.0\s*$')

    def test_analytics_service_is_privacy_safe_and_toggleable(self):
        service = self.read('lib/src/services/app_analytics.dart')
        self.assertIn("package:firebase_analytics/firebase_analytics.dart", service)
        self.assertIn('setAnalyticsCollectionEnabled', service)
        for event in (
            'section_opened',
            'work_item_created',
            'work_item_completed',
            'habit_checkin',
            'focus_started',
            'focus_completed',
            'cloud_sync_enabled',
        ):
            self.assertIn(event, service)
        # Event parameters must remain aggregate/generic; never accept planner text.
        for forbidden in ('task_title', 'journal_text', 'northstar_text', 'habit_name', 'email_address'):
            self.assertNotIn(forbidden, service)

    def test_controller_tracks_generic_product_events_and_local_privacy_setting(self):
        controller = self.read('lib/src/controllers/app_controller.dart')
        sync = self.read('lib/src/services/sync_service.dart')
        self.assertIn("import '../services/app_analytics.dart';", controller)
        self.assertIn('bool analyticsEnabled = true;', controller)
        self.assertIn("database.getSetting('analytics_enabled')", controller)
        self.assertIn('Future<void> setAnalyticsEnabled(bool enabled)', controller)
        self.assertIn('analytics.logSectionOpened(section.name)', controller)
        self.assertIn('analytics.logWorkItemCreated(item.type.name)', controller)
        self.assertIn('analytics.logWorkItemCompleted(item.type.name)', controller)
        self.assertIn('analytics.logHabitCheckIn(habit.kind.name)', controller)
        self.assertIn("'analytics_enabled'", sync)

    def test_timer_instrumentation_counts_starts_and_completed_sessions_without_titles(self):
        engine = self.read('lib/src/services/timer_engine.dart')
        controller = self.read('lib/src/controllers/app_controller.dart')
        self.assertIn('onTimerStarted', engine)
        self.assertIn('onSessionRecorded', engine)
        self.assertIn('onTimerStarted?.call(mode);', engine)
        self.assertIn('onSessionRecorded?.call(session);', engine)
        self.assertIn('analytics.logFocusStarted(mode.name)', controller)
        self.assertIn('analytics.logFocusCompleted(session.mode.name)', controller)

    def test_settings_exposes_clear_anonymous_analytics_opt_out(self):
        settings = self.read('lib/src/screens/settings_screen.dart')
        self.assertIn('Anonymous usage analytics', settings)
        self.assertIn('Never sends task names, journal text, NorthStar content, habit names, or table contents.', settings)
        self.assertIn('controller.setAnalyticsEnabled', settings)

    def test_workflow_still_injects_measurement_id(self):
        workflow = self.read('.github/workflows/pages.yml')
        self.assertIn('--dart-define=FIREBASE_MEASUREMENT_ID=${{ vars.FIREBASE_MEASUREMENT_ID }}', workflow)


if __name__ == '__main__':
    unittest.main()
