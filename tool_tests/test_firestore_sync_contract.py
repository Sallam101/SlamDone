import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class FirestoreSyncContractTest(unittest.TestCase):
    def test_sync_service_uses_uid_namespaced_collections(self):
        text = (ROOT / 'lib/src/services/sync_service.dart').read_text(encoding='utf-8')
        self.assertIn("collection('users').doc(user.uid)", text)
        self.assertIn('collection(entityType)', text)
        self.assertIn("collection('settings')", text)
        self.assertIn("collection('meta').doc('timer_state')", text)
        self.assertNotIn('Supabase.instance', text)

    def test_all_required_cloud_tables_are_declared(self):
        text = (ROOT / 'lib/src/services/sync_service.dart').read_text(encoding='utf-8')
        for table in (
            'work_items', 'canvas_layouts', 'journal_entries', 'journal_versions',
            'time_sessions', 'habits', 'habit_entries', 'northstar_notes',
            'reward_ranks', 'study_tables'
        ):
            self.assertIn(f"'{table}'", text)

    def test_journal_versions_join_sync_queue(self):
        text = (ROOT / 'lib/src/database/local_database.dart').read_text(encoding='utf-8')
        self.assertIn("enqueueEntity('journal_versions', version.id)", text)
        self.assertIn("if (entityType == 'journal_versions')", text)

    def test_conflict_resolver_is_shared_production_code(self):
        db = (ROOT / 'lib/src/database/local_database.dart').read_text(encoding='utf-8')
        resolver = (ROOT / 'lib/src/sync/conflict_resolver.dart').read_text(encoding='utf-8')
        self.assertIn('incomingRecordIsNewer', db)
        self.assertIn('incomingRecordIsNewer', resolver)
        self.assertIn("incoming['revision']", resolver)
        self.assertIn("incoming['client_updated_at']", resolver)
        self.assertIn("incoming['device_id']", resolver)

    def test_device_and_native_transport_settings_never_enter_firestore(self):
        text = (ROOT / 'lib/src/services/sync_service.dart').read_text(encoding='utf-8')
        for key in (
            'device_id',
            'drive_sync_folder',
            'sync_mode',
            'floating_timer_command',
            'floating_timer_heartbeat',
        ):
            self.assertIn(f"'{key}'", text)
        self.assertIn('localOnlySettingKeys.contains(key)', text)
        self.assertIn('where((doc) => !localOnlySettingKeys.contains(doc.id))', text)

    def test_northstar_images_are_chunked_below_firestore_document_limit(self):
        text = (ROOT / 'lib/src/services/sync_service.dart').read_text(encoding='utf-8')
        self.assertIn("collection('northstar_assets')", text)
        self.assertIn("collection('chunks')", text)
        self.assertIn('northStarImageChunkChars = 700000', text)
        self.assertIn("payload.remove('image_base64')", text)
        self.assertIn("row['image_base64'] = buffer.toString()", text)
        self.assertIn("'image_chunk_count'", text)

    def test_periodic_sync_only_pushes_dirty_queue(self):
        text = (ROOT / 'lib/src/services/sync_service.dart').read_text(encoding='utf-8')
        self.assertIn('syncNow(silent: true, pullRemote: false)', text)
        self.assertIn('bool pullRemote = true', text)
        self.assertIn('if (pullRemote) {', text)
        sync_body = text[text.index('Future<void> syncNow'):text.index('String _verifiedStatus')]
        self.assertNotIn('await _pushSettings(user)', sync_body)
        self.assertNotIn('await _pushTimerState(user)', sync_body)

    def test_settings_and_timer_changes_join_dirty_queue(self):
        db = (ROOT / 'lib/src/database/local_database.dart').read_text(encoding='utf-8')
        self.assertIn("enqueueEntity('app_settings', key)", db)
        self.assertIn("enqueueEntity('timer_state', '1')", db)
        sync = (ROOT / 'lib/src/services/sync_service.dart').read_text(encoding='utf-8')
        self.assertIn("if (entityType == 'app_settings')", sync)
        self.assertIn("if (entityType == 'timer_state')", sync)

    def test_realtime_listeners_cover_settings_and_timer_state(self):
        text = (ROOT / 'lib/src/services/sync_service.dart').read_text(encoding='utf-8')
        self.assertIn("collection('settings').snapshots()", text)
        self.assertIn("collection('meta').doc('timer_state').snapshots()", text)
        controller = (ROOT / 'lib/src/controllers/app_controller.dart').read_text(encoding='utf-8')
        self.assertIn('onRemoteChanged: _reloadRemoteState', controller)
        self.assertIn('await timerEngine.reloadFromDatabase()', controller)

    def test_reenqueuing_replaces_pending_token_to_preserve_inflight_edits(self):
        db = (ROOT / 'lib/src/database/local_database.dart').read_text(encoding='utf-8')
        start = db.index('Future<void> enqueueEntity')
        end = db.index('Future<List<SyncQueueEntry>> loadSyncQueue', start)
        block = db[start:end]
        self.assertIn('conflictAlgorithm: ConflictAlgorithm.replace', block)
        self.assertNotIn('conflictAlgorithm: ConflictAlgorithm.ignore', block)


if __name__ == '__main__':
    unittest.main()
