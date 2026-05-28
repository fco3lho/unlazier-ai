# Style and Consistency

- **Indentation** — always use exactly **4 spaces**.
- **Naming Convention** — prefer **snake_case** unless the language or project standard dictates otherwise (e.g., camelCase in JavaScript/TypeScript).
- **Automatic Formatting** — use the project's formatter (Prettier, ruff, gofmt, etc.). Never fight it.
- **Respect the Linter** — no unnecessary disable comments. Fix the issue, not the warning.
- **Consistency with Existing Code** — match the project's existing patterns. Don't introduce a new style.
- **Imports at Top** — all imports, includes, and requires at the top of the file.
- **English Only** — all code elements, documentation, and comments in English.

---

## Examples

Bad **Inconsistent style, fighting the formatter**
```python
def  calculate(x,y):
    return  x+ y   # espaços inconsistentes
```

Good **Consistent, formatter-respecting style**
```python
def calculate(x, y):
    return x + y
```
