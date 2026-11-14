# Correctness and Robustness

- **Error Handling** — no silent exceptions. Errors must be meaningful. Fail fast.
- **Edge Cases** — handle null, undefined, empty collections, boundary values, empty strings.
- **Defensive Programming** — validate inputs, use assertions, enforce invariants.
- **Security** — prevent injection, never hardcode secrets, follow least-privilege principle.
- **No Swallowed Exceptions** — `except: pass` and empty catch blocks are forbidden.
- **Exhaustive Branching** — `switch`/`match` must always have a `default`/exhaustive case. `if` used as a guard clause (early return or raise) does not require an `else`. Parallel `if`/`else` branches — when both paths carry distinct behavior — must handle all cases.

---

## Examples

[BAD] Silent failure, missing edge case
```
function divide(a, b):
    try:
        return a / b
    catch any_error:
        pass  // error silently swallowed
```

[GOOD] Meaningful error, handle impossible inputs explicitly
```
function divide(a, b):
    if b == 0:
        raise ValueError("Division by zero is not allowed")
    return a / b
```
