---
name: update-report
description: Use after shipping app releases or major features to review, calibrate, and regenerate the project analytics report (reports/index.html). Audits qualitative aspects not handled by the automated script—architectural value cards, incident post-mortems, readiness radar calibration, visual marker counts, and methodology synchronization.
---

# Update Report

Workflow for maintaining and updating the **Cashflow Analytics & Engineering Portfolio Report** (`reports/index.html`) after every few releases.

While `scripts/generate_report.py` dynamically extracts raw Git telemetry (commits, tags, LOC, test counts, punchcard heatmap, and COCOMO formulas), **qualitative evaluations, architectural highlights, radar calibrations, and cross-document synchronizations require deliberate review**.

---

## 1. Scope Boundary: Automated vs Manual

| Component | Handled by `scripts/generate_report.py` | Requires Audit in this Skill |
|---|---|---|
| **Git & Release Cadence** | Commit counts, dates, SemVer tag sorting, days/release | Release milestone summaries & tag message quality |
| **Code Footprint** | Dart `lib/`, `test/`, and Markdown line counts, test assertion count | Denominator thresholds in normalization formulas |
| **Punchcard Heatmap** | 7×24 hourly commit matrix, peak 4h window, top sprint day | Interpretive commentary on development rhythms |
| **AI & Capital Economics** | Mathematical token volume, compute spend, capital leverage | Unit cost pricing constants ($3.50/M) & methodology sync |
| **Architectural Value Cards** | Renders HTML template cards | Content of the 6 core innovation cards (must reflect latest ADRs/features) |
| **Engineering Retrospective & Post-Mortems** | Renders HTML incident cards in `.incident-grid` | 4 core incident post-mortems (concurrency locks, SLM grammar, state drift, zero-network distribution) reflect real architectural mitigations |
| **Architect Technical Growth & Gains** | Renders HTML growth cards in `.growth-grid` | 4 capability gain cards (Embedded SQLite, Edge AI runtime, Release CI automation, AI agent orchestration) reflect personal growth |
| **Tab Navigation & Hash Routing** | Renders `.tabs-nav` and manages `#analytics` / `#retrospective` SPA routing | Verify seamless switching, Chart.js resize handling, and deep-link persistence |
| **Production Readiness Radar** | Computes dynamic formulas and renders radar chart | Fixed baseline scores (ACID, SLM, UX) & formula denominators |
| **Visual Testing Metrics** | None | Syncing ADB screenshot marker count with `capture_screenshots.mjs` |

---

## 2. Step-by-Step Audit & Update Procedure

Execute these steps in order when updating the report after a release cluster:

### Step 1: Analyze Recent Architectural Changes & Incidents
Inspect git log and ADRs since the last report review:

```bash
git log $(git describe --tags --abbrev=0 2>/dev/null || echo "HEAD~20")..HEAD --oneline
ls -la docs/adr/
```

- Identify any major new architectural capabilities, critical incidents, or newly mastered engineering competencies.
- Review the 6 cards in `.value-grid` in `scripts/generate_report.py` (Tab 1):
  1. Offline Voice AI Journaling
  2. True 100% Offline-First Privacy
  3. Rigorous Double-Entry Financial Engine
  4. Exhaustive Automated Test Bed
  5. Production Play Store & Multi-Platform CI
  6. Ethical Open-Source Monetization
- **Constraint**: Maintain exactly 6 cards to preserve the balanced 3×2 desktop responsive layout.
- Review the 4 post-mortem cards in `.incident-grid` in `scripts/generate_report.py` (Tab 2):
  1. SQLite Database File Lock Contention (Harness serialization & fixture isolation)
  2. Non-Deterministic Local SLM Hallucination (GBNF grammar decoding & isolate offloading)
  3. Reactive State Drift in Multi-Table Writes (Atomic `DatabaseHelper.dataRevision` monotonic bus)
  4. Zero-Network Privacy vs Heavy Model Distribution (User-initiated SHA-256 verified download manager)
- **Constraint**: Maintain exactly 4 cards to preserve the balanced 2×2 desktop responsive layout. Ensure each card contains Trigger, Failure Mode, Remedy, and Key Engineering Takeaway.
- Review the 4 capability gain cards in `.growth-grid` in `scripts/generate_report.py` (Tab 2):
  1. Embedded Systems & ACID Mechanics (WAL mode, lock states, single-writer invariants)
  2. Edge AI Runtime & Constrained Decoding (whisper/llama FFI, isolates, formal GBNF grammars)
  3. Production Release & Test Rig Automation (SemVer CI, signed AABs, headless adb visual test harness)
  4. Solo Architectural Leverage via AI Pairing (spec-driven development, automated harness guardrails)
- **Constraint**: Maintain exactly 4 cards to preserve the balanced 2×2 desktop responsive layout. Ensure each card contains Domain, Core Shift, and Direct Practical Gain callout.

### Step 2: Calibrate Readiness Radar Denominators
Inspect `scripts/generate_report.py` around line 160:

