# Structure and Organization

- **Clean Code** — follow Clean Code principles: prioritize readability, maintainability, and efficiency over cleverness.
- **Separation of Concerns** — each module, class, and function does one thing.
- **Architectural Boundaries** — clear layers: presentation, domain, infrastructure.
- **Small Functions** — ideally 20–40 lines max, fitting on one screen.
- **Composition over Inheritance** — favor composition; avoid deep inheritance hierarchies.
- **Low Coupling, High Cohesion** — minimize dependencies between modules; keep related behavior together.
- **Single Responsibility** — each unit has one reason to change.
- **Functional First** — favor immutability over mutation. Write pure functions to minimize side effects. Use `map`, `filter`, `reduce` over imperative loops. Prefer declarative over imperative logic.

---

## Examples

[BAD] God function doing everything
```
function process_user(user_id):
    user = db.query("SELECT * FROM users WHERE id = " + user_id)
    total = sum(item.price for item in user.items)
    if total > 100:
        email.send(user.email, "Receipt", "Total: " + total)
    return "<html><body>Hello " + user.name + "</body></html>"
```

[GOOD] Separated responsibilities
```
function get_user(user_id): ...
function calculate_total(items): ...
function send_receipt_email(email, total): ...
function render_greeting(name): ...
```
