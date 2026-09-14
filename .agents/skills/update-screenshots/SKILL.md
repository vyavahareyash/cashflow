---
name: update-screenshots
description: Use when the user asks to update, refresh, regenerate, or recapture app screenshots, especially after changing the app or a screen. Inspect the current semantic integration flow, keep its marker list synchronized with the adb capture runner, run it on Android, and verify every generated PNG.
---

# Update Screenshots

Run the repository's current screenshot flow on the Android emulator. The flow uses Flutter integration-test semantics for navigation and readiness, and the host Node script uses `adb screencap` for sequential PNG capture across both Light and Dark modes.

## Workflow

1. Inspect `integration_test/screenshots_test.dart` and `scripts/capture_screenshots.mjs` before changing the flow. Treat the awaited `_markScreen` calls in the integration test and both the `markers` array and the `PAIRS` comparison array in the Node script as one ordered contract.
2. The capture flow systematically tests two passes:
   - **Pass 1 (Light Mode)**: captures all primary screens, input modals (Expense, Income, Transfer, Add/Edit Category, Add/Edit Goal, Lock Funds, Add Account), tab selections (e.g. Activity Ledger vs Analytics & Trends), scrolled views for secondary diagrams/statistics (e.g. `16b-analytics-trends-scroll-light`), and expanded component states (Account locked funds accordion).
   - **Pass 2 (Dark Mode)**: toggles theme via tooltip `Toggle Theme` and captures corresponding screens, modals, scrolled views (e.g. `26b-analytics-trends-scroll-dark`), and interaction states in dark high contrast.
3. If the app or a screen changed, update the integration flow first:
   - Use stable semantic finders (`find.text`, `find.textContaining`, `find.byTooltip`, `find.widgetWithText`).
   - Use `find.textContaining` for cards or dialogs with dynamic numbers/currency.
   - For pushed full-page routes (e.g. `BackupRestoreScreen`), unwind back to the root navigation shell via `await tester.pageBack()` before triggering theme toggles.
   - For multi-tab screens (e.g. `Insights & Activity`), explicitly tap each destination tab (`find.text('Activity Ledger')`, `find.text('Analytics & Trends')`) and await distinct content.
   - For screens with multiple diagrams or below-the-fold charts (e.g. Monthly Spending Trends line chart below donut chart), add a dedicated scrolled marker (e.g. `16b`, `26b`) by dragging the scrollable (`await tester.drag(scrollableFinder, const Offset(0, -550))`), settling (`pumpAndSettle`), and pumping extra frames for chart stabilization before calling `_markScreen`.
   - Mirror the exact marker name and order in `scripts/capture_screenshots.mjs` across BOTH `markers` and `PAIRS`.
4. Ensure an Android emulator is running (`emulator-5554` default; or specify `ANDROID_DEVICE`).
5. Start from clean app data when screenshots must contain the standard demo dataset:

   ```sh
   export ANDROID_HOME=$HOME/Library/Android/sdk
   export PATH=$HOME/Documents/flutter/bin:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH
   adb shell pm clear com.example.cashflow >/dev/null
   ```

6. Run the capture script from the repository root:

   ```sh
   rm -f screenshots/*.png
   PATH="$HOME/Documents/flutter/bin:$ANDROID_HOME/platform-tools:$PATH" node scripts/capture_screenshots.mjs
   file screenshots/*.png
   ```

   To quickly regenerate `screenshots/manifest.json` and `screenshots/index.html` without re-running device tests, use:

   ```sh
   node scripts/capture_screenshots.mjs --html-only
   ```

7. Confirm the Flutter test reports `All tests passed`, the emitted marker sequence matches the host marker array, every marker produces a valid PNG (1080x2424 RGBA), and both `screenshots/manifest.json` and `screenshots/index.html` are generated.

## Data And Screen Changes

Sample data is loaded before the first screen marker when the capture flow requires populated screenshots. Keep this setup aligned with the current backup UI: discover the current sample-data action and confirmation labels, scroll its semantic ancestor into view, wait for the success state, and return to the first screen.

For a new or modified screen, identify its stable semantic navigation control and a reliable readiness condition. A title, tab label, loaded content label, or absence of a loading indicator is preferable to a fixed delay. For a changed tab, nested view, or below-the-fold chart, add a separate marker when it needs its own screenshot.

Use numbered, filesystem-safe marker names for output files (`01-dashboard-light`, `15-activity-ledger-light`, `16b-analytics-trends-scroll-light`, `25-activity-ledger-dark`), but do not rely on hardcoded counts in documents; derive counts dynamically from the marker array.

## Readiness Rules

- Navigate with semantic finders such as `find.text`, `find.textContaining`, `find.byTooltip`, and `find.widgetWithText`; do not add coordinate-based adb taps.
- After opening a screen or modal, wait for its title and for loading indicators (`CircularProgressIndicator`) to disappear before marking it.
- After tapping a tab or nested view, wait for its transition to settle (`pumpAndSettle`) and for its content to render before marking it; use extra pumped frames when charts or animations need them.
- For scrolled/below-the-fold views, drag the scrollable into view using `tester.drag(scrollable, Offset(0, -Y))`, await settle and several pumped animation frames to allow chart curves to stabilize, and capture a distinct scrolled marker.
- Ensure scrollable triggers are brought into the visible viewport with `tester.ensureVisible(...)` before tapping.
- Keep `_markScreen` awaited. It intentionally leaves time for the host-side adb capture to finish before the Flutter test navigates again.
- Keep both the host `markers` list and the `PAIRS` array synchronized with the marker names in the integration test.

## Troubleshooting

- If a control is offscreen or partially obscured, call `tester.ensureVisible(finder)` or drag it into view, call `pumpAndSettle`, and only then tap it.
- If a modal does not dismiss cleanly, verify whether it uses an explicit close button (`find.byTooltip('Close')`), `find.text('Cancel')`, or `tester.pageBack()`.
- If ADB communication fails on macOS in sandboxed environments, run the capture command with sandbox bypass enabled to allow TCP socket access to ADB server (`tcp:5037`). Also ensure `flutter` is executable in non-interactive PATH.
- If the test fails after all screenshots are marked (e.g. during final navigation back to main screens), check for `RenderFlex` overflows caused by dynamic strings/data; wrap flexible content rows in `Expanded` with `TextOverflow.ellipsis`.
- If side-by-side comparisons in `screenshots/index.html` are misaligned or broken, verify that `PAIRS` in `scripts/capture_screenshots.mjs` includes the new marker IDs.
- If capture appears to show the next screen, increase the awaited marker delay in `_markScreen` rather than adding host-side concurrent captures.
- If a marker was renamed or removed, clean up obsolete PNGs (`rm -f screenshots/*.png`) so no orphaned files pollute the review gallery.
- If adb is not found, re-export `ANDROID_HOME` and prepend `$ANDROID_HOME/platform-tools` to `PATH`.

## Completion Criteria

The task is complete only when:
1. The requested screenshot set has been regenerated across Light and Dark passes.
2. The Flutter integration test passes with zero failures.
3. The marker order is synchronized between Dart and Node.
4. Each expected screenshot is a valid PNG from the emulator (1080x2424 RGBA).
5. `screenshots/manifest.json` and `screenshots/index.html` review gallery are generated and up to date.