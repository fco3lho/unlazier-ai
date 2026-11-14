#!/bin/bash
# Unlazier AI uninstaller for Linux and macOS.
#
# Usage:
#   ./uninstall.sh [--harness <names|all>] [--yes]
#   curl -fsSL https://raw.githubusercontent.com/fco3lho/unlazier-ai/main/uninstall.sh | bash
#
# Removes only what Unlazier AI added; everything else in each tool's configuration stays.
# The work is done by install.sh in uninstall mode, so both share one harness table.

set -euo pipefail

RAW_BASE="https://raw.githubusercontent.com/fco3lho/unlazier-ai/main"
SCRIPT_PATH="${BASH_SOURCE[0]:-}"

# Run the sibling installer only when this script is a file in a clone; when piped from
# curl there is no script path and the installer is downloaded instead.
if [ -n "$SCRIPT_PATH" ] && [ -f "$SCRIPT_PATH" ]; then
    exec bash "$(cd "$(dirname "$SCRIPT_PATH")" && pwd)/install.sh" --uninstall "$@"
fi

command -v curl >/dev/null 2>&1 || { echo "Error: curl is required but not installed." >&2; exit 1; }
curl -fsSL "$RAW_BASE/install.sh" | bash -s -- --uninstall "$@"
