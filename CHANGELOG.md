# Changelog

All notable changes to Unlazier (called Unlazier AI before version 2.1) are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [2.1.0] - 2026-11-14

### Added

- **Alerts layer:** three short beeps when the assistant asks for permission, asks a question, or finishes its turn, through each tool's own events. Kiro and Amp signal only the end of a turn, and Cline signals no permission prompts.

### Changed

- **Renamed from Unlazier AI to Unlazier.** Files, folders, and markers use `unlazier` instead of `unlazier-ai`, and the repository moves to `fco3lho/unlazier`. Installing again removes everything version 2.0 wrote under the old name.
- **Rules go into the tool's rules folder, one small file per rule**, for tools that always load such a folder: Claude Code (`~/.claude/rules/`), Devin, Kiro, and Cline. Anthropic recommends keeping each CLAUDE.md under 200 lines, and version 2.0 added about 480 lines to it. Your `CLAUDE.md` is no longer touched. Tools that read a single instructions file (Codex CLI, OpenCode, Copilot CLI, Gemini CLI, Amp) keep the marked block.
- **Upgrading from 2.0 is automatic:** installing again removes the block from `CLAUDE.md` and the old rule files in the Kiro, Cline, and Devin folders, then writes the new files.
- The Claude Code status line shows reset times longer than a day in days, for example `3d 11h 30m`.

### Fixed

- The Claude Code status line script is copied only when Unlazier actually installs the status line, instead of on every install.

## [2.0.0] - 2026-11-14

Version 2 changes how Unlazier AI is installed. If you have version 1, read [Upgrading from Version 1](README.md#upgrading-from-version-1) before installing, and **do not run the version 1 uninstaller**.

### Added

- **Seven more tools:** Codex CLI, GitHub Copilot CLI, Gemini CLI, Amp, Kiro, Cline, and Devin Desktop (formerly Windsurf), in addition to Claude Code and OpenCode.
- **Windows support:** native PowerShell installer and uninstaller (`install.ps1`, `uninstall.ps1`), with nothing extra to install.
- **Choose your tools:** the installer shows a menu, marks the tools it finds on your computer, and installs only where you choose. `--harness` (Windows: `-Harness`) picks tools without the menu.
- **Reminder layer:** a short summary of the rules (`reminder.md`) is sent again with each message, and the core principles again after the conversation is compacted, so the rules keep their weight in long sessions. It works through each tool's own hooks or plugins.
- **Usage layer:** the reminder includes how much of the 5-hour and weekly usage windows is used (Claude Code through its status line, Codex through its session log), so the assistant can pace itself.
- **New rule, Agent Parallelism (`rules/parallelism.md`):** how much work to run in parallel, based on the usage windows, and in which order to parallelize.
- **Claude Code status line** that shows both usage windows and saves them for the reminder; installed only when you have no status line of your own.
- **Version 1 cleanup:** the installer finds files left by version 1, lists them, and asks before removing them.
- **Tests and continuous integration** for the installers and the hook, on Ubuntu, macOS, and Windows.
- This changelog.

### Changed

- **The installer adds to your configuration instead of replacing it.** The rules go inside a marked block (`<!-- unlazier-ai:start -->` to `<!-- unlazier-ai:end -->`) in each tool's instructions file; your own content in that file is kept. Hooks are added next to yours in settings files.
- **No more backup folders.** Version 1 copied the whole configuration folder to `*.bak.<date>` on every install.
- The principles no longer list rule file paths, because the topic rules are now always installed together with them.
- The **README** was rewritten in plain language, with a table of every file the installer touches.

### Removed

- The `bugfix`, `code-review`, and `refactoring` skills.
- `opencode.global.json`: OpenCode now gets its rules from `~/.config/opencode/AGENTS.md`, so your `opencode.json` is no longer replaced.

### Fixed

- **The uninstaller no longer deletes your whole configuration.** Version 1 ran `rm -rf ~/.claude` and `rm -rf ~/.config/opencode`, which also deleted settings, history, and credentials. Version 2 removes only what it added.
- **The installer no longer overwrites** `~/.claude/CLAUDE.md` and `~/.config/opencode/opencode.json`.
- **Installing on macOS** no longer fails when rewriting rule paths (version 1 used a `sed -i` form that only works on Linux).

## [1.0.0]

First release: behavioral principles (`AGENTS.md`), nine topic rules, three skills, and a bash installer for Claude Code and OpenCode on Linux and macOS.
