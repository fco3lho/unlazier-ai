# Unlazier AI

Coding agents are powerful but tend to produce lazy, overengineered, or incomplete code. They make silent assumptions, introduce speculative abstractions, touch unrelated lines during edits, and leave placeholders or debug leftovers behind.

This repository provides a set of behavioral principles and code quality rules that make the OpenCode agent produce cleaner, more reliable, and simpler code — every session, every project.

## The Problem

AI coding agents commonly exhibit these behaviors:

- **Silent assumptions** — The agent picks one interpretation and runs with it without checking.
- **Overengineering** — Strategy patterns and abstract factories appear where a single function would do.
- **Scope creep** — Edits touch adjacent code, reformat styles, and "improve" things nobody asked for.
- **Incomplete delivery** — TODOs, debug logs, dead code, and partial implementations left behind.

## The Solution

Four behavioral principles in `AGENTS.md` correct the agent's decision-making process:

| Principle | What it prevents |
|-----------|-----------------|
| **Think Before Coding** | Silent assumptions, missing tradeoffs, unclear requirements |
| **Simplicity First** | Overengineering, speculative abstractions, premature flexibility |
| **Surgical Changes** | Scope creep, style drift, unrelated refactoring |
| **Goal-Driven Execution** | Vague goals, untested changes, incomplete verification |

Eight topic-specific rule files in `rules/` cover code quality dimensions with concrete rules and examples. Three auto-activating skills in `skills/` package the most common workflows (bug fixing, code review, refactoring).

## Repository Structure

```
.
├── AGENTS.md                     # 4 behavioral principles (always loaded)
├── rules/                        # 8 topic-specific code quality rules
│   ├── structure.md              #   Structure and Organization
│   ├── correctness.md            #   Correctness and Robustness
│   ├── style.md                  #   Style and Consistency
│   ├── completeness.md           #   Completeness
│   ├── performance.md            #   Performance
│   ├── testability.md            #   Testability
│   ├── async.md                  #   Async and Concurrency
│   └── naming.md                 #   Naming and Language Idioms
├── skills/                       # 3 auto-activating skills
│   ├── bugfix/                   #   Goal-Driven bug fix workflow
│   ├── code-review/              #   Structured code review checklist
│   └── refactoring/              #   Surgical refactoring workflow
├── opencode.json                 # Project-local config (paths relative to repo)
├── opencode.global.json          # Global config template (tilde paths for home dir)
├── install.sh                    # Install to ~/.config/opencode/
├── uninstall.sh                  # Remove global installation
├── LICENSE                       # MIT License
└── README.md                     # This file
```

## How It Works

OpenCode loads these files at session start:

| File(s) | How they load |
|---------|--------------|
| `AGENTS.md` | Auto-discovered by OpenCode at startup |
| `rules/*.md` | Loaded via `instructions` field in `opencode.json` (glob pattern) |
| `skills/*/` | Auto-activated by the agent when task keywords match their description |

Skills trigger automatically based on context. For example, asking the agent to "fix this bug" activates the `bugfix` skill, which guides through reproduction, fix, and verification.

The `opencode.json` file at the root configures everything:

```json
{
    "instructions": ["AGENTS.md", "rules/*.md"],
    "skills": {
        "paths": ["skills"]
    }
}
```

## Installation

### Global (all projects)

```bash
git clone <this-repo> ~/unlazier-ai
cd ~/unlazier-ai
./install.sh
```

This copies the files to `~/.config/opencode/` — OpenCode's global config directory on Linux. Every subsequent session uses these rules automatically.

To remove:

```bash
./uninstall.sh
```

### Per-project

Copy or symlink the desired files to your project root, or reference them via `instructions` in your project's `opencode.json`.

## The 4 Behavioral Principles

These live in `AGENTS.md` and form the foundation of every interaction:

1. **Think Before Coding** — State assumptions explicitly. Surface tradeoffs. Ask when something is unclear.
2. **Simplicity First** — Minimum code that solves the problem. No speculative abstractions or unused flexibility.
3. **Surgical Changes** — Touch only what you must. Match existing style. Clean up only your own orphans.
4. **Goal-Driven Execution** — Define success criteria. Reproduce bugs with a failing test. Verify.

## The 8 Topic Rules

Each file in `rules/` targets a specific quality dimension:

| Rule | Focus | Example |
|------|-------|--------|
| `structure.md` | SRP, small functions, composition over inheritance | God function vs separated responsibilities |
| `correctness.md` | Error handling, edge cases, security | Silent `except: pass` vs proper validation |
| `style.md` | Indentation, naming conventions, formatter, linter | Inconsistent spacing vs clean formatting |
| `completeness.md` | No TODOs, dead code, debug leftovers | Placeholder with `print()` vs complete implementation |
| `performance.md` | N+1 queries, lazy evaluation, unnecessary allocation | Loop query vs batch query |
| `testability.md` | Dependency injection, behavior testing, no fragile tests | Mocking internals vs testing behavior |
| `async.md` | No fire-and-forget, resource cleanup, cancellation | Unhandled task vs proper await and error handling |
| `naming.md` | Meaningful names, boolean prefixes, language idioms | `calc(x, y)` vs `calculate_total(price, quantity)` |

Every rule file includes a "Bad" and "Good" code example to illustrate the principle in practice.

## The 3 Skills

Skills auto-activate when the task matches their trigger keywords:

- **bugfix** — Guides through: write a failing reproduction test, implement the minimum fix, verify no regressions, cover edge cases.
- **code-review** — Applies all 8 rules as a structured checklist with severity levels (error / warning / suggestion).
- **refactoring** — Defines scope upfront, enforces surgical changes, verifies the diff traces only to the original request.

## Customization

- **Add project rules** — Create more `.md` files in `rules/` or add directly to `AGENTS.md`.
- **Personal overrides** — Install globally, then edit `~/.config/opencode/AGENTS.md`.
- **Override priority** — Project-level `AGENTS.md` overrides global. Last-loaded rule wins.

## License

MIT
