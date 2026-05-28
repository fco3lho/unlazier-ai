# Testability

- **Testable Code** — use dependency injection, pure functions, and minimal mocking.
- **Meaningful Coverage** — test behavior, not implementation. Don't mock everything.
- **Simple Tests** — one assertion per test, descriptive names, arrange-act-assert structure.
- **Test-First for Bugs** — reproduce the bug with a failing test before fixing it (see Goal-Driven Execution in AGENTS.md).
- **No Fragile Tests** — avoid overspecification. Tests should not break on innocent refactoring.

---

## Examples

Bad **Fragile test mocking implementation details**
```python
def test_calculate():
    mock_db = Mock()
    mock_db.query.return_value = [1, 2, 3]
    result = calculate(mock_db)
    assert mock_db.query.called_once_with("SELECT * FROM items")
```

Good **Test focused on behavior**
```python
def test_calculate_with_items():
    db = InMemoryDatabase([1, 2, 3])
    assert calculate(db) == 6
```
