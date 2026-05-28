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

> **Example:** User says "add export". Don't silently assume CSV. Ask: "Export to CSV, JSON, or both? All records or filtered?"

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

> **Example:** User asks for discount calculation. Don't build `AbstractDiscountStrategy` with factory pattern. Write `calculate_discount(amount, percent)`.

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

> **Example:** Fixing an empty-email bug. Bad Don't add type hints, docstrings, or reformat quotes. Good Change only the specific line that fails on empty string.

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

> **Example:** "Fix the sort bug" -> "1) Write test with duplicate scores that shows instability -> verify: test fails. 2) Add stable sort key -> verify: test passes. 3) Run existing suite -> verify: no regressions."

---

## Detailed Rules by Topic

For language-agnostic code quality rules organized by topic, read the relevant file from `rules/` when working on a related task:

- `rules/structure.md` — Structure and Organization
- `rules/correctness.md` — Correctness and Robustness
- `rules/style.md` — Style and Consistency
- `rules/completeness.md` — Completeness
- `rules/performance.md` — Performance
- `rules/testability.md` — Testability
- `rules/async.md` — Async and Concurrency
- `rules/naming.md` — Naming and Language Idioms
