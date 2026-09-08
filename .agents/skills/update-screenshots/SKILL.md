---
name: update-screenshots
description: Use when the user asks to update, refresh, regenerate, or recapture app screenshots, especially after changing the app or a screen. Inspect the current semantic integration flow, keep its marker list synchronized with the adb capture runner, run it on Android, and verify every generated PNG.
---

# Update Screenshots

Run the repository's current screenshot flow on the Android emulator. The flow uses Flutter integration-test semantics for navigation and readiness, and the host Node script uses `adb screencap` for PNG capture.

## Workflow

1. Inspect `integration_test/screenshots_test.dart` and `scripts/capture_screenshots.mjs` before changing the flow. Treat the awaited `_markScreen` calls in the integration test and the marker array in the Node script as one ordered contract.
2. If the app or a screen changed, update the integration flow first: use current semantic labels, titles, tooltips, and content readiness signals; add, remove, or rename markers to match the requested screen set; then mirror that exact marker order in the Node script.
3. Ensure an Android emulator is running. The default device is `emulator-5554`; use `ANDROID_DEVICE` when another emulator is required.
4. Start from clean app data when screenshots must contain the standard demo dataset:

   ```sh
   export ANDROID_HOME=$HOME/Library/Android/sdk
   export PATH=$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH
   adb shell pm clear com.example.cashflow >/dev/null
   ```

5. Run the capture script from the repository root:

   ```sh
   rm -f screenshots/*.png
   node scripts/capture_screenshots.mjs
   file screenshots/*.png
   ```

6. Confirm the Flutter test reports `All tests passed`, the emitted marker sequence matches the host marker array, and every marker produces a valid PNG. Do not assume a fixed screenshot count; derive it from the current marker array.

## Data And Screen Changes

Sample data is loaded before the first screen marker when the capture flow requires populated screenshots. Keep this setup aligned with the current backup UI: discover the current sample-data action and confirmation labels, scroll its semantic ancestor into view, wait for the success state, and return to the first screen.

For a new or modified screen, identify its stable semantic navigation control and a reliable readiness condition. A title, tab label, loaded content label, or absence of a loading indicator is preferable to a fixed delay. For a changed tab or nested view, add a separate marker when it needs its own screenshot.

Use numbered, filesystem-safe marker names for output files, but do not rely on the current numbers or names in this document. The integration test and host script are the source of truth.

## Readiness Rules

- Navigate with semantic finders such as `find.text`, `find.byTooltip`, and `find.widgetWithText`; do not add coordinate-based adb taps.
- After opening a screen, wait for its title and for loading indicators to disappear before marking it.
- After tapping a tab or nested view, wait for its transition to settle and for its content to render before marking it; use extra pumped frames when charts or animations need them.
- Keep `_markScreen` awaited. It intentionally leaves time for the host-side adb capture to finish before the Flutter test navigates again.
- Keep the host marker list synchronized with the marker names in the integration test.

## Troubleshooting

- If a control is offscreen, resolve the `Scrollable` ancestor from that control, drag it into view, call `pumpAndSettle`, and only then tap it.
- If a marker times out, check that the corresponding marker is emitted after the required title/content readiness condition and that the host list contains the same name.
- If capture appears to show the next screen, increase the awaited marker delay in `_markScreen` rather than adding host-side concurrent captures.
- If a screen was renamed or added, search for all old and new marker names and update both sides of the marker contract.
- If adb is not found, re-export `ANDROID_HOME` and prepend `$ANDROID_HOME/platform-tools` to `PATH`.

## Completion Criteria

The task is complete only when the current requested screenshot set has been regenerated, the Flutter integration test passes, the marker order is synchronized between Dart and Node, and each expected screenshot is a valid PNG from the emulator.