<p align="center">
  <img src="docs/images/sloth.png" alt="Sloth" width="250">
</p>

# <p align="center">Unlazier AI</p>

<p align="center">
  <b>English</b> | <a href="README.pt-BR.md">Português (Brasil)</a> | <a href="README.es.md">Español</a>
</p>

AI coding assistants are powerful, but they often cut corners. They guess what you meant instead of asking, write more code than needed, change things you did not ask them to touch, and leave unfinished work behind.

Unlazier AI is a set of rules that makes these assistants work more carefully. You install it once, and every AI coding tool you use follows the same rules in every project.

## Table of Contents

- [What You Get](#what-you-get)
- [Supported Tools](#supported-tools)
- [Install](#install)
- [What Changes on Your Computer](#what-changes-on-your-computer)
- [Usage Limits and Parallel Work](#usage-limits-and-parallel-work)
- [Uninstall](#uninstall)
- [Upgrading from Version 1](#upgrading-from-version-1)
- [Notes for Each Tool](#notes-for-each-tool)
- [The Rules](#the-rules)
- [Customization](#customization)
- [For Contributors](#for-contributors)
- [License](#license)

## What You Get

Unlazier AI adds three layers to each tool. Every tool gets the same three layers; only the place where the tool keeps its settings is different.

| Layer | What it does | Why it matters |
|-------|--------------|----------------|
| **1. Rules** | Adds the rules to the tool's rules folder, one small file per rule, or to its global instructions file when the tool has no rules folder. The assistant reads them at the start of every session. | The assistant knows what is expected from the first message. |
| **2. Reminder** | Sends a short summary of the rules again with each of your messages, and the core principles again after the conversation is compacted. | In long sessions, instructions from the start lose weight as the conversation grows. The reminder keeps them fresh. |
| **3. Usage** | Adds a line to the reminder saying how much of your 5-hour and weekly usage limits is used. | The assistant can run tasks in parallel when there is room, and slow down before you hit a limit. |

## Supported Tools

| Tool | 1. Rules | 2. Reminder | 3. Usage |
|------|:--------:|:-----------:|:--------:|
| Claude Code | Yes | Yes | Yes, through the status line |
| Codex CLI | Yes | Yes (needs one approval, see [notes](#codex-cli)) | Yes, read from Codex's own session log |
| Gemini CLI | Yes | Yes | Not available |
| Devin Desktop (formerly Windsurf) | Yes | Yes | Not available |
| Kiro | Yes | Yes | Not available |
| Cline | Yes | Yes on Linux and macOS (needs a setting, see [notes](#cline)) | Not available |
| OpenCode | Yes | Yes | Not available |
| Amp | Yes | Yes | Not available |
| GitHub Copilot CLI | Yes | Not available | Not available |

"Not available" always means the tool itself offers no way to do it: Copilot CLI ignores what a prompt hook prints, and only Claude Code and Codex expose usage limits in a form a program can read. Cursor is not supported because it keeps its global rules in its own settings, not in a file.

## Install

### Linux and macOS

Open a terminal and run:

```bash
curl -fsSL https://raw.githubusercontent.com/fco3lho/unlazier-ai/main/install.sh | bash
```

The reminder and usage layers need **jq**, a small JSON tool. If it is missing, the installer still installs the rules and tells you the exact command to install jq for your system (for example `brew install jq` on macOS or `sudo apt-get install -y jq` on Ubuntu). Install it and run the installer again.

### Windows

Open **PowerShell** and run:

```powershell
irm https://raw.githubusercontent.com/fco3lho/unlazier-ai/main/install.ps1 | iex
```

Nothing else is needed on Windows.

### Choosing your tools

The installer shows a numbered list of all supported tools and marks with `*` the ones it found on your computer:

```
Choose the tools to install Unlazier AI for (* = found on this computer):
  1) * Claude Code
  2)   OpenCode
  3) * Codex CLI
  ...
Type numbers separated by spaces, "all", or press Enter for the tools marked with *:
```

Press **Enter** to install for the tools marked with `*`, or type the numbers you want (for example `1 3`).

### Without the menu

To pick tools in the command itself, which is useful for scripts:

```bash
# Linux and macOS, from a downloaded copy of this repository
./install.sh --harness claude,codex

# Linux and macOS, without downloading
curl -fsSL https://raw.githubusercontent.com/fco3lho/unlazier-ai/main/install.sh | bash -s -- --harness claude,codex
```

```powershell
# Windows
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/fco3lho/unlazier-ai/main/install.ps1))) -Harness claude,codex
```

Tool names: `claude`, `opencode`, `codex`, `copilot`, `gemini`, `amp`, `kiro`, `cline`, `devin`, or `all`. Add `--yes` (Windows: `-Yes`) to answer "yes" to questions automatically.

After installing, **restart your tools** so they load the changes.

## What Changes on Your Computer

The installer never replaces your own settings and never creates backup copies.

- **Your files stay yours.** Tools that read a rules folder (Claude Code, Devin, Kiro, Cline) get their own files there, all named `unlazier-ai-*.md`, and your instructions file is not touched. The other tools read a single instructions file, so the rules go inside a marked block that starts with `<!-- unlazier-ai:start -->` and ends with `<!-- unlazier-ai:end -->`; anything you wrote outside that block is never touched. Installing again only updates these files and blocks.
- **Settings files are added to, not replaced.** Hooks are added next to the ones you already have. A settings file that cannot be read safely (for example, one with comments) is left unchanged, and the installer tells you.
- **Everything else lives in one folder per tool**, called `unlazier-ai`, next to the tool's own settings.

On Windows, `~` means your user folder (`C:\Users\<you>`).

| Tool | Rules | Reminder | Folder |
|------|-------|----------|--------|
| Claude Code | `~/.claude/rules/unlazier-ai-*.md` | hooks in `~/.claude/settings.json`; status line if you have none | `~/.claude/unlazier-ai/` |
| Codex CLI | `~/.codex/AGENTS.md` | `~/.codex/hooks.json` | `~/.codex/unlazier-ai/` |
| Gemini CLI | `~/.gemini/GEMINI.md` | hook in `~/.gemini/settings.json` | `~/.gemini/unlazier-ai/` |
| Devin Desktop | `~/.devin/rules/unlazier-ai-*.md` | hook in `~/.config/devin/config.json` (Windows: `%APPDATA%\devin\config.json`) | `~/.devin/unlazier-ai/` |
| Kiro | `~/.kiro/steering/unlazier-ai-*.md` | `~/.kiro/hooks/unlazier-ai.json` | `~/.kiro/unlazier-ai/` |
| Cline | `~/Documents/Cline/Rules/unlazier-ai-*.md` | `~/Documents/Cline/Hooks/UserPromptSubmit` | `~/Documents/Cline/unlazier-ai/` |
| OpenCode | `~/.config/opencode/AGENTS.md` | `~/.config/opencode/plugins/unlazier-ai.ts` | `~/.config/opencode/unlazier-ai/` |
| Amp | `~/.config/amp/AGENTS.md` | `~/.config/amp/plugins/unlazier-ai.ts` | `~/.config/amp/unlazier-ai/` |
| GitHub Copilot CLI | `~/.copilot/copilot-instructions.md` | none | `~/.copilot/unlazier-ai/` |

If you moved a tool's settings with its own environment variable (`CLAUDE_CONFIG_DIR`, `CODEX_HOME`, `COPILOT_HOME`, `GEMINI_CLI_HOME`, `KIRO_HOME`), the installer uses that location.

## Usage Limits and Parallel Work

Subscriptions such as Claude and ChatGPT limit how much you can use in a 5-hour window and in a week. Unlazier AI tells the assistant how to pace itself:

| 5-hour window | What the assistant does |
|---------------|-------------------------|
| below 70% | Runs as much work in parallel as it can |
| 70% to 85% | Runs at most 2 tasks at a time |
| 85% to 95% | Works on one task at a time, without helper agents |
| 95% or more | Finishes the current step, tells you, and waits |

When the **weekly** window reaches 99%, the assistant finishes the current step, tells you, and waits.

When it parallelizes, it prefers, in this order: helper agents for parts of the same task, then different tasks of the same request, then different requests.

**Where the numbers come from:**

- **Claude Code** sends usage only to the status line (the bar at the bottom of the screen). If you have no status line, the installer adds one that shows both windows and saves them for the reminder. If you already have your own, it is kept. To feed the reminder, make your status line save the `rate_limits` part of what Claude Code sends it to `~/.claude/state/rate_limits.json`, in this form:

    ```json
    {"captured_at": 1794668291, "five_hour": {"used_percentage": 24, "resets_at": 1794683400}, "seven_day": {"used_percentage": 60, "resets_at": 1794978000}}
    ```

    `captured_at` is the current time in seconds. Usage data is available only on Claude subscription plans, not with an API key.
- **Codex CLI** writes usage into its own session log, which the reminder reads. Nothing to set up.
- **Other tools** do not expose usage, so the reminder says `Usage: unknown`. The assistant then runs at most 2 to 3 tasks at a time and asks you before running more than 5.

A reading older than 15 minutes counts as unknown.

## Uninstall

Linux and macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/fco3lho/unlazier-ai/main/uninstall.sh | bash
```

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/fco3lho/unlazier-ai/main/uninstall.ps1 | iex
```

The uninstaller shows the same menu and removes only what Unlazier AI added: the `unlazier-ai-*.md` rule files, the marked blocks, its hooks, its plugins, its status line (only if it is the one Unlazier AI installed), and the `unlazier-ai` folders. A file that becomes empty after the block is removed is deleted. Your own settings, history, and credentials stay.

## Upgrading from Version 1

Version 1 copied its files over your configuration in `~/.claude` and `~/.config/opencode`. When you install version 2, the installer looks for those old files, lists them, and asks before removing them. Old rule and skill files are offered for removal only if they are exactly as version 1 left them; a file you edited is kept.

The old `~/.claude/CLAUDE.md` (or `~/.config/opencode/AGENTS.md`) is recognized by its first line, `# Global Agent Rules`. If you added your own notes to it after installing version 1, answer **no** and move your notes out first: version 1 replaced that whole file, so the installer cannot tell your notes apart from the old rules.

> **Do not run the version 1 uninstaller.** It deleted the entire `~/.claude` and `~/.config/opencode` folders, including your settings and credentials. The version 2 uninstaller removes only what Unlazier AI added.

## Notes for Each Tool

### Claude Code

The rules go to `~/.claude/rules/` rather than `~/.claude/CLAUDE.md`: Anthropic recommends keeping each CLAUDE.md under 200 lines, and each rule file counts as a separate, short file. Rules in that folder load at the start of every session, like CLAUDE.md. Version 2.0 put the rules in a block inside CLAUDE.md; installing again moves them and removes that block.

Claude Code asks you to trust a folder before running hooks in it; the reminder starts working after you accept. Usage data needs a Claude subscription and a status line (see [Usage Limits](#usage-limits-and-parallel-work)).

### Codex CLI

Codex runs a new hook only after you approve it. Open Codex, type `/hooks`, and approve the two Unlazier AI hooks once. If a file named `AGENTS.override.md` exists in `~/.codex`, Codex ignores `AGENTS.md`, and the installer warns you. Codex reads at most 32 KiB of instructions in total by default; the Unlazier AI rules use about 18 KiB, so very long project instructions may be cut. You can raise the limit with `project_doc_max_bytes` in `~/.codex/config.toml`.

### Gemini CLI

Gemini sends its instructions file again with every message, so it needs no extra step after compaction. Google replaced Gemini CLI with Antigravity CLI for free and Google One users on June 18, 2026; Antigravity CLI is not supported yet.

### Devin Desktop (formerly Windsurf)

Devin limits each rules file to 12,000 characters; every Unlazier AI rule file is far below that. Devin also runs the hooks it finds in `~/.claude/settings.json`; turning that off would also turn off your Claude Code rules inside Devin, so Unlazier AI leaves it as is. Devin documents no way to add text after compaction, so only the per-message reminder is used.

### Kiro

The reminder after compaction needs Kiro CLI 3.1.0 or later.

### Cline

Hooks are off by default. Turn on **Enable Hooks** in Cline's Feature Settings. Cline supports hooks only on Linux and macOS, so on Windows Cline gets the rules without the reminder.

### OpenCode

The plugin works with OpenCode 1.18.29 or later, including version 2. OpenCode reloads its instruction files after compaction on its own. Once `~/.config/opencode/AGENTS.md` exists, OpenCode stops reading `~/.claude/CLAUDE.md` as a fallback; the installer warns you when this applies.

### Amp

The plugin loads in new threads. In a running thread, reload plugins with `Ctrl+O`, then `plugins: reload`.

### GitHub Copilot CLI

Copilot ignores what a prompt hook prints, so it gets the rules without the reminder. The VS Code Copilot extension can also read `~/.claude/CLAUDE.md` when its `chat.useClaudeMdFile` setting is on, which would load the rules twice if you use both.

## The Rules

The principles in [`AGENTS.md`](AGENTS.md) shape how the assistant works:

1. **Think Before Coding**: state assumptions, ask when something is unclear (one question at a time, with a recommended answer).
2. **Simplicity First**: the smallest change that solves the problem, without speculative abstractions.
3. **Surgical Changes**: touch only what the request needs and match the existing style.
4. **Goal-Driven Execution**: define how success is checked, and verify before reporting done.
5. **Commit Messages**: follow the Conventional Commits format.
6. **Communication Brevity**: short, direct answers without filler.

> **Attribution:** The first four principles come from [Andrej Karpathy's observations](https://x.com/karpathy/status/2015883857489522876) on LLM coding pitfalls, popularized by the [andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) repository.

The topic rules in [`rules/`](rules/) add detail, each with a bad and a good example:

| Rule | Focus |
|------|-------|
| [`structure.md`](rules/structure.md) | Readable code, one job per function, small functions |
| [`correctness.md`](rules/correctness.md) | Error handling, edge cases, security |
| [`style.md`](rules/style.md) | Formatting, consistency, professional tone |
| [`completeness.md`](rules/completeness.md) | No placeholders, dead code, or debug leftovers |
| [`performance.md`](rules/performance.md) | Avoiding wasteful queries and computation |
| [`testability.md`](rules/testability.md) | Code that is easy to test, tests that check behavior |
| [`async.md`](rules/async.md) | Handling asynchronous work and cleanup |
| [`naming.md`](rules/naming.md) | Clear names that follow each language's conventions |
| [`documentation.md`](rules/documentation.md) | Comments that explain why, plus run instructions |
| [`parallelism.md`](rules/parallelism.md) | Pacing parallel work by usage limits |

The reminder that is sent with every message is in [`reminder.md`](reminder.md).

## Customization

- **Your own global rules:** write them in your tool's instructions file (for example `~/.claude/CLAUDE.md`), outside any Unlazier AI block, or in your own files in the rules folder with names that do not start with `unlazier-ai`. They survive updates and uninstalls.
- **Changing the Unlazier AI rules:** edit the files in a copy of this repository and run `./install.sh` (or `.\install.ps1`) from that copy. Edits made directly to the installed `unlazier-ai-*.md` files or inside the installed block are replaced on the next install.
- **Project rules:** each tool also reads instructions from your project folder (for example `AGENTS.md` or `CLAUDE.md`); those apply on top of the global rules.

## For Contributors

Repository layout:

| Path | Purpose |
|------|---------|
| `AGENTS.md`, `rules/` | The rules (layer 1). `CLAUDE.md` links to `AGENTS.md`. |
| `reminder.md` | The short reminder (layer 2). |
| `hooks/inject.sh`, `hooks/inject.ps1` | Prints the reminder and the usage line (layers 2 and 3) in the format each tool expects. |
| `statusline/` | Claude Code status line that saves usage for the reminder. |
| `plugins/` | OpenCode and Amp plugins, which call the same hook script. |
| `install.sh`, `install.ps1` | Installers; each tool is an adapter in one table. `uninstall.*` call them in uninstall mode. |
| `tests/` | Installer and hook tests; `tests/fixtures/v1/` holds version 1 files for the upgrade tests. |

Run the tests:

```bash
bash tests/install_test.sh        # Linux and macOS, needs jq
```

```powershell
./tests/install_test.ps1          # Windows PowerShell 5.1 or PowerShell 7
```

The tests use a temporary home folder and never touch your real configuration. GitHub Actions runs them on Ubuntu, macOS, and Windows, plus `shellcheck` on the shell scripts.

This README is the official version. [`README.pt-BR.md`](README.pt-BR.md) and [`README.es.md`](README.es.md) are translations of it; when you change this file, update them in the same change.

## License

MIT
