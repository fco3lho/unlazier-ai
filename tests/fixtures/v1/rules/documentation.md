# Documentation Standards

- **Focus on Why and How** — comments and docstrings must explain the reasoning and intent behind complex logic, not restate what the code obviously does.
- **Avoid Obvious Comments** — self-explanatory code needs no comment. Comment only when the WHY is non-obvious: a hidden constraint, a workaround for a specific bug, or behavior that would surprise a reader.
- **Execution Instructions** — every project or module must include clear instructions on how to run, build, or test the code. Do not assume the reader knows the toolchain.
- **Concise and Complete** — explanations must be clear and complete without being verbose. One precise sentence beats three vague ones.

---

## Examples

[BAD] Obvious comment that restates the code
```
// Adds 1 to counter
counter = counter + 1
```

[GOOD] Explains the reasoning, not the mechanics
```
// Offset by 1 because the external API uses 1-based pagination
page_number = requested_page + 1
```
