// Unlazier plugin for Amp.
//
// Amp has no shell hooks, so this plugin covers two Unlazier layers itself:
// - Reminder: calls the shared hook script when the agent starts working on a user message
//   and appends the reminder to that message, hidden from the user. Rules loaded at session
//   start lose weight as the context fills; the reminder keeps them near the latest messages.
//   Amp has no compaction event.
// - Alerts: plays the shared alert when the agent finishes its turn. Amp has no permission or
//   question event.
//
// Installed at ~/.config/amp/plugins/unlazier.ts; the scripts live in ../unlazier/.

import type { PluginAPI } from "@ampcode/plugin"
import { execFileSync, spawn } from "node:child_process"
import { fileURLToPath } from "node:url"

const PAYLOAD_DIR = fileURLToPath(new URL("../unlazier/", import.meta.url))
const SCRIPT_TIMEOUT_MILLISECONDS = 5000
const IS_WINDOWS = process.platform === "win32"

function scriptCommand(name: "inject" | "alert", args: string[]): [string, string[]] {
    if (IS_WINDOWS) {
        return ["powershell.exe", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", `${PAYLOAD_DIR}${name}.ps1`, ...args]]
    }
    return ["bash", [`${PAYLOAD_DIR}${name}.sh`, ...args]]
}

function readReminder(): string {
    const [command, args] = scriptCommand("inject", ["amp", "prompt"])
    try {
        return execFileSync(command, args, { encoding: "utf8", timeout: SCRIPT_TIMEOUT_MILLISECONDS }).trim()
    } catch (error) {
        // A failing reminder must not block the user's message; report it and continue.
        console.error(`unlazier: reminder unavailable: ${error}`)
        return ""
    }
}

// The beep runs detached so it never delays Amp.
function playAlert(): void {
    const [command, args] = scriptCommand("alert", [])
    const child = spawn(command, args, { stdio: "ignore", detached: true })
    child.on("error", (error) => console.error(`unlazier: alert unavailable: ${error}`))
    child.unref()
}

export default function (amp: PluginAPI) {
    amp.on("agent.start", async () => {
        const reminder = readReminder()
        return reminder ? { message: { content: reminder, display: false } } : undefined
    })
    amp.on("agent.end", async () => {
        playAlert()
    })
}
