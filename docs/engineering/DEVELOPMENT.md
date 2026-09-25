# Cashflow Development Guide

Engineering manual for setting up, building, testing, and debugging Cashflow.

---

## Local Setup

### Prerequisites
- Flutter SDK (3.x or higher)
- Android SDK / Android Studio (for Android build and emulator support)
- Xcode (for macOS and iOS targets)

Verify toolchains and connected devices:

```bash
flutter doctor
flutter devices
```

Install Dart and Flutter dependencies:

```bash
flutter pub get
```

---

## Common Development Commands

### Running the App
Run on default detected device:
```bash
flutter run
```

Run on a specific device or target:
```bash
flutter run -d chrome
flutter run -d emulator-5554
flutter run -d ios
flutter run -d macos
flutter run -d <wireless-device-id> # e.g. adb-RZCX127ARVK-Q5g91b._adb-tls-connect._tcp
```

Run with Play Store version of coffee (Google Play Billing tip jar):
```bash
flutter run --dart-define=ENABLE_EXTERNAL_DONATIONS=false
```

Run with Buy Me a Coffee version (external donations - default in debug):
```bash
flutter run --dart-define=ENABLE_EXTERNAL_DONATIONS=true
```

### Static Analysis & Formatting
Format code according to project rules:
```bash
dart format lib test
```

Execute static lint analysis:
```bash
flutter analyze
```

### Running Automated Tests
Run all unit and widget tests (runs in parallel via in-memory SQLite):
```bash
flutter test
```

Run a specific test file:
```bash
flutter test test/screens/dashboard_screen_test.dart
```

### Git Quality Hooks
Repository invariants are enforced via git hooks: `pre-commit` performs fast local verification (secrets, formatting, static analysis, script compilation), while `pre-push` executes the automated test suite and verifies code coverage (≥60%):
```bash
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit .githooks/pre-push
```

---

## Android Emulator Workflow

List configured Android Virtual Devices (AVDs):
```bash
flutter emulators
```

Launch an emulator:
```bash
flutter emulators --launch <emulator-id>
```

Verify connection:
```bash
flutter devices
adb devices
```

Run Cashflow on `emulator-5554`:
```bash
flutter run -d emulator-5554
```

### Terminal Hot Reload Controls
While `flutter run` is active in your terminal:
- Press `r` for **hot reload** (preserves state, updates widget tree).
- Press `R` for **hot restart** (resets state, restarts application).
- Press `q` to terminate the debug session.

---

## Android Wireless Debugging Workflow

Run and debug Cashflow on a physical Android device over local Wi-Fi without a USB cable:

### 1. Enable Wireless Debugging on Device
1. Enable **Developer Options**: Go to **Settings → About Phone → Software Information** and tap **Build Number** 7 times.
2. Go to **Settings → Developer Options → Wireless debugging** and toggle it **ON**.
3. Confirm connection to the same local Wi-Fi network as your development machine.

### 2. Connect via ADB
Pair device (first-time setup only):
```bash
adb pair <ip-address>:<port> <pairing-code>
```

Connect via ADB (if not auto-connected via mDNS TLS):
```bash
adb connect <ip-address>:<port>
```

Verify connected devices:
```bash
flutter devices
# or
adb devices
```

### 3. Run Cashflow on Wireless Target
Launch app on detected wireless device:
```bash
flutter run -d <wireless-device-id>

# Example:
flutter run -d adb-RZCX127ARVK-Q5g91b._adb-tls-connect._tcp
```

### 4. Interactive Development Controls
While `flutter run` is active in your terminal:
- Press `r` for **hot reload** (preserves state, updates widget tree).
- Press `R` for **hot restart** (resets state, restarts application).
- Press `q` to terminate the debug session.

---

## Screenshot Automation

The repository provides automated screenshot generation driven by Flutter integration tests:

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"
adb shell pm clear com.vyavahareyash.cashflow >/dev/null
node scripts/capture_screenshots.mjs
```

Screenshots are saved directly to `screenshots/`.

---

## Testing Guidelines & Pitfall Prevention

Follow these rules to prevent test deadlocks or flaky failures:

1. **In-Memory SQLite testing**: Tests run `sqflite_common_ffi` using `inMemoryDatabasePath` so they can run concurrently without file lock errors.
2. **No async database I/O in `testWidgets`**:
   `testWidgets` runs inside a `fakeAsync` zone. Performing SQLite file operations inside `testWidgets` deadlocks. Place database logic and queries inside standard `test(...)` blocks, and test UI rendering using in-memory model instances and `await tester.pump()`.
3. **Avoid unbounded `pumpAndSettle()`**:
   Screens with animated transitions, looping timers, or continuous streams will cause `pumpAndSettle()` to timeout. Use bounded pumps:
   ```dart
   await tester.pump();
   await tester.pump(const Duration(milliseconds: 100));
   ```
4. **Database cleanup isolation**:
   Ensure every test database file is deleted in both `setUp` and `tearDown` hooks.
5. **Form Field Conventions**:
   Use `initialValue` instead of deprecated `value` on `DropdownButtonFormField`.

---

## Release Builds

### Google Play Store (Android App Bundle)
Google Play Store requires production releases packaged as an Android App Bundle (`.aab`):

```bash
# Standard Play Store App Bundle (.aab)
flutter build appbundle --release

# With specific semantic version and build number:
flutter build appbundle --release --build-name=1.0.0 --build-number=1

# Output artifact location:
# build/app/outputs/bundle/release/app-release.aab
```

### Other Platform Targets

```bash
# Android APK (direct sideloading / offline installation)
flutter build apk --release

# Web
flutter build web --release

# iOS
flutter build ios --release
```
