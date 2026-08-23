# SupeSlam Firebase Setup

Use a dedicated Firebase project for SupeSlam unless you have deliberately designed another project to share these exact collection names. A separate project avoids accidental overlap with MathFreak, USCrisp, or another app.

## 1. Create the Firebase web app

1. Open Firebase Console and create/select the SupeSlam project.
2. Add a **Web app**.
3. Copy the web configuration values shown by Firebase.
4. In **Authentication → Sign-in method**, enable **Google**.
5. In **Authentication → Settings → Authorized domains**, add:
   - `sallam101.github.io`
6. Create a **Cloud Firestore** database.

SupeSlam does not require Firebase Cloud Storage for the Autivra migration baseline. Embedded NorthStar images are kept inside the user's Firestore namespace as bounded chunk documents.

## 2. Apply Firestore rules

The repository contains `firestore.rules`. The rule is intentionally UID-scoped: a signed-in user can only read/write paths below their own `users/{uid}` namespace.

You can paste `firestore.rules` into **Firestore Database → Rules** and publish it, or with Firebase CLI run:

```bash
firebase deploy --only firestore:rules
```

`firebase.json` already points the CLI to the repository rule file.

## 3. Add GitHub repository variables

In `Sallam101/SupeSlam` open **Settings → Secrets and variables → Actions → Variables** and create:

- `FIREBASE_API_KEY`
- `FIREBASE_AUTH_DOMAIN`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_STORAGE_BUCKET`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_APP_ID`
- `FIREBASE_MEASUREMENT_ID` — optional

Do not put a Firebase service-account JSON or Admin SDK private key in the web build.

The Pages workflow injects these values at `flutter build web` time with Dart defines.

## 4. Enable GitHub Pages

1. Open **Settings → Pages**.
2. Under **Build and deployment**, choose **GitHub Actions**.
3. Push to `main` or manually run **Build and deploy SupeSlam PWA** from the Actions tab.
4. When the workflow is green, open:

`https://Sallam101.github.io/SupeSlam/`

## 5. First sign-in check

1. Open the Pages URL on the PC.
2. Go to Settings and choose Google sign-in.
3. Confirm the signed-in account is shown.
4. Create one harmless test record, press Sync now, then open the site on the phone with the same Google account and confirm the record appears.
5. Only after that cross-device smoke test should you import the private Autivra migration file.
