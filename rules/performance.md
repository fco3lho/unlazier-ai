# Performance

- **Algorithmic Complexity** — be mindful of nested loops, N+1 queries, and unnecessary recomputation.
- **Lazy Evaluation** — compute only when needed. Don't eagerly load or compute data that may not be used.
- **No Needless Allocation** — avoid creating intermediate objects, arrays, or copies without reason.
- **Profile before Optimizing** — don't optimize based on intuition. Use metrics.

---

## Examples

[BAD] N+1 query in a loop
```
for each user in users:
    orders = db.query("SELECT * FROM orders WHERE user_id = " + user.id)
```

[GOOD] Batch query
```
user_ids = [user.id for each user in users]
orders = db.query("SELECT * FROM orders WHERE user_id IN (" + join(user_ids) + ")")
```
