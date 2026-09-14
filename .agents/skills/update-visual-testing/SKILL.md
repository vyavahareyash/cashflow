---
name: update-visual-testing
description: Use when the user asks to update visual testing, refresh visual regression coverage, add screenshots for a new screen, or make screenshot tests follow app changes. Inspect the current Flutter navigation and screen implementations, reconcile the integration capture flow with the host adb runner, update both when coverage has drifted, and validate every current screen capture.
---

# Update Visual Testing

Maintain the repository's visual-testing capture flow as the app evolves. The goal is complete, usable screenshot coverage of the current user-visible screens, input modals, interactive component states, and theme variants (Light and Dark), not preservation of an old screenshot count.

## Workflow

1. Establish the current contract before editing:
   - Read `lib/main.dart` to inventory top-level navigation destinations, theme configurations, and their labels.
   - Read the screen implementations under `lib/screens/` to find nested tabs (e.g. Activity Ledger vs Analytics & Trends), input modals/dialogs (Expense, Income, Transfer, Add/Edit Category, Add/Edit Goal, Lock Funds, Add Account), and interactive component states (e.g. Accounts locked funds accordion).
   - Read `integration_test/screenshots_test.dart` to inventory semantic navigation, readiness waits, theme transitions, and emitted `SCREENSHOT_MARKER` names.
   - Read `scripts/capture_screenshots.mjs` to inventory the host-side marker order, device configuration, PNG output behavior, and review gallery generator.
2. Compare these sources and maintain a dual-pass coverage matrix:
   - **Pass 1 (Light Mode)**: Primary screens, bottom sheets, modals, and interaction states in light theme.
   - **Pass 2 (Dark Mode)**: Toggles theme via `Toggle Theme` tooltip and captures paired screens and modals in dark theme.
3. Update the integration test when the app has changed:
   - Use current `find.text`, `find.textContaining`, `find.byTooltip`, `find.widgetWithText`, or other stable semantic finders.
   - Use `find.textContaining` for dynamic amounts or dates (e.g. `'Total saved:'`, `'Locked Funds ('`).
   - For pushed full-page routes (e.g. `BackupRestoreScreen`), unwind back to the root navigation shell via `await tester.pageBack()` before theme switching.
   - For multi-tab screens (e.g. `Insights & Activity`), explicitly tap each destination tab (`find.text('Activity Ledger')`, `find.text('Analytics & Trends')`) and await distinctive content.
   - For screens with multiple diagrams or below-the-fold visualizations (e.g. `Monthly Spending Trends` line chart and stats grid located below the category donut chart), add dedicated scrolled markers (`16b-analytics-trends-scroll-light`, `26b-analytics-trends-scroll-dark`) using `tester.drag(scrollable, const Offset(0, -550))`, followed by `pumpAndSettle` and pumped animation frames to allow chart curves to stabilize before calling `_markScreen`.
   - Ensure offscreen or scrollable elements are brought into view using `tester.ensureVisible(...)` before tapping.
   - Keep marker emission awaited so the host can finish adb capture before navigation continues.
   - Load demo/sample data through the current UI when populated screenshots are required; discover changed labels and scrollable controls from the current implementation.
4. Update `scripts/capture_screenshots.mjs` to contain the exact same marker names, types, descriptions, and order across BOTH `markers` array and the `PAIRS` comparison matrix as the integration test.
5. Review the resulting coverage for drift:
   - No current top-level destination is missing unless it is intentionally excluded with a documented reason in the test.
   - Dedicated captures exist for tabs with distinct content (such as the Activity Ledger and Trends tabs) and scrolled views for below-the-fold diagrams.
   - Input modals and key expanded components have matching Light and Dark pairs.
   - No marker exists only on one side of the Dart/Node contract.
   - Every marker has a readiness condition appropriate to its current screen.
   - Output names are numbered and filesystem-safe (e.g. `15-activity-ledger-light`, `16b-analytics-trends-scroll-light`, `25-activity-ledger-dark`).
6. Validate from the repository root:

   ```sh
   export ANDROID_HOME=$HOME/Library/Android/sdk
   export PATH=$HOME/Documents/flutter/bin:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH
   adb shell pm clear com.example.cashflow >/dev/null
   rm -f screenshots/*.png
   PATH="$HOME/Documents/flutter/bin:$ANDROID_HOME/platform-tools:$PATH" node scripts/capture_screenshots.mjs
   file screenshots/*.png
   ```

   To quickly regenerate `screenshots/manifest.json` and `screenshots/index.html` without re-running device tests, use:

   ```sh
   node scripts/capture_screenshots.mjs --html-only
   ```

   Use `ANDROID_DEVICE` when the target emulator is not `emulator-5554`. In sandboxed execution environments, execute with sandbox bypass enabled to allow TCP socket communication to the ADB daemon (`tcp:5037`).
7. Confirm `flutter drive` reports `All tests passed`, the marker sequence emitted by Dart matches the host sequence, every marker produces a valid PNG with 1080x2424 RGBA resolution, and both `screenshots/manifest.json` and `screenshots/index.html` review gallery are up to date.

## Ownership Rules

- `lib/main.dart` and the screen implementations define what the app currently exposes.
- `integration_test/screenshots_test.dart` defines semantic navigation, readiness, and marker emission.
- `scripts/capture_screenshots.mjs` defines host synchronization, PNG persistence, `screenshots/manifest.json`, and the standalone `screenshots/index.html` review gallery.
- Keep the integration test, host runner, manifest metadata, and review gallery synchronized in the same edit whenever a screen, modal, tab, or scrolled diagram is added, removed, renamed, or reordered.
- Prefer a content/title readiness check plus a small frame settle over arbitrary long delays; retain the awaited marker delay required by the host capture process.
- Treat charts and animated transitions as loaded only after their visible content exists and enough frames have settled for a stable framebuffer.
- Do not use coordinate-based adb taps for app navigation; adb is reserved for device setup and framebuffer capture.

## Change Detection Checklist

When visual testing is requested after an app change, search for:

- New or removed `NavigationDestination` entries.
- Changed destination labels, tooltips, app-bar titles, or tab labels.
- New routes, dialogs, bottom sheets, tabs, or conditional empty/loading/error states.
- Dedicated tab destinations (e.g. Activity Ledger vs Analytics & Trends) requiring explicit navigation.
- Below-the-fold diagrams, charts, or statistic tables requiring dedicated scrolled markers.
- Changed sample-data actions or confirmation text.
- Marker names present in only one capture implementation or missing in `PAIRS`.
- Screenshots in the output directory that no longer correspond to current markers.

## Completion Criteria

The task is complete only when:
1. The capture code reflects the repository's current screen, modal, and tab inventory across Light and Dark passes.
2. Semantic navigation and readiness checks pass with zero test failures.
3. Dart and Node marker contracts are identical and ordered.
4. Every current marker produces a valid screenshot (1080x2424 RGBA).
5. `screenshots/manifest.json` and `screenshots/index.html` review gallery are generated and verified. Mention intentional exclusions and unavailable emulator validation explicitly.
