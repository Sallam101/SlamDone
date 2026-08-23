import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class FirebaseSourceContractTest(unittest.TestCase):
    def test_pubspec_uses_flutterfire_not_supabase(self):
        text = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
        self.assertIn('firebase_core:', text)
        self.assertIn('firebase_auth:', text)
        self.assertIn('cloud_firestore:', text)
        self.assertNotIn('supabase_flutter:', text)

    def test_main_initializes_firebase_conditionally(self):
        text = (ROOT / 'lib/main.dart').read_text(encoding='utf-8')
        self.assertIn('Firebase.initializeApp', text)
        self.assertIn('FirebaseConfig.isConfigured', text)
        self.assertNotIn('Supabase.initialize', text)

    def test_sync_service_uses_google_firebase_auth(self):
        text = (ROOT / 'lib/src/services/sync_service.dart').read_text(encoding='utf-8')
        self.assertIn('FirebaseAuth.instance', text)
        self.assertIn('signInWithGoogle', text)
        self.assertIn('GoogleAuthProvider', text)
        self.assertNotIn('Supabase.instance', text)

    def test_settings_uses_google_sign_in(self):
        text = (ROOT / 'lib/src/screens/settings_screen.dart').read_text(encoding='utf-8')
        self.assertIn('Continue with Google', text)
        self.assertNotIn('Create account', text)
        self.assertNotIn("labelText: 'Password'", text)


if __name__ == '__main__':
    unittest.main()
