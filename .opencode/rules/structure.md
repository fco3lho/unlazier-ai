# Structure and Organization

- **Separation of Concerns** — each module, class, and function does one thing.
- **Architectural Boundaries** — clear layers: presentation, domain, infrastructure.
- **Small Functions** — ideally 20-40 lines max, fitting on one screen.
- **Composition over Inheritance** — favor composition; avoid deep inheritance hierarchies.
- **Low Coupling, High Cohesion** — minimize dependencies between modules; keep related behavior together.
- **Single Responsibility** — each unit has one reason to change.

---

## Examples

❌ **God function doing everything**
```python
def process_user(user_id):
    user = db.query(f"SELECT * FROM users WHERE id={user_id}")
    total = sum(item.price for item in user.items)
    if total > 100:
        email.send(user.email, "Receipt", f"Total: {total}")
    html = f"<html><body>Hello {user.name}</body></html>"
    return html
```

✅ **Separated responsibilities**
```python
def get_user(user_id): ...
def calculate_total(items): ...
def send_receipt_email(email, total): ...
def render_greeting(name): ...
```
