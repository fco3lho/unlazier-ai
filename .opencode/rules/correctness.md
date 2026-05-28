# Correctness and Robustness

- **Error Handling** — no silent exceptions. Errors must be meaningful. Fail fast.
- **Edge Cases** — handle null, undefined, empty collections, boundary values, empty strings.
- **Defensive Programming** — validate inputs, use assertions, enforce invariants.
- **Security** — prevent injection, never hardcode secrets, follow least-privilege principle.
- **No Swallowed Exceptions** — `except: pass` and empty catch blocks are forbidden.
- **Exhaustive Handling** — every if has an else, every switch has a default, every match is exhaustive.

---

## Examples

Bad **Silent failure, missing edge case**
```python
def divide(a, b):
    try:
        return a / b
    except:
        pass
```

Good **Meaningful error, exhaustive cases**
```python
def divide(a, b):
    if b == 0:
        raise ValueError("Division by zero")
    return a / b
```
