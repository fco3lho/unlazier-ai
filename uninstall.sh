#!/bin/bash
set -e

CONFIG_DIR="${HOME}/.config/opencode"
BACKUP_DIR="${CONFIG_DIR}.bak.$(date +%Y%m%d%H%M%S)"
CLAUDE_DIR="${HOME}/.claude"
CLAUDE_BACKUP_DIR="${CLAUDE_DIR}.bak.$(date +%Y%m%d%H%M%S)"

# --- OpenCode ---

if [ -d "$CONFIG_DIR" ]; then
    echo "Backing up OpenCode config to $BACKUP_DIR"
    cp -r "$CONFIG_DIR" "$BACKUP_DIR"

    echo "Removing $CONFIG_DIR..."
    rm -rf "$CONFIG_DIR"
    echo "Uninstalled OpenCode config."
else
    echo "No OpenCode config found at $CONFIG_DIR"
fi

# --- Claude Code ---

if [ -d "$CLAUDE_DIR" ]; then
    echo "Backing up Claude Code config to $CLAUDE_BACKUP_DIR"
    cp -r "$CLAUDE_DIR" "$CLAUDE_BACKUP_DIR"

    echo "Removing $CLAUDE_DIR..."
    rm -rf "$CLAUDE_DIR"
    echo "Uninstalled Claude Code config."
else
    echo "No Claude Code config found at $CLAUDE_DIR"
fi

echo ""
echo "Done. Backups saved at:"
[ -d "$BACKUP_DIR" ] && echo "  - $BACKUP_DIR"
[ -d "$CLAUDE_BACKUP_DIR" ] && echo "  - $CLAUDE_BACKUP_DIR"
