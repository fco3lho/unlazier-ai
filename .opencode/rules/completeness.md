# Completeness

- **No Placeholders** — no `// TODO: implement`, `pass`, `throw new NotImplementedException()`, or stub functions.
- **No Dead Code** — no commented-out code, unused imports, unused variables, or unreachable branches.
- **No Debug Leftovers** — no stray `console.log`, `print()`, `console.debug()`, or debugger statements.
- **Cover All Paths** — every conditional branch is handled. No hidden fall-throughs.
- **Fully Implement Requirements** — no partial solutions or "implement as needed" cop-outs. Deliver what was asked.

---

## Examples

❌ **Placeholder + debug leftover**
```python
def calculate_total(items):
    # TODO: implement discount logic
    print("DEBUG:", items)
    return sum(item.price for item in items)
```

✅ **Complete implementation, no leftovers**
```python
def calculate_total(items):
    return sum(item.price for item in items)
```
