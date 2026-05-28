# Performance

- **Algorithmic Complexity** — be mindful of nested loops, N+1 queries, and unnecessary recomputation.
- **Lazy Evaluation** — compute only when needed. Don't eagerly load or compute data that may not be used.
- **No Needless Allocation** — avoid creating intermediate objects, arrays, or copies without reason.
- **Profile before Optimizing** — don't optimize based on intuition. Use metrics.

---

## Examples

Bad **N+1 query in a loop**
```python
for user in users:
    orders = db.query(f"SELECT * FROM orders WHERE user_id={user.id}")
```

Good **Eager-load in batch**
```python
user_ids = [u.id for u in users]
orders = db.query(f"SELECT * FROM orders WHERE user_id IN ({','.join(user_ids)})")
```