```python
radar_scores = [
    98,  # ACID & Data Integrity (Fixed: review schema migrations & journal integrity)
    min(99, int(82 + (test_cases / 350.0) * 15)),      # Automated Testing (Denominator: 350)
    94,  # Edge AI & Local SLM (Fixed: review isolate & grammar speed)
    min(99, int(82 + (len(releases) / 20.0) * 14)),     # CI/CD & Releases (Denominator: 20)
    min(99, int(85 + (lib_lines / 30000.0) * 13)),      # Clean Architecture (Denominator: 30,000)
    95   # Product & UX Design (Fixed: review 60fps, haptics, theme consistency)
]
```

- If `test_cases` approaches or exceeds 350, increase the denominator (e.g., 400 or 500) so the score scales smoothly and does not peg at 99 prematurely.
- If `len(releases)` approaches 20, increase denominator (e.g., 25 or 30).
- If `lib_lines` approaches 30,000, scale the denominator accordingly.
- Reflect any formula adjustments in `docs/engineering/METRICS_METHODOLOGY.md` table in Section 6.

### Step 3: Synchronize Visual Testing Marker Counts
Check current count of automated visual screenshot markers in `scripts/capture_screenshots.mjs`:

```bash
node -e "import('./scripts/capture_screenshots.mjs').then(m => console.log('Markers:', m.PAIRS ? m.PAIRS.length : 'check script'))" 2>/dev/null || grep -c "_markScreen" integration_test/screenshots_test.dart
```

- If new screenshots or markers were added, update the marker count reference in:
  1. `scripts/generate_report.py` (Value card 4: "Over X automated unit, widget, and visual integration tests with sequential SQLite locking guardrails and Y visual screenshot markers...")
  2. `docs/engineering/METRICS_METHODOLOGY.md` (Section 6 table and text)

### Step 4: Validate Methodology & MathJax Syntax
Inspect `docs/engineering/METRICS_METHODOLOGY.md`:
- Ensure all displayed numbers (commits, KLOC, test cases, AI token volume) match the newly generated report values.
- Verify GitHub Markdown math compatibility:
  - **No raw dollar signs in prose**: Use `USD` (e.g., `3.50 USD / Million Tokens`, not `$3.50`).
  - **No raw currency inside math**: Use `71.05\text{ USD}`, never `\text{$}` or `\text{\$}`.
  - **No text-mode underscores**: Use `\text{Production LOC}`, not `\text{lib_lines}`.
  - **Generous vertical spacing**: Ensure every `$$...$$` block is unindented and bounded by blank lines before and after.

### Step 5: Regenerate Report
Run the report generator to compile the live HTML:

```bash
python3 scripts/generate_report.py
```

Verify console output: `Successfully regenerated reports/index.html with fully dynamic metrics!`

### Step 6: Verify Layout & Quality Gates
1. Open or inspect `reports/index.html`:
   - Top KPI cards render in a balanced 3×2 grid across all tabs.
   - Tab navigation switches seamlessly between `[ 📊 System Architecture & Metrics ]` and `[ 🛡️ Engineering Retrospective & Learnings ]` without page reload.
   - Deep-linking via URL hash (`#retrospective`) directly activates Tab 2 on initial load.
   - Returning to Tab 1 (`#analytics`) triggers Chart.js resize smoothly without canvas distortion.
   - Architectural value addition cards render in a balanced 3×2 grid in Tab 1.
   - Incident post-mortem cards render in a balanced 2×2 grid in Tab 2.
   - Architect capability gain cards render in a balanced 2×2 grid in Tab 2.
   - Milestone timeline is constrained to scrollable container (`max-height: 440px`).
   - Radar chart and Punchcard heatmap render without JS errors.
   - Commit Explorer filter pills (Features, Bug Fixes, CI/CD, Docs) work.
2. Check `README.md` callout:
   - Ensure the callout highlights current metrics and links to both GitHub Pages and `METRICS_METHODOLOGY.md`.

---

## 3. Completion Criteria

A report update is complete when:
- [ ] `scripts/generate_report.py` executed with exit code 0.
- [ ] Architectural cards (Tab 1) reflect the latest shipped capabilities.
- [ ] Incident post-mortems (Tab 2) reflect real failure modes and latest architectural mitigations.
- [ ] Architect capability gains (Tab 2) reflect actual engineering growth and practical application.
- [ ] Tab switching and bidirectional hash synchronization (`#analytics` / `#retrospective`) operate without errors.
- [ ] Radar denominators scale proportionally with codebase growth.
- [ ] Screenshot marker count matches `integration_test/screenshots_test.dart`.
- [ ] `docs/engineering/METRICS_METHODOLOGY.md` formulas and numbers match `reports/index.html`.
- [ ] Zero KaTeX/MathJax syntax errors on GitHub Markdown preview.
- [ ] Working tree is committed and pushed to `main` (triggering GitHub Pages deploy).
