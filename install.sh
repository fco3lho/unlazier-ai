#!/bin/bash
set -e

REPO="fco3lho/unlazier-ai"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/$REPO/$BRANCH"

OPENCODE_DIR="${HOME}/.config/opencode"
CLAUDE_DIR="${HOME}/.claude"

# Check for required dependencies
command -v curl >/dev/null 2>&1 || { echo "Error: curl is required but not installed."; exit 1; }

# Detect if running from a local clone or via pipe
if [ -f "AGENTS.md" ] && [ -f "opencode.global.json" ]; then
    LOCAL=true
else
    LOCAL=false
fi

# Detect installed tools
INSTALL_OPENCODE=false
INSTALL_CLAUDE=false

if command -v opencode >/dev/null 2>&1; then
    INSTALL_OPENCODE=true
    echo "Detected: OpenCode"
fi

if command -v claude >/dev/null 2>&1; then
    INSTALL_CLAUDE=true
    echo "Detected: Claude Code"
fi

# If neither tool detected, install for both (safe default for fresh setups)
if [ "$INSTALL_OPENCODE" = false ] && [ "$INSTALL_CLAUDE" = false ]; then
    echo "No OpenCode or Claude Code detected in PATH. Installing config for both."
    INSTALL_OPENCODE=true
    INSTALL_CLAUDE=true
fi

# --- OpenCode installation ---

if [ "$INSTALL_OPENCODE" = true ]; then
    BACKUP_DIR="${OPENCODE_DIR}.bak.$(date +%Y%m%d%H%M%S)"

    if [ -d "$OPENCODE_DIR" ]; then
        # Remove previous backups before creating a fresh one
        for old_bak in "${OPENCODE_DIR}".bak.*; do
            [ -d "$old_bak" ] && rm -rf "$old_bak"
        done
        echo "Backing up existing OpenCode config to $BACKUP_DIR"
        cp -r "$OPENCODE_DIR" "$BACKUP_DIR"
    fi

    mkdir -p "$OPENCODE_DIR/rules"
    mkdir -p "$OPENCODE_DIR/skills"

    if [ "$LOCAL" = true ]; then
        cp AGENTS.md "$OPENCODE_DIR/AGENTS.md"
        cp rules/*.md "$OPENCODE_DIR/rules/"
        cp -r skills/* "$OPENCODE_DIR/skills/"
        cp opencode.global.json "$OPENCODE_DIR/opencode.json"
    else
        echo "Downloading OpenCode config from $RAW_BASE..."
        curl -fsSL "$RAW_BASE/AGENTS.md" -o "$OPENCODE_DIR/AGENTS.md"
        for f in structure correctness style completeness performance testability async naming documentation; do
            curl -fsSL "$RAW_BASE/rules/$f.md" -o "$OPENCODE_DIR/rules/$f.md"
        done
        for skill in bugfix code-review refactoring; do
            mkdir -p "$OPENCODE_DIR/skills/$skill"
            curl -fsSL "$RAW_BASE/skills/$skill/SKILL.md" -o "$OPENCODE_DIR/skills/$skill/SKILL.md"
        done
        curl -fsSL "$RAW_BASE/opencode.global.json" -o "$OPENCODE_DIR/opencode.json"
    fi

    echo "Installed OpenCode config to $OPENCODE_DIR"
fi

# --- Claude Code installation ---

if [ "$INSTALL_CLAUDE" = true ]; then
    CLAUDE_BACKUP_DIR="${CLAUDE_DIR}.bak.$(date +%Y%m%d%H%M%S)"

    if [ -d "$CLAUDE_DIR" ]; then
        # Remove previous backups before creating a fresh one
        for old_bak in "${CLAUDE_DIR}".bak.*; do
            [ -d "$old_bak" ] && rm -rf "$old_bak"
        done
        echo "Backing up existing Claude Code config to $CLAUDE_BACKUP_DIR"
        cp -r "$CLAUDE_DIR" "$CLAUDE_BACKUP_DIR"
    fi

    mkdir -p "$CLAUDE_DIR/rules"
    mkdir -p "$CLAUDE_DIR/skills"

    if [ "$LOCAL" = true ]; then
        cp AGENTS.md "$CLAUDE_DIR/CLAUDE.md"
        cp rules/*.md "$CLAUDE_DIR/rules/"
        cp -r skills/* "$CLAUDE_DIR/skills/"
    else
        echo "Downloading Claude Code config from $RAW_BASE..."
        curl -fsSL "$RAW_BASE/AGENTS.md" -o "$CLAUDE_DIR/CLAUDE.md"
        for f in structure correctness style completeness performance testability async naming documentation; do
            curl -fsSL "$RAW_BASE/rules/$f.md" -o "$CLAUDE_DIR/rules/$f.md"
        done
        for skill in bugfix code-review refactoring; do
            mkdir -p "$CLAUDE_DIR/skills/$skill"
            curl -fsSL "$RAW_BASE/skills/$skill/SKILL.md" -o "$CLAUDE_DIR/skills/$skill/SKILL.md"
        done
    fi

    echo "Installed Claude Code config to $CLAUDE_DIR"
fi

echo ""
echo "Done. Restart your tools for changes to take effect."
