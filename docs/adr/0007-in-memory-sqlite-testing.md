# 7. In-Memory SQLite Database for Automated Testing

## Status
Accepted (Supersedes [ADR-0004](0004-single-concurrency-sqlite-testing.md))

## Context
Previously, automated tests used physical database files, requiring `--concurrency=1` to prevent `SQLITE_BUSY` (OS error 5) locks. As the test suite grew, sequential execution became a pipeline bottleneck.

## Decision
We now utilize `sqflite_common_ffi`'s `inMemoryDatabasePath` injected via a `test/flutter_test_config.dart` setup phase. Since parallel tests run in isolated Dart processes, each file naturally provisions a discrete, in-memory SQLite database instance.

## Consequences
- Total test execution time is dramatically reduced.
- GitHub Actions CI checks execute in parallel.
- Developers can simply run `flutter test` without remembering concurrency limits.
