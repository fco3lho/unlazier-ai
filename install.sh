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

echo ""
echo "Installed to $CONFIG_DIR"
echo "Restart OpenCode for changes to take effect."
