import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class RepoContractTest(unittest.TestCase):
    def test_private_migration_artifacts_are_ignored(self):
        text = (ROOT / '.gitignore').read_text(encoding='utf-8')
        for pattern in ('*.db', '*.db-wal', '*.db-shm', '*Migration*.json'):
            self.assertIn(pattern, text)

    def test_firestore_rules_are_uid_scoped(self):
        rules = (ROOT / 'firestore.rules').read_text(encoding='utf-8')
        self.assertIn('match /users/{uid}/{document=**}', rules)
        self.assertIn('request.auth.uid == uid', rules)

    def test_pages_build_targets_slamdone_base_href(self):
        workflow = (ROOT / '.github/workflows/pages.yml').read_text(encoding='utf-8')
        self.assertIn('flutter test', workflow)
        self.assertIn('flutter build web --release --base-href /SlamDone/', workflow)
        self.assertIn('actions/upload-pages-artifact@v4', workflow)
        self.assertIn('actions/deploy-pages@v4', workflow)

    def test_pages_removes_generated_flutter_template_widget_test(self):
        workflow = (ROOT / '.github/workflows/pages.yml').read_text(encoding='utf-8')
        self.assertIn('rm -f test/widget_test.dart', workflow)
        self.assertLess(
            workflow.index('rm -f test/widget_test.dart'),
            workflow.index('flutter test'),
        )

    def test_pages_build_injects_all_firebase_web_config(self):
        workflow = (ROOT / '.github/workflows/pages.yml').read_text(encoding='utf-8')
        required = (
            'FIREBASE_API_KEY',
            'FIREBASE_AUTH_DOMAIN',
            'FIREBASE_PROJECT_ID',
            'FIREBASE_STORAGE_BUCKET',
            'FIREBASE_MESSAGING_SENDER_ID',
            'FIREBASE_APP_ID',
        )
        for name in required:
            self.assertIn(f'--dart-define={name}=${{{{ vars.{name} }}}}', workflow)

    def test_docs_pin_repo_url_and_firebase_setup(self):
        combined = '\n'.join(
            (ROOT / name).read_text(encoding='utf-8')
            for name in ('README.md', 'FIREBASE_SETUP.md', 'MIGRATION_AUTIVRA4.md')
        )
        self.assertIn('https://Sallam101.github.io/SlamDone/', combined)
        for name in (
            'FIREBASE_API_KEY',
            'FIREBASE_AUTH_DOMAIN',
            'FIREBASE_PROJECT_ID',
            'FIREBASE_STORAGE_BUCKET',
            'FIREBASE_MESSAGING_SENDER_ID',
            'FIREBASE_APP_ID',
        ):
            self.assertIn(name, combined)
        self.assertNotIn('SUPABASE_URL', combined)
        self.assertNotIn('SUPABASE_PUBLISHABLE_KEY', combined)

    def test_firebase_cli_config_points_to_uid_rules(self):
        config = (ROOT / 'firebase.json').read_text(encoding='utf-8')
        self.assertIn('firestore.rules', config)

    def test_legacy_supabase_assets_are_not_shipped(self):
        for relative in (
            'SUPABASE_SETUP.md',
            'supabase_config.example.json',
            'lib/src/generated/supabase_config.dart',
            'supabase',
        ):
            self.assertFalse((ROOT / relative).exists(), relative)

    def test_recovered_demo_seed_methods_are_not_shipped(self):
        repository = (ROOT / 'lib/src/repositories/app_repository.dart').read_text(encoding='utf-8')
        self.assertNotIn('_insertSampleData', repository)
        self.assertNotIn('_insertDefaultRanks', repository)


if __name__ == '__main__':
    unittest.main()
