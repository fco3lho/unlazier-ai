// Unlazier AI plugin for OpenCode (V1 from 1.18.29, and V2).
//
// OpenCode has no shell hooks, so this plugin calls the shared Unlazier AI hook script and
// adds its reminder to the system prompt of every model request. Rules loaded at session
// start lose weight as the context fills; the reminder keeps them near the latest messages.
// OpenCode reloads its instruction files after compaction, so no compaction hook is needed.
//
// Installed at ~/.config/opencode/plugins/unlazier-ai.ts; the script lives in ../unlazier-ai/.
// V2 calls setup() and V1 calls server(), so one file serves both versions.

import { execFileSync } from "node:child_process"
import { fileURLToPath } from "node:url"

const PAYLOAD_DIR = fileURLToPath(new URL("../unlazier-ai/", import.meta.url))
const SCRIPT_TIMEOUT_MILLISECONDS = 5000

function readReminder(): string {
    const isWindows = process.platform === "win32"
    const command = isWindows ? "powershell.exe" : "bash"
    const args = isWindows
        ? ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", `${PAYLOAD_DIR}inject.ps1`, "opencode", "prompt"]
        : [`${PAYLOAD_DIR}inject.sh`, "opencode", "prompt"]
    try {
        return execFileSync(command, args, { encoding: "utf8", timeout: SCRIPT_TIMEOUT_MILLISECONDS }).trim()
    } catch (error) {
        // A failing reminder must not block the user's request; report it and continue.
        console.error(`unlazier-ai: reminder unavailable: ${error}`)
        return ""
    }
}

type ContextEvent = { system: Array<{ type: "text"; text: string }> }
type SessionContext = { session: { hook: (name: "context", handler: (event: ContextEvent) => void) => Promise<void> } }

export default {
    id: "unlazier-ai",

    async setup(context: SessionContext) {
        await context.session.hook("context", (event) => {
            const reminder = readReminder()
            if (reminder) {
                event.system.push({ type: "text", text: reminder })
            }
        })
    },

    async server() {
        return {
            "experimental.chat.system.transform": async (_input: unknown, output: { system: string[] }) => {
                const reminder = readReminder()
                if (reminder) {
                    output.system.push(reminder)
                }
            },
        }
    },
}
