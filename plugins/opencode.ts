// Unlazier plugin for OpenCode (V1 from 1.18.29, and V2).
//
// OpenCode has no shell hooks, so this plugin covers two Unlazier layers itself:
// - Reminder: calls the shared hook script and adds its reminder to the system prompt of every
//   model request. Rules loaded at session start lose weight as the context fills; the reminder
//   keeps them near the latest messages. OpenCode reloads its instruction files after
//   compaction, so no compaction hook is needed.
// - Alerts: plays the shared alert when OpenCode asks for permission, asks a question, or goes
//   idle at the end of a turn.
//
// Installed at ~/.config/opencode/plugins/unlazier.ts; the scripts live in ../unlazier/.
// V2 calls setup() and V1 calls server(), so one file serves both versions.

import { execFileSync, spawn } from "node:child_process"
import { fileURLToPath } from "node:url"

const PAYLOAD_DIR = fileURLToPath(new URL("../unlazier/", import.meta.url))
const SCRIPT_TIMEOUT_MILLISECONDS = 5000
const IS_WINDOWS = process.platform === "win32"

// V1 names a question "question.asked" and V2 a "form.created"; older V1 builds name a
// permission prompt "permission.updated".
const ALERT_EVENTS = new Set(["permission.asked", "permission.updated", "question.asked", "form.created", "session.idle"])

function scriptCommand(name: "inject" | "alert", args: string[]): [string, string[]] {
    if (IS_WINDOWS) {
        return ["powershell.exe", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", `${PAYLOAD_DIR}${name}.ps1`, ...args]]
    }
    return ["bash", [`${PAYLOAD_DIR}${name}.sh`, ...args]]
}

function readReminder(): string {
    const [command, args] = scriptCommand("inject", ["opencode", "prompt"])
    try {
        return execFileSync(command, args, { encoding: "utf8", timeout: SCRIPT_TIMEOUT_MILLISECONDS }).trim()
    } catch (error) {
        // A failing reminder must not block the user's request; report it and continue.
        console.error(`unlazier: reminder unavailable: ${error}`)
        return ""
    }
}

// The beep runs detached so it never delays OpenCode.
function playAlert(): void {
    const [command, args] = scriptCommand("alert", [])
    const child = spawn(command, args, { stdio: "ignore", detached: true })
    child.on("error", (error) => console.error(`unlazier: alert unavailable: ${error}`))
    child.unref()
}

async function watchAlerts(events: AsyncIterable<{ type: string }>): Promise<void> {
    for await (const event of events) {
        if (ALERT_EVENTS.has(event.type)) {
            playAlert()
        }
    }
}

type ContextEvent = { system: Array<{ type: "text"; text: string }> }
type SessionContext = {
    session: { hook: (name: "context", handler: (event: ContextEvent) => void) => Promise<void> }
    event: { subscribe: (options: { signal: AbortSignal }) => AsyncIterable<{ type: string }> }
}

export default {
    id: "unlazier",

    async setup(context: SessionContext) {
        await context.session.hook("context", (event) => {
            const reminder = readReminder()
            if (reminder) {
                event.system.push({ type: "text", text: reminder })
            }
        })
        const controller = new AbortController()
        watchAlerts(context.event.subscribe({ signal: controller.signal })).catch((error) => {
            if (!controller.signal.aborted) {
                console.error(`unlazier: alerts stopped: ${error}`)
            }
        })
        return () => controller.abort()
    },

    async server() {
        return {
            "experimental.chat.system.transform": async (_input: unknown, output: { system: string[] }) => {
                const reminder = readReminder()
                if (reminder) {
                    output.system.push(reminder)
                }
            },
            event: async ({ event }: { event: { type: string } }) => {
                if (ALERT_EVENTS.has(event.type)) {
                    playAlert()
                }
            },
        }
    },
}
