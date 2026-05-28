---
name: code-review
description: "Use when reviewing code for quality, best practices, bugs, or adherence to coding standards. Checks against Simplicity First, Completeness, Structure, Style, Correctness, Naming, Performance, Testability, and Async rules."
---

# Code Review

Apply this structured review to every file changed in the diff or opened for review.

## 1. Simplicity Check (`rules/structure.md`)

- Each function does one thing? (SRP)
- No unnecessary abstractions? (no Strategy pattern for one-line math)
- Fits on one screen? (< 40 lines per function)

## 2. Completeness Check (`rules/completeness.md`)

- Any `// TODO`, `FIXME`, `XXX`, `pass`, `NotImplementedError`?
- Any `console.log`, `print()`, `debugger` statements?
- Any unused imports or variables introduced by these changes?
- Any commented-out code or unreachable branches introduced by these changes?
- Any pre-existing dead code that should be flagged to the user?
- Every `switch`/`match` has a `default`/exhaustive case?
- Parallel `if`/`else` branches (non-guard-clauses) handle all paths?

## 3. Correctness Check (`rules/correctness.md`)

- All error paths handled? (no `except: pass`, no empty catch)
- Edge cases covered? (null, empty, zero, boundary values)
- Inputs validated?
- Security risks? (injection, hardcoded secrets)

## 4. Style Check (`rules/style.md`)

- Matches existing project style?
- Formatter would pass? (Prettier, ruff, gofmt, etc.)
- Imports at top?

## 5. Naming Check (`rules/naming.md`)

- Names meaningful and in English? (`calculate_total` not `calc`)
- Boolean prefixes? (`is_`, `has_`, `should_`)
- Language-idiomatic? (snake_case for Python, camelCase for JS)

## 6. Performance Check (`rules/performance.md`)

- N+1 queries in loops?
- Unnecessary allocation inside loops?
- Eager loading when lazy would do?

## 7. Testability Check (`rules/testability.md`)

- Logic testable without excessive mocking?
- Side effects isolated?

## 8. Async Check (`rules/async.md`)

- Every promise/async handled? No fire-and-forget?
- Resources cleaned up? (connections, handles, streams)
