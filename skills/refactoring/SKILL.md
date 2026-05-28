---
name: refactoring
description: "Use when refactoring, simplifying, or restructuring code. Follows Surgical Changes and Simplicity First: touch only what's needed, avoid scope creep, keep it simple."
---

# Refactoring Workflow

## Before Starting

- Identify the **exact scope** of the refactoring. What specific improvement is asked?
- If the request is vague ("clean this up"), ask for specifics before starting.

## Rules

### Surgical Changes

- Refactor only what was requested. Do not improve adjacent code.
- Match existing style, even if you personally prefer a different one.
- If you discover unrelated dead code, mention it — don't delete it.
- Remove imports/variables/functions YOUR changes made unused. Not pre-existing ones.

### Simplicity First

- Prefer the simplest structure that solves the problem.
- Extract functions only when they are reused or reduce cognitive load.
- Do not introduce abstractions "for future flexibility."
- A 50-line flat function is often better than 5 classes with inheritance.

### Verification

1. Tests pass before and after (run the full suite)
2. Diff shows only the intended lines changed
3. No new TODOs, FIXMEs, or stubs introduced

## After Refactoring

Run `git diff` and check:
- Every changed line traces to the original request?
- No unrelated formatting, style, or comment changes?
