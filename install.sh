#!/bin/bash
set -e

CONFIG_DIR="${HOME}/.config/opencode"
BACKUP_DIR="${CONFIG_DIR}.bak.$(date +%Y%m%d%H%M%S)"

if [ -d "$CONFIG_DIR" ]; then
    echo "Backing up existing config to $BACKUP_DIR"
    cp -r "$CONFIG_DIR" "$BACKUP_DIR"
fi

mkdir -p "$CONFIG_DIR/rules"
mkdir -p "$CONFIG_DIR/skills"

cp AGENTS.md "$CONFIG_DIR/AGENTS.md"
cp rules/*.md "$CONFIG_DIR/rules/"
cp -r skills/* "$CONFIG_DIR/skills/"
cp opencode.json "$CONFIG_DIR/opencode.json"

echo "Installed to $CONFIG_DIR"
echo "Restart OpenCode for changes to take effect."
