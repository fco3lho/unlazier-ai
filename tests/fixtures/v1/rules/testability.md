# Testability

- **Testable Code** — use dependency injection, pure functions, and minimal mocking.
- **Meaningful Coverage** — test behavior, not implementation. Don't mock everything.
- **Simple Tests** — one assertion per test, descriptive names, arrange-act-assert structure.
- **Test-First for Bugs** — reproduce the bug with a failing test before fixing it (see Goal-Driven Execution in AGENTS.md).
- **No Fragile Tests** — avoid overspecification. Tests should not break on innocent refactoring.

---

## Examples

[BAD] Fragile test mocking implementation details
```
function test_calculate():
    mock_db = create_mock()
    mock_db.query.returns([1, 2, 3])
    result = calculate(mock_db)
    assert mock_db.query.was_called_with("SELECT * FROM items")
```

[GOOD] Test focused on behavior
```
function test_calculate_with_items():
    db = InMemoryDatabase(items=[item(1), item(2), item(3)])
    assert calculate(db) == 6
```
