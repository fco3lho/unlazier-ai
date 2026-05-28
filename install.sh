#!/bin/bash
set -e

REPO="fco3lho/unlazier-ai"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/$REPO/$BRANCH"

CONFIG_DIR="${HOME}/.config/opencode"
BACKUP_DIR="${CONFIG_DIR}.bak.$(date +%Y%m%d%H%M%S)"

# Detect if running from a local clone or via pipe
if [ -f "AGENTS.md" ] && [ -f "opencode.global.json" ]; then
    LOCAL=true
else
    LOCAL=false
fi

CLAUDE_DIR="${HOME}/.claude"
CLAUDE_BACKUP_DIR="${CLAUDE_DIR}.bak.$(date +%Y%m%d%H%M%S)"

# --- OpenCode installation ---

if [ -d "$CONFIG_DIR" ]; then
    echo "Backing up existing config to $BACKUP_DIR"
    cp -r "$CONFIG_DIR" "$BACKUP_DIR"
fi

mkdir -p "$CONFIG_DIR/rules"
mkdir -p "$CONFIG_DIR/skills"

if [ "$LOCAL" = true ]; then
    cp AGENTS.md "$CONFIG_DIR/AGENTS.md"
    cp rules/*.md "$CONFIG_DIR/rules/"
    cp -r skills/* "$CONFIG_DIR/skills/"
    cp opencode.global.json "$CONFIG_DIR/opencode.json"
else
    echo "Downloading from $RAW_BASE"
    curl -fsSL "$RAW_BASE/AGENTS.md" -o "$CONFIG_DIR/AGENTS.md"
    for f in structure correctness style completeness performance testability async naming; do
        curl -fsSL "$RAW_BASE/rules/$f.md" -o "$CONFIG_DIR/rules/$f.md"
    done
    for skill in bugfix code-review refactoring; do
        mkdir -p "$CONFIG_DIR/skills/$skill"
        curl -fsSL "$RAW_BASE/skills/$skill/SKILL.md" -o "$CONFIG_DIR/skills/$skill/SKILL.md"
    done
    curl -fsSL "$RAW_BASE/opencode.global.json" -o "$CONFIG_DIR/opencode.json"
fi

echo "Installed OpenCode config to $CONFIG_DIR"

# --- Claude Code installation ---

if [ -d "$CLAUDE_DIR" ]; then
    echo "Backing up existing Claude Code config to $CLAUDE_BACKUP_DIR"
    cp -r "$CLAUDE_DIR" "$CLAUDE_BACKUP_DIR"
fi

mkdir -p "$CLAUDE_DIR/rules"
mkdir -p "$CLAUDE_DIR/skills"

# CLAUDE.md imports AGENTS.md via absolute path to keep a single source of truth
{
    echo "@${CONFIG_DIR}/AGENTS.md"
    echo ""
    echo "## Claude Code"
    echo "- Load rules from ${CONFIG_DIR}/rules/ when relevant (see AGENTS.md for the full list)"
} > "$CLAUDE_DIR/CLAUDE.md"

if [ "$LOCAL" = true ]; then
    cp rules/*.md "$CLAUDE_DIR/rules/"
    cp -r skills/* "$CLAUDE_DIR/skills/"
else
    for f in structure correctness style completeness performance testability async naming; do
        curl -fsSL "$RAW_BASE/rules/$f.md" -o "$CLAUDE_DIR/rules/$f.md"
    done
    for skill in bugfix code-review refactoring; do
        mkdir -p "$CLAUDE_DIR/skills/$skill"
        curl -fsSL "$RAW_BASE/skills/$skill/SKILL.md" -o "$CLAUDE_DIR/skills/$skill/SKILL.md"
    done
fi

echo "Installed Claude Code config to $CLAUDE_DIR"
echo "Restart OpenCode or Claude Code for changes to take effect."
