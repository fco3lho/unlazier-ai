# Completeness

- **No Placeholders** — no `// TODO: implement`, `pass`, `throw new NotImplementedException()`, or stub functions.
- **No Agent-Generated Dead Code** — code written during this task must not be dead: no unused imports, unused variables, or unreachable branches introduced by the agent's own changes.
- **Pre-Existing Dead Code** — flag pre-existing dead code to the user; do not remove it without explicit user approval.
- **No Debug Leftovers** — no stray `console.log`, `print()`, `console.debug()`, or debugger statements.
- **Cover All Paths** — every conditional branch is handled. No hidden fall-throughs.
- **Fully Implement Requirements** — no partial solutions or "implement as needed" cop-outs. Deliver what was asked.

---

## Examples

[BAD] Placeholder + debug leftover
```
function calculate_total(items):
    // TODO: implement discount logic
    print("DEBUG: " + items)
    return sum(item.price for item in items)
```

[GOOD] Complete implementation, no leftovers
```
function calculate_total(items):
    return sum(item.price for item in items)
```
