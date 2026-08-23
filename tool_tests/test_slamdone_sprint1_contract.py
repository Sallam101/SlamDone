from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SlamDoneSprint1ContractTest(unittest.TestCase):
    def read(self, relative):
        return (ROOT / relative).read_text(encoding='utf-8')

    def test_branding_and_pages_target_are_slamdone(self):
        pubspec = self.read('pubspec.yaml')
        app = self.read('lib/src/app.dart')
        home = self.read('lib/src/screens/home_shell.dart')
        workflow = self.read('.github/workflows/pages.yml')
        branding = self.read('tools/brand_web.py')
        self.assertIn('name: slamdone', pubspec)
        self.assertIn("title: 'SlamDone'", app)
        self.assertIn("Text('SlamDone'", home)
        self.assertIn('flutter create --platforms=web --project-name=slamdone .', workflow)
        self.assertIn('flutter build web --release --base-href /SlamDone/', workflow)
        self.assertIn("'name': 'SlamDone'", branding)

    def test_legacy_migration_and_database_identifiers_remain_compatible(self):
        migration = self.read('lib/src/migration/migration_models.dart')
        database = self.read('lib/src/database/local_database.dart')
        self.assertIn("'supeslam-autivra-migration'", migration)
        self.assertIn("databasePath = 'supeslam.db'", database)

    def test_child_task_delayed_archive_and_undo_exist(self):
        controller = self.read('lib/src/controllers/app_controller.dart')
        self.assertIn('Duration(seconds: 4)', controller)
        self.assertIn('item.type == WorkItemType.task', controller)
        self.assertIn('item.parentId != null', controller)
        self.assertIn('WorkStatus.archived', controller)
        self.assertIn('Future<void> undoAutoArchive', controller)
        self.assertIn('AutoArchiveNotice', controller)

    def test_big_picture_and_mind_map_share_archive_visibility_filter(self):
        models = self.read('lib/src/models/models.dart')
        big = self.read('lib/src/screens/big_picture_screen.dart')
        mind = self.read('lib/src/screens/mind_map_screen.dart')
        self.assertIn('enum WorkItemVisibilityFilter', models)
        self.assertIn('WorkItemVisibilityFilter.hideArchived', big)
        self.assertIn('WorkItemVisibilityFilter.hideArchived', mind)
        self.assertIn('matchesVisibilityFilter', big)
        self.assertIn('matchesVisibilityFilter', mind)

    def test_all_spatial_views_gate_wheel_zoom_and_support_middle_pan(self):
        canvas = self.read('lib/src/widgets/canvas_workspace.dart')
        structured = self.read('lib/src/widgets/structured_hierarchy_view.dart')
        northstar = self.read('lib/src/screens/northstar_screen.dart')
        for source in (canvas, structured, northstar):
            self.assertIn('PointerScrollEvent', source)
            self.assertIn('HardwareKeyboard.instance.isControlPressed', source)
            self.assertIn('kMiddleMouseButton', source)

    def test_archived_cards_offer_explicit_unarchive_action(self):
        controller = self.read('lib/src/controllers/app_controller.dart')
        canvas = self.read('lib/src/widgets/canvas_workspace.dart')
        structured = self.read('lib/src/widgets/structured_hierarchy_view.dart')
        self.assertIn('Future<void> unarchiveWorkItem', controller)
        self.assertIn("value: 'unarchive'", canvas)
        self.assertIn("value: 'unarchive'", structured)

    def test_free_canvas_cards_keep_rich_status_meta(self):
        canvas = self.read('lib/src/widgets/canvas_workspace.dart')
        self.assertIn('_buildBigPictureMeta', canvas)
        self.assertIn("'URGENT'", canvas)
        self.assertIn('item.energyLevel', canvas)
        self.assertIn('item.status.name', canvas)

    def test_timer_completed_child_uses_same_autoarchive_policy(self):
        controller = self.read('lib/src/controllers/app_controller.dart')
        self.assertIn('_refreshAfterTimerCompletion', controller)
        self.assertIn('timerEngine.state.workItemId', controller)
        self.assertIn('_scheduleAutoArchiveIfNeeded(before, itemById(before.id))', controller)

    def test_floating_timer_is_in_app_overlay(self):
        controller = self.read('lib/src/controllers/app_controller.dart')
        home = self.read('lib/src/screens/home_shell.dart')
        focus = self.read('lib/src/screens/focus_screen.dart')
        overlay = self.read('lib/src/widgets/floating_timer_overlay.dart')
        self.assertIn('bool floatingTimerVisible', controller)
        self.assertIn('showFloatingTimer', controller)
        self.assertIn('hideFloatingTimer', controller)
        self.assertIn('SlamDoneFloatingTimerOverlay', home)
        self.assertIn('Open floating timer', focus)
        self.assertIn('class SlamDoneFloatingTimerOverlay', overlay)


if __name__ == '__main__':
    unittest.main()
