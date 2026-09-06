# LiftFlow

A modern, high-performance gym management and athletic member engagement platform built with Flutter and Supabase.

---

## 1. Environment & Build Configuration

LiftFlow strictly injects environment parameters and credentials at compile time via Flutter's `--dart-define` / `--dart-define-from-file` mechanism. This ensures:
- **Zero hardcoded secrets** in Dart source code.
- **No plaintext `.env` asset files** bundled in the application package.
- **Only public `anon` / publishable keys** are included in mobile binaries (service-role keys remain exclusively on backend Edge Functions).

### Required Environment Variables

| Variable | Description | Example |
| :--- | :--- | :--- |
| `ENV` | Environment name (`dev`, `staging`, `production`, `test`) | `dev` |
| `SUPABASE_URL` | Hosted Supabase project URL | `https://your-project.supabase.co` |
| `SUPABASE_ANON_KEY` | Public Supabase anonymous client API key | `eyJhbGci...` |
| `APP_NAME` | Display name of the application | `LiftFlow` |

---

## 2. Quickstart for Developers

### Step 1: Clone and Set Up Configuration
Copy the configuration template to `config/dev.json` (which is excluded in `.gitignore`):

```bash
cp config/env.example.json config/dev.json
```

Populate `config/dev.json` with your Supabase credentials:

```json
{
  "ENV": "dev",
  "SUPABASE_URL": "https://<your-project-ref>.supabase.co",
  "SUPABASE_ANON_KEY": "<your-anon-key>",
  "APP_NAME": "LiftFlow"
}
```

### Step 2: Install Dependencies
```bash
flutter pub get
```

### Step 3: Run Static Analysis & Tests
```bash
flutter analyze
flutter test
```

---

## 3. Running the App

### Option A: Using `--dart-define-from-file` (Recommended)
```bash
# Run on connected physical device or emulator
flutter run --dart-define-from-file=config/dev.json

# Run on Chrome / Edge Web
flutter run -d edge --dart-define-from-file=config/dev.json
```

### Option B: Using Direct `--dart-define` Flags
```bash
flutter run \
  --dart-define=ENV=dev \
  --dart-define=SUPABASE_URL=https://<your-project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key> \
  --dart-define=APP_NAME=LiftFlow
```

### Option C: VS Code & Android Studio
- **VS Code**: Select `LiftFlow (Dev - Device)` from the Run & Debug pane (`F5`).
- **Android Studio / IntelliJ**: Select `main.dart` from the run configuration dropdown.

---

## 4. Building Android APKs

### Build Debug APK
```bash
flutter build apk --debug --dart-define-from-file=config/dev.json
```
Output: `build/app/outputs/flutter-apk/app-debug.apk`

### Build Release APK
```bash
flutter build apk --release --dart-define-from-file=config/dev.json
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### Install on Connected Physical Android Device
```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```
Or with release APK:
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## 5. Security Protocol

1. **Never commit secrets**: `config/dev.json`, `config/prod.json`, `*.env`, and keystores are strictly ignored by `.gitignore`.
2. **Client keys only**: Only the public `SUPABASE_ANON_KEY` is passed to Flutter. The `service_role` key must **never** be supplied to Flutter client builds.
