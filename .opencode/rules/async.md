# Async and Concurrency

- **No Fire-and-Forget** — every promise, future, or async call must be handled (awaited, .then'd, or caught).
- **Race Conditions** — use locks, transactions, and atomic operations where shared state is involved.
- **Resource Cleanup** — always close connections, file handles, streams, and disposables. Use context managers, using blocks, or finally clauses.
- **Cancellation** — support cancellation tokens, AbortController, or equivalent.
- **Async Error Handling** — never ignore rejected promises or unhandled async exceptions.

---

## Examples

❌ **Fire-and-forget, no error handling**
```python
def save(data):
    asyncio.create_task(db.insert(data))
```

✅ **Proper await + error handling**
```python
async def save(data):
    try:
        await db.insert(data)
    except DatabaseError as e:
        logger.error("Failed to save: %s", e)
        raise
```
