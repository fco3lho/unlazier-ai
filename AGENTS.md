# Global Agent Rules

This document defines the mandatory standards for all code generation, refactoring, and documentation tasks. These rules exist to eliminate lazy coding, overengineering, silent assumptions, and incomplete work.

**Tradeoff:** These rules bias toward caution over speed. For trivial tasks (typo fixes, obvious one-liners), use judgment.

---

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

---

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No flexibility or configurability that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

**Good code solves today's problem simply, not tomorrow's problem prematurely.**

---

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't improve adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:
- Remove imports, variables, and functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

---

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" -> "Write tests for invalid inputs, then make them pass"
- "Fix the bug" -> "Write a test that reproduces it, then make it pass"
- "Refactor X" -> "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] -> verify: [check]
2. [Step] -> verify: [check]
3. [Step] -> verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

## 5. Structure and Organization

- **Separation of Concerns** — each module, class, and function does one thing.
- **Architectural Boundaries** — clear layers: presentation, domain, infrastructure.
- **Small Functions** — ideally 20-40 lines max, fitting on one screen.
- **Composition over Inheritance** — favor composition; avoid deep inheritance hierarchies.
- **Low Coupling, High Cohesion** — minimize dependencies between modules; keep related behavior together.
- **Single Responsibility** — each unit has one reason to change.

---

## 6. Correctness and Robustness

- **Error Handling** — no silent exceptions. Errors must be meaningful. Fail fast.
- **Edge Cases** — handle null, undefined, empty collections, boundary values, empty strings.
- **Defensive Programming** — validate inputs, use assertions, enforce invariants.
- **Security** — prevent injection, never hardcode secrets, follow least-privilege principle.
- **No Swallowed Exceptions** — `except: pass` and empty catch blocks are forbidden.
- **Exhaustive Handling** — every if has an else, every switch has a default, every match is exhaustive.

---

## 7. Style and Consistency

- **Indentation** — always use exactly **4 spaces**.
- **Naming Convention** — prefer **snake_case** unless the language or project standard dictates otherwise (e.g., camelCase in JavaScript/TypeScript).
- **Automatic Formatting** — use the project's formatter (Prettier, ruff, gofmt, etc.). Never fight it.
- **Respect the Linter** — no unnecessary disable comments. Fix the issue, not the warning.
- **Consistency with Existing Code** — match the project's existing patterns. Don't introduce a new style.
- **Imports at Top** — all imports, includes, and requires at the top of the file.
- **English Only** — all code elements, documentation, and comments in English.

---

## 8. Completeness

- **No Placeholders** — no `// TODO: implement`, `pass`, `throw new NotImplementedException()`, or stub functions.
- **No Dead Code** — no commented-out code, unused imports, unused variables, or unreachable branches.
- **No Debug Leftovers** — no stray `console.log`, `print()`, `console.debug()`, or debugger statements.
- **Cover All Paths** — every conditional branch is handled. No hidden fall-throughs.
- **Fully Implement Requirements** — no partial solutions or "implement as needed" cop-outs. Deliver what was asked.

---

## 9. Performance

- **Algorithmic Complexity** — be mindful of nested loops, N+1 queries, and unnecessary recomputation.
- **Lazy Evaluation** — compute only when needed. Don't eagerly load or compute data that may not be used.
- **No Needless Allocation** — avoid creating intermediate objects, arrays, or copies without reason.
- **Profile before Optimizing** — don't optimize based on intuition. Use metrics.

---

## 10. Testability

- **Testable Code** — use dependency injection, pure functions, and minimal mocking.
- **Meaningful Coverage** — test behavior, not implementation. Don't mock everything.
- **Simple Tests** — one assertion per test, descriptive names, arrange-act-assert structure.
- **Test-First for Bugs** — reproduce the bug with a failing test before fixing it (see section 4).
- **No Fragile Tests** — avoid overspecification. Tests should not break on innocent refactoring.

---

## 11. Async and Concurrency

- **No Fire-and-Forget** — every promise, future, or async call must be handled (awaited, .then'd, or caught).
- **Race Conditions** — use locks, transactions, and atomic operations where shared state is involved.
- **Resource Cleanup** — always close connections, file handles, streams, and disposables. Use context managers, using blocks, or finally clauses.
- **Cancellation** — support cancellation tokens, AbortController, or equivalent.
- **Async Error Handling** — never ignore rejected promises or unhandled async exceptions.

---

## 12. Naming and Language Idioms

- **English Only** — variables, functions, classes, constants, and types must be named in English.
- **Prefer snake_case** — unless the project or language convention dictates otherwise.
- **Meaningful Names** — `calculate_total` not `calc`, `user_count` not `x`. No abbreviations.
- **Boolean Prefixes** — `is_`, `has_`, `should_`, `can_` for boolean variables and functions.
- **Constants in UPPER_CASE** — `MAX_RETRY_COUNT`, `DEFAULT_TIMEOUT`, `API_BASE_URL`.
- **Language Idioms** — follow the idioms of the language in use:
    - Python: snake_case, list comprehensions, context managers
    - JavaScript/TypeScript: camelCase for variables, PascalCase for classes
    - Rust: snake_case, Result/Option idioms
    - Go: camelCase, interfaces as contracts
    - Java: camelCase, PascalCase for classes
- **No Hungarians** — don't encode types in names (`str_name`, `int_count`).
