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
Run all unit and widget tests sequentially ([ADR-0004](../adr/0004-single-concurrency-sqlite-testing.md)):
```bash
flutter test --concurrency=1
```

Run a specific test file:
```bash
flutter test test/screens/dashboard_screen_test.dart
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

1. **Single concurrency mandatory (`--concurrency=1`)**:
   Tests run `sqflite_common_ffi` on local test database files. Concurrency $>1$ causes SQLite file lock errors (`OS error 5 / database is locked`).
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

```bash
# Android APK
flutter build apk --release

# Web
flutter build web --release

# iOS
flutter build ios --release
```
