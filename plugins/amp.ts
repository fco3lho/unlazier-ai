// Unlazier AI plugin for Amp.
//
// Amp has no shell hooks, so this plugin calls the shared Unlazier AI hook script when the
// agent starts working on a user message and appends the reminder to that message, hidden
// from the user. Rules loaded at session start lose weight as the context fills; the
// reminder keeps them near the latest messages. Amp has no compaction event.
//
// Installed at ~/.config/amp/plugins/unlazier-ai.ts; the script lives in ../unlazier-ai/.

import type { PluginAPI } from "@ampcode/plugin"
import { execFileSync } from "node:child_process"
import { fileURLToPath } from "node:url"

const PAYLOAD_DIR = fileURLToPath(new URL("../unlazier-ai/", import.meta.url))
const SCRIPT_TIMEOUT_MILLISECONDS = 5000

function readReminder(): string {
    const isWindows = process.platform === "win32"
    const command = isWindows ? "powershell.exe" : "bash"
    const args = isWindows
        ? ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", `${PAYLOAD_DIR}inject.ps1`, "amp", "prompt"]
        : [`${PAYLOAD_DIR}inject.sh`, "amp", "prompt"]
    try {
        return execFileSync(command, args, { encoding: "utf8", timeout: SCRIPT_TIMEOUT_MILLISECONDS }).trim()
    } catch (error) {
        // A failing reminder must not block the user's message; report it and continue.
        console.error(`unlazier-ai: reminder unavailable: ${error}`)
        return ""
    }
}

export default function (amp: PluginAPI) {
    amp.on("agent.start", async () => {
        const reminder = readReminder()
        return reminder ? { message: { content: reminder, display: false } } : undefined
    })
}
