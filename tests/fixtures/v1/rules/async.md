# Async and Concurrency

- **No Fire-and-Forget** — every promise, future, or async call must be handled (awaited, .then'd, or caught).
- **Race Conditions** — use locks, transactions, and atomic operations where shared state is involved.
- **Resource Cleanup** — always close connections, file handles, streams, and disposables. Use context managers, using blocks, or finally clauses.
- **Cancellation** — support cancellation tokens, AbortController, or equivalent.
- **Async Error Handling** — never ignore rejected promises or unhandled async exceptions.

---

## Examples

[BAD] Fire-and-forget, no error handling
```
function save(data):
    spawn_task(db.insert(data))  // not awaited, errors silently dropped
```

[GOOD] Proper await + error handling
```
async function save(data):
    try:
        await db.insert(data)
    catch DatabaseError as error:
        log.error("Failed to save: " + error)
        raise
    finally:
        db.close()
```
