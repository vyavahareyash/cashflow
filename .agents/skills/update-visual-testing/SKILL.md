---
name: update-visual-testing
description: Use when the user asks to update visual testing, refresh visual regression coverage, add screenshots for a new screen, or make screenshot tests follow app changes. Inspect the current Flutter navigation and screen implementations, reconcile the integration capture flow with the host adb runner, update both when coverage has drifted, and validate every current screen capture.
---

# Update Visual Testing

Maintain the repository's visual-testing capture flow as the app evolves. The goal is complete, usable screenshot coverage of the current user-visible screens and meaningful nested states, not preservation of an old screenshot count.

## Workflow

1. Establish the current contract before editing:
   - Read `lib/main.dart` to inventory top-level navigation destinations and their labels.
   - Read the screen implementations under `lib/screens/` to find nested tabs, important dialogs, empty/loading states, and stable readiness text.
   - Read `integration_test/screenshots_test.dart` to inventory semantic navigation, readiness waits, and emitted `SCREENSHOT_MARKER` names.
   - Read `scripts/capture_screenshots.mjs` to inventory the host-side marker order, device configuration, and PNG output behavior.
2. Compare these sources and make a coverage table mentally or in the task notes: each capture-worthy destination/state must have a semantic navigation path, a readiness condition, one integration marker, and one host capture entry.
3. Update the integration test when the app has changed:
   - Use current `find.text`, `find.byTooltip`, `find.widgetWithText`, or other stable semantic finders.
   - Wait for the current screen title or content and for loading indicators to disappear.
   - Add separate captures for tabs, nested views, dialogs, or other visually meaningful states that users can reach independently.
   - Keep marker emission awaited so the host can finish adb capture before navigation continues.
   - Load demo/sample data through the current UI when populated screenshots are required; discover changed labels and scrollable controls from the current implementation.
4. Update `scripts/capture_screenshots.mjs` to contain the exact same marker names and order as the integration test. Keep capture sequential and host-side through `adb exec-out screencap -p`.
5. Review the resulting coverage for drift:
   - No current top-level destination is missing unless it is intentionally excluded with a documented reason in the test.
   - No marker exists only on one side of the Dart/Node contract.
   - Every marker has a readiness condition appropriate to its current screen.
   - Output names are numbered and filesystem-safe, but the workflow does not assume a fixed count.
6. Validate from the repository root:

   ```sh
   export ANDROID_HOME=$HOME/Library/Android/sdk
   export PATH=$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH
   adb shell pm clear com.example.cashflow >/dev/null
   rm -f screenshots/*.png
   node scripts/capture_screenshots.mjs
   file screenshots/*.png
   ```

   Use `ANDROID_DEVICE` when the target emulator is not `emulator-5554`. If no emulator is available, still run static checks and report the runtime validation as blocked rather than claiming completion.
7. Confirm `flutter drive` reports `All tests passed`, the marker sequence emitted by Dart matches the host sequence, and every current marker produced a valid PNG with the emulator's expected dimensions.

## Ownership Rules

- `lib/main.dart` and the screen implementations define what the app currently exposes.
- `integration_test/screenshots_test.dart` defines semantic navigation, readiness, and marker emission.
- `scripts/capture_screenshots.mjs` defines host synchronization and PNG persistence.
- Keep the integration test and host runner synchronized in the same edit whenever a screen is added, removed, renamed, or reordered.
- Prefer a content/title readiness check plus a small frame settle over arbitrary long delays; retain the awaited marker delay required by the host capture process.
- Treat charts and animated transitions as loaded only after their visible content exists and enough frames have settled for a stable framebuffer.
- Do not use coordinate-based adb taps for app navigation; adb is reserved for device setup and framebuffer capture.

## Change Detection Checklist

When visual testing is requested after an app change, search for:

- New or removed `NavigationDestination` entries.
- Changed destination labels, tooltips, app-bar titles, or tab labels.
- New routes, dialogs, bottom sheets, tabs, or conditional empty/loading/error states.
- Changed sample-data actions or confirmation text.
- Marker names present in only one capture implementation.
- Screenshots in the output directory that no longer correspond to current markers.

## Completion Criteria

The task is complete only when the capture code reflects the repository's current screen inventory, semantic navigation and readiness checks pass, Dart and Node marker contracts are identical and ordered, and every current marker produces a valid screenshot. Mention intentional exclusions and unavailable emulator validation explicitly.
