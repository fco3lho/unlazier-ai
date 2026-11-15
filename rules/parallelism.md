# Agent Parallelism

- **Parallelize by Priority** — when work can run concurrently, prefer, in this order:
    1. Subagents for subtasks of the same main task.
    2. Different tasks of a single request (for example, the tasks of one issue).
    3. Two or more different requests, each with one or more main tasks.
- **Read Usage First** — the injected Unlazier reminder carries a `Usage:` line with the 5-hour and weekly window percentages and their source. Check it before starting concurrent work and again after long-running steps. Report the reading and its source to the user when it changes your pace.
- **Follow the Usage Ladder** — scale concurrency to the 5-hour window:

    | 5-hour window | Behavior |
    |---------------|----------|
    | below 70% | Maximum parallelism |
    | 70% to 85% | At most 2 concurrent agents or tasks |
    | 85% to 95% | Sequential only, no subagents; start nothing new, and let agents already running finish their current step |
    | 95% or more | Stop the running agents at a consistent point, wait in the background for the window to reset, and resume the work on your own; never end the turn waiting for the user |

    When the weekly window reaches 99%, pause: finish the current step, report, and wait for the user.
- **Wait for the Reset (Claude Code)** — the status line saves the usage to `~/.claude/state/rate_limits.json`, and Unlazier installs `~/.claude/unlazier/wait-usage.sh` to wait on it:
    - Before dispatching agents, run `bash ~/.claude/unlazier/wait-usage.sh --stop-at 95` in the background (Windows: `powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\unlazier\wait-usage.ps1" -StopAt 95`), plus a second watcher with `--window seven_day --stop-at 99` (Windows: `-Window seven_day -StopAt 99`).
    - On `threshold` from the 5-hour watcher, stop the running agents at a consistent point and run the script again without `--stop-at`.
    - On `reset` or `dropped`, read the usage again, start the watchers again, then resume the stopped agents and the plan.
    - On `threshold` from the weekly watcher, pause as described above.
    - Never write a wait loop of your own: `resets_at` moves to the next cycle at the reset, so such a loop never ends.
- **No Background Wait** — tools other than Claude Code neither save the usage to a file nor wake the session when a background task ends, so the 95% row cannot be followed there: finish the current step, report, and wait for the user.
- **Unknown Usage** — when the `Usage:` line is missing or reads `unknown`, run at most 2–3 tasks concurrently and ask the user before going beyond 5.
- **Rate-Limit Signals** — on any rate-limit error or quota warning, finish what is running, start nothing new, and report. Never retry in a tight loop.
- **No Credential Access** — never read credential files or call undocumented endpoints to obtain usage data.
- **No Subagents Available** — if the harness has no subagents, apply the same ladder to concurrent tool calls or background tasks.

---

## Examples

[BAD] Ignoring the usage reading
```
Usage: 5h 91% · weekly 40%
-> spawns 6 subagents to refactor 6 modules at once
```

[GOOD] Pace matches the ladder
```
Usage: 5h 91% · weekly 40%
-> 5-hour window is between 85% and 95%: refactor the 6 modules sequentially, no subagents
```

[GOOD] Stop, wait, and resume at 95%
```
Usage: 5h 95% · weekly 40%
-> stops the running agents at a consistent point, runs wait-usage.sh in the background, and resumes the plan when it reports reset
```
