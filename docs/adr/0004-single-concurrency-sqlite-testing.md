# 4. Single Concurrency Limit for Automated SQLite Testing

## Status
Accepted

## Context
Automated tests exercise real SQLite databases via `sqflite_common_ffi`. When Flutter test runs parallel worker processes, concurrent access to local test SQLite database files triggers file locking contention (`database is locked`, OS error 5/11).

## Decision
We mandate `--concurrency=1` for all automated test runs:
```bash
flutter test --concurrency=1
```

## Consequences
- Total test execution time is marginally longer (several seconds across the suite), but 100% deterministic and flake-free.
- Developers and CI pipelines must pass `--concurrency=1` to avoid false-positive lock failures.
