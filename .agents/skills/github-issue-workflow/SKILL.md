---
name: github-issue-workflow
description: Use when implementing a Cashflow GitHub issue, choosing the next issue, updating issue progress, or checking whether work remains aligned with the project docs. Read the roadmap and product specification first, follow dependency order, validate the change, and keep GitHub synchronized with the stable project docs.
---

# Cashflow GitHub Issue Workflow

Work from the repository's documented plan. GitHub issues are the execution queue; the `/docs` folder is the product and architecture source of truth.

## Authority Order

Resolve conflicts in this order:

1. `docs/PRODUCT_SPECIFICATION.md` for locked product decisions.
2. `docs/architecture/SCHEMA_REDESIGN.md` for database shape and migrations.
3. `docs/IMPLEMENTATION_ROADMAP.md` for sprint sequence, scope, and acceptance criteria.
4. The GitHub issue for the current task's concrete acceptance criteria, status, and dependencies.
5. Existing code and tests for current behavior and local conventions.

When implementation reality disagrees with a plan, stop and record the discrepancy in the issue or relevant document before silently changing scope.

## Start Of Work

1. Read the relevant sections of `docs/PRODUCT_SPECIFICATION.md` and `docs/IMPLEMENTATION_ROADMAP.md`.
2. Inspect the GitHub issue, its labels, dependencies, comments, and linked issues.
3. Confirm the issue is the next unblocked task in dependency order. Work on a later issue only when its blockers are complete or explicitly waived.
4. Inspect the owning code path, nearby tests, and repository instructions before editing.
5. State a local hypothesis about the behavior and one focused check that could disconfirm it.

Completion criterion: the issue scope, dependencies, acceptance criteria, and owning code path are all identified before the first substantive edit.

## Implementation Loop

1. Keep the change limited to the issue's scope and acceptance criteria.
2. Preserve existing public APIs and local Flutter/Dart patterns unless the issue requires a contract change.
3. For schema or model work, update the migration, model mapping, CRUD operations, and affected tests together.
4. For UI work, trace the data source through the screen and verify loading, empty, error, and refresh states.
5. Add or update focused tests for changed behavior; use `double.tryParse()` for numeric input and `async`/`await` for database access.
6. After the first substantive edit, run the narrowest relevant validation before reading or changing an adjacent slice.
7. Run broader validation before marking the issue complete: `flutter analyze` and the relevant `flutter test` command.

Completion criterion: the implementation satisfies every acceptance criterion, focused validation passes, and broader validation has no new issue-related failures.

## Progress Tracking

Update progress at each meaningful state change:

- **Not started:** issue is planned but no implementation work has begun.
- **In progress:** implementation or validation is underway; identify the current blocker in a comment.
- **Blocked:** a dependency, product decision, environment problem, or failing prerequisite prevents progress; link the blocker.
- **Ready for review:** acceptance criteria are implemented and validation results are recorded.
- **Done:** reviewed, validated, and all required documentation/status updates are complete.

Keep the GitHub issue current with:

- a short progress comment describing what changed and what remains;
- links to related issues or pull requests;
- test commands and results;
- any decision or scope change that affects the roadmap.

Use the repository owner and name explicitly for GitHub API operations: `owner=vyavahareyash`, `repo=cashflow`.

## Documentation Synchronization

After completing an issue:

1. Update the issue status, labels, acceptance checklist, dependencies, and progress comments on GitHub.
2. Update `docs/IMPLEMENTATION_ROADMAP.md` only when stable scope or sequencing changed.
3. Update architecture or product docs only when a decision or supported behavior changed; preserve locked decisions unless the user explicitly approves a change.
4. Check links and run `git diff --check`.

Completion criterion: GitHub contains the current status and execution history, while the roadmap and other docs contain only stable scope and product decisions.

## Choosing The Next Issue

Use this order:

1. P0 blockers on the critical path.
2. The earliest unblocked issue in `docs/IMPLEMENTATION_ROADMAP.md`.
3. Issues in the current sprint before later sprint work.
4. P1 issues before P2/P3 work when they are equally unblocked.

Before starting, verify the issue is not already implemented under another GitHub number. The planning documents contain historical `NEW-###` identifiers and actual issue numbers; preserve the mapping and avoid duplicate issues.

## Stop Conditions

Stop and ask for direction when:

- acceptance criteria conflict with a locked product decision;
- the task requires a schema change not covered by the migration plan;
- the issue is blocked by an unresolved dependency;
- validation exposes an unrelated pre-existing failure and the issue-specific result is unclear;
- completing the issue would require expanding the scope into a new issue.

Do not mark an issue done merely because code was edited. A task is complete only after behavior, tests, GitHub status, and planning documents agree.
