# Cashflow Documentation Hub

This directory contains the stable product, scope, architecture, and delivery references for Cashflow.

## Start Here

- [Project scope](PROJECT_SCOPE.md) — feature inventory and product boundaries.
- [Product specification](PRODUCT_SPECIFICATION.md) — locked behavior, formulas, and product decisions.
- [Implementation roadmap](IMPLEMENTATION_ROADMAP.md) — stable phases, sequencing, and acceptance principles.
- [Schema redesign](architecture/SCHEMA_REDESIGN.md) — database v2 design and migration strategy.

## Live Execution

GitHub is the source of truth for work that changes over time:

- [Issues](https://github.com/vyavahareyash/cashflow/issues) — status, ownership, priorities, milestones, and dependencies.
- [Pull requests](https://github.com/vyavahareyash/cashflow/pulls) — implementation, review, and delivery history.
- [Repository](https://github.com/vyavahareyash/cashflow) — source, releases, and project configuration.

Create roadmap work with the repository's [roadmap issue form](../.github/ISSUE_TEMPLATE/feature.yml). Include scope, acceptance criteria, validation, and related work. Link a pull request to its issue with `Closes #<issue>` or `Fixes #<issue>` only when the issue is fully delivered.

## Document Ownership

- Product behavior belongs in [PRODUCT_SPECIFICATION.md](PRODUCT_SPECIFICATION.md).
- Feature boundaries belong in [PROJECT_SCOPE.md](PROJECT_SCOPE.md).
- Stable delivery sequencing belongs in [IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md).
- Schema decisions belong in [SCHEMA_REDESIGN.md](architecture/SCHEMA_REDESIGN.md).
- Current execution state belongs in GitHub, not duplicated Markdown tables.
