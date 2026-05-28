# Style and Consistency

- **Indentation** — always use exactly **4 spaces**.
- **Naming Convention** — prefer **snake_case** unless the language or project standard dictates otherwise (e.g., camelCase in JavaScript/TypeScript).
- **Automatic Formatting** — use the project's formatter (Prettier, ruff, gofmt, etc.). Never fight it.
- **Respect the Linter** — no unnecessary disable comments. Fix the issue, not the warning.
- **Consistency with Existing Code** — match the project's existing patterns. Don't introduce a new style.
- **Imports at Top** — all imports, includes, and requires at the top of the file.
- **English Only** — all code elements, documentation, and comments in English.
- **Professional Tone** — documentation, comments, and docstrings must maintain a professional and sober tone. Avoid informal language.
- **No CAPSLOCK for Emphasis** — never use CAPSLOCK to emphasize text in comments or documentation. Exception: constants and environment variables follow language conventions (e.g., `MAX_RETRIES`, `DATABASE_URL`).

---

## Examples

[BAD] Inconsistent style, fighting the formatter
```
function  calculate(x,y):
    return  x+ y   // inconsistent spacing
```

[GOOD] Consistent, formatter-respecting style
```
function calculate(x, y):
    return x + y
```
