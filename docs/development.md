# Development Guide

Cashflow is a Flutter application with local SQLite storage. Run commands from the repository root.

## Setup

Install Flutter and verify the available toolchains and devices:

```bash
flutter doctor
flutter devices
```

Install project dependencies before the first run or after changing `pubspec.yaml`:

```bash
flutter pub get
```

## Common Commands

Run the app on the default Flutter device:

```bash
flutter run
```

Run on a specific device or platform:

```bash
flutter run -d chrome
flutter run -d emulator-5554
flutter run -d ios
```

Run all tests, a single test file, or static analysis:

```bash
flutter test
flutter test test/path/to/test_file.dart
flutter analyze
```

Format Dart files or the whole project:

```bash
dart format lib test
dart format .
```

Build release artifacts when needed:

```bash
flutter build apk
flutter build ios
flutter build web
```

## Run on an Android Emulator

List configured Android Virtual Devices:

```bash
flutter emulators
```

Launch an emulator by its listed identifier:

```bash
flutter emulators --launch <emulator-id>
```

Confirm that the emulator is available. The screenshot tooling uses `emulator-5554` by default.

```bash
flutter devices
adb devices
```

Run Cashflow on that emulator:

```bash
flutter run -d emulator-5554
```

## Apply Changes on the Emulator

Keep `flutter run` running in a terminal while developing. After saving Dart changes, use the Flutter terminal controls:

- Press `r` for hot reload. This applies most UI and logic changes while preserving the current app state.
- Press `R` for hot restart. This reruns the app and resets in-memory state when hot reload is not enough.
- Press `q` to stop the running app session.

You can also start or attach to the emulator again with:

```bash
flutter run -d emulator-5554
```

Use a full restart when changing native Android code, dependencies, platform configuration, or database initialization. Stop the current run with `q`, then run the command again. If the emulator is not detected, check:

```bash
adb devices
flutter devices
```

When using another emulator, replace the device identifier in the command or set `ANDROID_DEVICE` for scripts that support it:

```bash
ANDROID_DEVICE=<device-id> flutter run -d <device-id>
```

If `adb` is not found on macOS, set the Android SDK path and add the emulator and platform-tools directories to `PATH`:

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"
```

## Screenshot Capture

The repository includes an Android screenshot flow driven by Flutter integration tests. Start an emulator first, then run:

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"
adb shell pm clear com.example.cashflow >/dev/null
node scripts/capture_screenshots.mjs
```

To capture on a different emulator:

```bash
ANDROID_DEVICE=<device-id> node scripts/capture_screenshots.mjs
```

Screenshots are written to `screenshots/`.

## Recommended Pre-Change Check

Before opening a pull request, run the focused tests for the changed area, then run the full test suite and analyzer:

```bash
flutter test test/path/to/changed_test.dart
flutter test
flutter analyze
```