# Naming and Language Idioms

- **English Only** — variables, functions, classes, constants, and types must be named in English.
- **Prefer snake_case** — unless the project or language convention dictates otherwise.
- **Meaningful Names** — `calculate_total` not `calc`, `user_count` not `x`. No abbreviations.
- **Boolean Prefixes** — `is_`, `has_`, `should_`, `can_` for boolean variables and functions.
- **Constants in UPPER_CASE** — `MAX_RETRY_COUNT`, `DEFAULT_TIMEOUT`, `API_BASE_URL`.
- **Language Idioms** — follow the idioms of the language in use:
    - Python: snake_case, list comprehensions, context managers
    - JavaScript/TypeScript: camelCase for variables, PascalCase for classes
    - Rust: snake_case, Result/Option idioms
    - Go: camelCase, interfaces as contracts
    - Java: camelCase, PascalCase for classes
- **No Hungarians** — don't encode types in names (`str_name`, `int_count`).

---

## Examples

[BAD] Cryptic names, Hungarian notation
```
function calc(x, y):
    str_n = "Alice"
    i_t = 5
    return x * y + i_t
```

[GOOD] Meaningful, idiomatic names
```
function calculate_total(price, quantity):
    customer_name = "Alice"
    tax_percent = 5
    return price * quantity + tax_percent
```
