---
name: prepare-release
description: Prepare, validate, synchronize, and cut a new app release. Use when the user asks to "prepare a release", "cut a release", "bump version for release", "make a release", or "publish new release".
---

# Prepare & Cut Release

Workflow for cutting a production release of Cashflow across Flutter targets (Android APK/AAB, iOS unsigned, and GitHub Releases).

---

## 1. Release Inventory & State Check

Before touching code, inspect unreleased commits, current tags, and tree hygiene:

```bash
git status
git tag --sort=-v:refname | head -n 5
grep -E '^version:' pubspec.yaml
git log $(git describe --tags --abbrev=0 2>/dev/null || echo "HEAD~10")..HEAD --oneline
```

- Ensure working tree is clean.
- Read current version `X.Y.Z+B` from `pubspec.yaml`.
- Determine next version:
  - **Patch (`X.Y.Z+1`)**: backward-compatible bug fixes, UI polishes, docs/methodology updates.
  - **Minor (`X.Y+1.0`)**: new backward-compatible feature modules (e.g. new accounts tab, voice journaling improvements).
  - **Major (`X+1.0.0`)**: breaking schema/data migrations or paradigm shifts.
  - **Build Number (`B+1`)**: strictly monotonic integer incremented with every release.

---

## 2. File Synchronization Checklist

Every release requires synchronized edits across four locations:

### 1. `pubspec.yaml`
Update root `version` field:
```yaml
version: X.Y.Z+B
```

### 2. `lib/screens/backup_restore_screen.dart`
Update displayed system version string (~line 2317):
```dart
_buildInfoRow('Version', 'X.Y.Z (Build B)', isDark),
```

### 3. `CHANGELOG.md`
Prepend new release section under `# Changelog` using [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format:
```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- Feature description (#PR or commit)

### Changed
- Change description (#PR or commit)

### Fixed
- Fix description (#PR or commit)

---
```
Ensure all commits since last tag are captured with PR numbers or commit hashes.

### 4. `reports/index.html` (Analytics Report)
Regenerate project telemetry so new tag and commit counts reflect in the engineering report:
```bash
python3 scripts/generate_report.py
```
Verify output: `Successfully regenerated reports/index.html with fully dynamic metrics!`

---

## 3. Pre-Release Verification Gates

Run all quality checks prior to staging the release commit:

### 1. Code Formatting
```bash
dart format --set-exit-if-changed lib test
```

### 2. Static Analysis
```bash
flutter analyze
```
Must exit with 0 errors and 0 warnings.

> [!NOTE]
> Unit tests and coverage validation are enforced automatically by the Git pre-push hook during `git push`.

### 3. Optional Verification: Screenshot Suite
> [!NOTE]
> **Prompt User First**: Ask the user before running this step (e.g. "Do you want to re-run screenshot automation (`node scripts/capture_screenshots.mjs`) for this release?").
If UI screens, themes, or layouts changed:
```bash
node scripts/capture_screenshots.mjs
```

---

## 4. Optional Build Sanity: Local Release Compilation
> [!NOTE]
> **Prompt User First**: Ask the user before running this step (e.g. "Do you want to verify local release builds (APK/AAB) before tagging?").
Verify release artifacts compile cleanly without tree-shaking or missing symbol errors:

```bash
# Android universal release APK
flutter build apk --release

# Android App Bundle for Google Play Store
flutter build appbundle --release
```

---

## 5. Commit, Tag, and Push Procedure

### Step 1: Stage and Commit
Stage synchronized files:
```bash
git add pubspec.yaml lib/screens/backup_restore_screen.dart CHANGELOG.md reports/index.html
git commit -m "chore(release): bump version to X.Y.Z+B"
```

### Step 2: Create Annotated Git Tag
Create tag matching SemVer version prefixed with `v`:
```bash
git tag -a vX.Y.Z -m "Release vX.Y.Z"
```

### Step 3: Push to Remote
> [!IMPORTANT]
> **Prompt User First**: Confirm with user before pushing (`git push origin main && git push origin vX.Y.Z`), since pushing `v*` tags immediately triggers the GitHub Actions release workflow and Google Play deployment.

Push both main branch and the release tag:
```bash
git push origin main
git push origin vX.Y.Z
```

---

## 6. Automated GitHub Actions Pipeline

Pushing `vX.Y.Z` automatically triggers `.github/workflows/release.yml`:

1. **`build-android`**:
   - Runs unit tests (`flutter test`).
   - Configures upload keystore (if secrets present).
   - Builds split APKs per ABI (`--dart-define=ENABLE_EXTERNAL_DONATIONS=true`).
   - Builds universal release APK.
   - Builds release `.aab` bundle.
   - Renames artifacts to `cashflow-vX.Y.Z-*.apk` / `.aab`.
   - Uploads to workflow artifacts (`build/dist/*`).
2. **`build-ios`**:
   - Builds unsigned iOS release bundle (`Runner.app`).
   - Packages `cashflow-vX.Y.Z-ios-unsigned.ipa` and zip bundle.
3. **`publish-release`**:
   - Creates GitHub Release tagged `vX.Y.Z`.
   - Generates release notes automatically from commit log.
   - Attaches all Android and iOS build artifacts.
4. **`publish-play-store`**:
   - Deploys release AAB to Google Play Store internal track (if `PLAY_SERVICE_ACCOUNT_JSON` secret configured).

---

## 7. Completion Criteria

A release is complete when:
- [ ] `pubspec.yaml` version matches `X.Y.Z+B`.
- [ ] `lib/screens/backup_restore_screen.dart` version string matches `X.Y.Z (Build B)`.
- [ ] `CHANGELOG.md` documents all changes since previous tag.
- [ ] `reports/index.html` regenerated via `python3 scripts/generate_report.py`.
- [ ] Pre-commit fast gates (formatting, analysis, syntax) and pre-push tests pass cleanly.
- [ ] Commit created with message `chore(release): bump version to X.Y.Z+B`.
- [ ] Annotated tag `vX.Y.Z` created.
- [ ] Pushed to `origin main` and `origin vX.Y.Z`.
- [ ] GitHub Actions release workflow completes successfully.
